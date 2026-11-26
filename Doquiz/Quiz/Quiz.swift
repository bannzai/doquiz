import Foundation
import SwiftData

/// 端末内のモデルが使えないため、問いを作らなかったことを表す error。
struct QuizModelUnavailableError: Error {}

/// 読書を終えた後のクイズの問いを作り、読書の記録に付けて保存して返す。
///
/// `quizEngine` に、今回の読書 (`readingSession`) のページの本文、同じ本 (`book`) の前の読書のページの本文、本の出題の設定を渡す。
/// ページの本文は取り込んだ順。前の読書は、今回より前に始めた読書の記録の全部で (終えた日時が入っていない記録を含む)、始めた順に並べる。
/// - 端末内のモデルが使えない時は、問いを作らずに `QuizModelUnavailableError` を投げる
/// - 問いが 1 問も返らなかった時は、何も保存せずに空の配列を返す
/// - `quizEngine` が投げた error はそのまま投げる。保存に失敗した時は、足した問いを取り除いてから `save` の error を投げる
///
/// 保存先への書き込みは `save` で行う (アプリは `modelContext.save` を渡す。保存の失敗をテストで起こせるよう引数にしている)。
/// 冪等ではない: 呼ぶたびに `quizEngine` が新しい問いを作り、読書の記録の問いが増える。呼び出し側は、読書 1 回につき成功を 1 回までにする。
/// - Returns: 保存した問い。`quizEngine` が返した順で、画面はこの順に出す
func makeQuizQuestions(
    book: Book,
    readingSession: ReadingSession,
    quizEngine: any QuizEngine,
    modelContext: ModelContext,
    save: () throws -> Void
) async throws -> [Question] {
    guard case .available = quizEngine.availability else {
        throw QuizModelUnavailableError()
    }
    let questions = try await quizEngine.makeQuestions(
        currentReadingPageTexts: capturedPageTexts(readingSessions: [readingSession]),
        previousReadingPageTexts: capturedPageTexts(
            readingSessions: book.readingSessions
                .filter { $0.startedDateTime < readingSession.startedDateTime }
                .sorted { $0.startedDateTime < $1.startedDateTime }
        ),
        questionKinds: book.questionKinds,
        questionGuidance: book.questionGuidance
    )
    guard !questions.isEmpty else {
        return []
    }
    for question in questions {
        question.readingSession = readingSession
        modelContext.insert(question)
    }
    do {
        try save()
    } catch {
        // 保存できなかった問いを context に残すと、後の保存 (回答・次の読書) に混ざるため、取り除いてから投げる。
        for question in questions {
            modelContext.delete(question)
        }
        throw error
    }
    return questions
}

/// `readingSessions` のページの本文を、渡した読書の記録の順に、読書の記録の中では取り込んだ順に並べて返す。
private func capturedPageTexts(readingSessions: [ReadingSession]) -> [String] {
    readingSessions.flatMap { readingSession in
        readingSession.capturedPages.sorted { $0.capturedDateTime < $1.capturedDateTime }.map(\.text)
    }
}

