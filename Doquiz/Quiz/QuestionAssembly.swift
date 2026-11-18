import Foundation
import FoundationModels

/// 端末内のモデルが返した値から、種類 `questionKind` の、保存していない問い (`readingSession` は nil) を組み立てて返す。
///
/// `questionText`・`modelAnswer`・`evidenceQuote` はモデルが返した問いの文・模範の答え・根拠の引用。
/// `wrongChoices` はモデルが返した誤りの選択肢で、四択の時だけ使う。
/// 選択肢は、四択なら模範の答えと `wrongChoices` を合わせて、模範の答えが決まった位置に来ないように並べ替えたもの、
/// 要約の正誤なら `summaryTrueFalseChoices`、穴埋めと記述なら空。
/// 冪等ではない: 呼ぶたびに問いの `id`・作った日時・四択の選択肢の順が変わる。
func assembleQuestion(
    questionKind: QuestionKind,
    questionText: String,
    modelAnswer: String,
    wrongChoices: [String],
    evidenceQuote: String
) -> Question {
    let choices: [String]
    switch questionKind {
    case .comprehension:
        choices = ([modelAnswer] + wrongChoices).shuffled()
    case .summaryTrueFalse:
        choices = summaryTrueFalseChoices
    case .fillInTheBlank, .written:
        choices = []
    }
    return Question(
        id: UUID(),
        createdDateTime: Date(),
        kind: questionKind,
        text: questionText,
        choices: choices,
        modelAnswer: modelAnswer,
        evidenceQuote: evidenceQuote,
        readingSession: nil
    )
}

/// `questionPlans` (`planQuestions` が返した、問い 1 問ごとの種類と本文) の順に `makeQuestion` で問いを作り、`isAcceptableQuestion` が通した問いだけを返す。
///
/// `selectedQuestionKinds` は本の出題の設定で選ばれた問いの種類。`makeQuestion` は問い 1 問を作る処理 (実物は端末内のモデルを 1 回呼ぶ)。
///
/// - `makeQuestion` が端末内のモデルのエラー (`LanguageModelError`。安全のための制限・拒否・一度に受け取れる量の超過など) を投げた時は、その 1 問を作らずに残りを続ける
///   (本文の一部が制限に当たっても、ほかの部分から作れた問いを出すため)
/// - 返す問いが 1 問も無く、`LanguageModelError` で失敗した問いがあった時は、最初の `LanguageModelError` を投げる
/// - `LanguageModelError` が 1 回も無く、作った問いが検査ですべて捨てられた時は、エラーを投げずに空の配列を返す
/// - `LanguageModelError` 以外のエラーは、受け取った時点でそのまま投げる
func collectAcceptableQuestions(
    questionPlans: [(questionKind: QuestionKind, currentReadingText: String, previousReadingText: String)],
    selectedQuestionKinds: [QuestionKind],
    makeQuestion: @MainActor ((questionKind: QuestionKind, currentReadingText: String, previousReadingText: String)) async throws -> Question
) async throws -> [Question] {
    var questions: [Question] = []
    var firstLanguageModelError: LanguageModelError?
    for questionPlan in questionPlans {
        do {
            let question = try await makeQuestion(questionPlan)
            if isAcceptableQuestion(
                question: question,
                selectedQuestionKinds: selectedQuestionKinds,
                currentReadingText: questionPlan.currentReadingText,
                previousReadingText: questionPlan.previousReadingText
            ) {
                questions.append(question)
            }
        } catch let languageModelError as LanguageModelError {
            firstLanguageModelError = firstLanguageModelError ?? languageModelError
        }
    }
    if questions.isEmpty, let firstLanguageModelError {
        throw firstLanguageModelError
    }
    return questions
}