/// 問いへの答えを判定し、回答を 1 件保存して返す。
///
/// 保存する利用者の答えは、四択と要約の正誤では選んだ選択肢 `answerText` をそのまま、穴埋めと記述では前後の空白と改行を除いたもの。
/// 判定に渡す答えも同じ値にする。
/// - 判定が error を投げた時 (端末内のモデルが判定を返せなかった時) は、回答を保存せずにその error を投げる
/// - 保存に失敗した時は、足した回答を取り除いてから `save` の error を投げる
///
/// 冪等ではない: 回答は答えるたびに 1 件増え、穴埋めと記述の判定は同じ答えでも変わることがある。
/// - Parameters:
///   - currentDateTime: 今の日時を返す。1 回呼び、答えた日時にする
///   - save: 保存先への書き込み (アプリは `modelContext.save` を渡す。保存の失敗をテストで起こせるよう引数にしている)
func answerQuizQuestion(
    question: Question,
    answerText: String,
    quizEngine: any QuizEngine,
    modelContext: ModelContext,
    currentDateTime: () -> Date,
    save: () throws -> Void
) async throws -> Answer {
    let savedAnswerText: String
    switch question.kind {
    case .comprehension, .summaryTrueFalse:
        // 選択式の判定は模範の答えと同じ文字列かで決まるため、選んだ選択肢を変えない。
        savedAnswerText = answerText
    case .fillInTheBlank, .written:
        savedAnswerText = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let answer = Answer(
        id: UUID(),
        answeredDateTime: currentDateTime(),
        text: savedAnswerText,
        isCorrect: try await quizEngine.judge(question: question, answerText: savedAnswerText),
        question: question
    )
    modelContext.insert(answer)
    do {
        try save()
    } catch {
        // 保存できなかった回答を context に残すと、後の保存に混ざり、保存されていない判定が画面に出るため、取り除いてから投げる。
        modelContext.delete(answer)
        throw error
    }
    return answer
}

/// 問いが 1 問もできなかった時に、クイズの画面に出す案内の文を返す。
///
/// - Parameter capturedPageCount: 今回の読書で取り込んだページの数。0 の時は、本文を取り込めなかったことを伝える
func quizNoQuestionsGuide(capturedPageCount: Int) -> String {
    capturedPageCount == 0
        ? "本文を取り込めなかったため\n今回の読書のクイズはありません"
        : "読んだ範囲から問いを作れなかったため\n今回の読書のクイズはありません"
}

/// 問いに答える画面で、答える前に離れるボタンを出すかを返す。
///
/// 判定している途中は、どの場合も出さない (離れた後に回答が保存されるため)。
/// それ以外は、答える前から離れられる画面 (`canLeaveBeforeAnswering`) か、答えの判定か保存に失敗した後 (`hasAnswerFailure`) に出す。
func quizCanLeaveBeforeNext(canLeaveBeforeAnswering: Bool, isJudging: Bool, hasAnswerFailure: Bool) -> Bool {
    !isJudging && (canLeaveBeforeAnswering || hasAnswerFailure)
}

/// 端末内のモデルが使えない時に、クイズの画面に出す案内の文。
let quizModelUnavailableGuide = "この iPhone では今 端末内のモデルを使えないため\nクイズを出せません"

/// 問いを作る処理か、作った問いの保存が失敗した時に、クイズの画面に出す案内の文を返す。
func quizPreparationFailureGuide(error: any Error) -> String {
    "問いを作れませんでした\n\(error)"
}

/// 答えの判定か、回答の保存が失敗した時に、クイズの画面に出す案内の文を返す。
func quizAnswerFailureGuide(error: any Error) -> String {
    "答えを判定して保存できませんでした\nもう一度答えてください\n\(error)"
}

/// 回答の判定を、クイズの画面に出す文にして返す。
///
/// 四択と要約の正誤は、模範の答えと同じかで決まるため言い切る。
/// 穴埋めと記述は、端末内のモデルの判定で間違うことがあるため言い切らない。
func quizJudgementText(questionKind: QuestionKind, isCorrect: Bool) -> String {
    switch questionKind {
    case .comprehension, .summaryTrueFalse:
        isCorrect ? "合っています" : "合っていません"
    case .fillInTheBlank, .written:
        isCorrect ? "合っていそうです" : "合っていないかもしれません"
    }
}

/// 判定の文の前に付ける印を返す。合っている時は ○、合っていない時は ×。
///
/// 穴埋めと記述でも同じ印を付ける (判定の文が言い切らないことで、間違うことがある旨を伝えるため)。
func quizJudgementSign(isCorrect: Bool) -> String {
    isCorrect ? "○" : "×"
}

/// 判定の下に添える、判定が間違うことがある旨の文を返す。添えない種類 (四択と要約の正誤) では nil。
func quizJudgementCaution(questionKind: QuestionKind) -> String? {
    switch questionKind {
    case .comprehension, .summaryTrueFalse:
        nil
    case .fillInTheBlank, .written:
        "この判定は端末内のモデルによるもので 間違うことがあります\n模範の答えと根拠にした本文で確かめてください"
    }
}
