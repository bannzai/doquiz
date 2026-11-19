import Foundation
import FoundationModels
import SwiftData

/// 履歴に並べる読書の記録を、保存先から読む条件と並び順を返す。
///
/// 読むのは、`id` が `bookID` の本の読書の記録だけで、読書を始めた日時の新しい順に並ぶ (終えた日時の無い読書の記録も含む)。
/// 履歴の画面と単体テストが同じ条件で読むよう、関数にしている。
func historyReadingSessionsDescriptor(bookID: UUID) -> FetchDescriptor<ReadingSession> {
    FetchDescriptor<ReadingSession>(
        predicate: #Predicate { $0.book?.id == bookID },
        sortBy: [SortDescriptor(\.startedDateTime, order: .forward)]
    )
}

/// 読書の記録の問いを、履歴に出す順 (作った日時の古い順。クイズで出した順) に並べて返す。
///
/// 作った日時が同じ問いは、何回呼んでも同じ順になるよう `id` の文字列の順に並べる。
func historyQuestions(readingSession: ReadingSession) -> [Question] {
    readingSession.questions.sorted {
        ($0.createdDateTime, $0.id.uuidString) < ($1.createdDateTime, $1.id.uuidString)
    }
}

/// 問いへの回答を、答えた日時の古い順に並べて返す。最後の要素が、いちばん新しい回答。
///
/// 答えた日時が同じ回答は、何回呼んでも同じ順になるよう `id` の文字列の順に並べる。
func historyAnswers(question: Question) -> [Answer] {
    question.answers.sorted {
        ($0.answeredDateTime, $0.id.uuidString) > ($1.answeredDateTime, $1.id.uuidString)
    }
}

/// 読書の記録のページを、取り込んだ日時の古い順 (読んだ順) に並べて返す。
func historyCapturedPages(readingSession: ReadingSession) -> [CapturedPage] {
    readingSession.capturedPages.sorted {
        ($0.capturedDateTime, $0.id.uuidString) < ($1.capturedDateTime, $1.id.uuidString)
    }
}

/// 読書の記録のページの数と問いの数を、「12 ページ ・ 5 問」の形の 1 行の文にして返す。
///
/// どちらの数も保存せず、保存済みのページと問いから数える (`.claude/rules/swiftdata.md`)。
func historyReadingSessionCountsText(readingSession: ReadingSession) -> String {
    "\(readingSession.capturedPages.count) ページ ・ \(readingSession.questions.count) 問"
}

/// 日時を、履歴に出す「2026年11月6日 19:40」の形の文にして返す。
///
/// - Parameter timeZone: 日付と時刻を読む時間帯。アプリは端末の時間帯 (`TimeZone.current`) を渡す
func historyDateTimeText(dateTime: Date, timeZone: TimeZone) -> String {
    // 画面の文言が日本語だけのため、端末の言語に関わらず日本語の書き方にする (`bookReadingSummary` と同じ)。
    dateTime.formatted(
        Date.FormatStyle(date: .long, time: .shortened, locale: Locale(identifier: "ja_JP"), timeZone: timeZone)
    )
}

/// 前に答えた時の判定を、履歴に出す文にして返す。
///
/// 四択と要約の正誤は、模範の答えと同じかで決まるため言い切る。
/// 穴埋めと記述は、端末内のモデルの判定で間違うことがあるため、そう判定したことだけを書く (`quizJudgementText` と同じ分け方)。
func historyJudgementText(questionKind: QuestionKind, isCorrect: Bool) -> String {
    switch questionKind {
    case .comprehension, .summaryTrueFalse:
        isCorrect ? "合っていました" : "合っていませんでした"
    case .fillInTheBlank, .written:
        isCorrect ? "合っていました" : "合っていませんでした"
    }
}

/// 履歴の問いに答え直しを始められるかを返す。
///
/// 穴埋めと記述は判定に端末内のモデルが要るため、`availability` が使えない時は始められない。
/// 四択と要約の正誤は、模範の答えと同じかで判定してモデルを使わないため、`availability` に関わらず始められる。
func historyCanReanswer(questionKind: QuestionKind, availability: SystemLanguageModel.Availability) -> Bool {
    switch questionKind {
    case .comprehension, .summaryTrueFalse:
        return true
    case .fillInTheBlank, .written:
        return true
    }
}

/// 履歴の問いに答え直しを始められない時に、その問いの下に出す案内の文。
let historyReanswerUnavailableGuide = "この iPhone では今 端末内のモデルを使えないため\nこの問いには答え直せません"

/// 読書の記録を消す前の確認に出す、一緒に消えるものの文を返す。数は保存済みのデータから数える。
func historyReadingSessionDeletionWarning(readingSession: ReadingSession) -> String {
    "この読書のページ \(readingSession.capturedPages.count) 件 問い \(readingSession.questions.count) 問"
        + " 回答 \(readingSession.questions.map(\.answers.count).reduce(0, +)) 件も消えます\n消した後は元に戻せません"
}

/// 本を消す前の確認に出す、一緒に消えるものの文を返す。数は保存済みのデータから数える。
func historyBookDeletionWarning(book: Book) -> String {
    "この本の読書の記録 \(book.readingSessions.count) 件"
        + " ページ \(book.readingSessions.map(\.capturedPages.count).reduce(0, +)) 件"
        + " 問い \(book.readingSessions.map(\.questions.count).reduce(0, +)) 問"
        + " 回答 \(book.readingSessions.flatMap(\.questions).map(\.answers.count).reduce(0, +)) 件も消えます\n消した後は元に戻せません"
}

/// 読書の記録を 1 件消して保存する。そのページ・問い・回答も一緒に消える。本と、同じ本のほかの読書の記録は残る。
///
/// 保存先への書き込みは `save` で行う (アプリは `modelContext.save` を渡す。保存の失敗をテストで起こせるよう引数にしている)。
/// 保存に失敗した時は、`modelContext` のまだ保存していない変更を取り消して (消した読書の記録を戻して) から `save` の error を投げる。
/// 冪等ではない: 消した後の読書の記録をもう一度渡してはいけない (保存先に無いデータを消すことになるため)。
func deleteReadingSession(readingSession: ReadingSession, modelContext: ModelContext, save: () throws -> Void) throws {
    try saveDeletion(modelContext: modelContext, save: save)
}

/// 本を消して保存する。その本の読書の記録・ページ・問い・回答も一緒に消える。ほかの本のデータは残る。
///
/// 保存先への書き込みは `save` で行う (アプリは `modelContext.save` を渡す。保存の失敗をテストで起こせるよう引数にしている)。
/// 保存に失敗した時は、`modelContext` のまだ保存していない変更を取り消して (消した本を戻して) から `save` の error を投げる。
/// 冪等ではない: 消した後の本をもう一度渡してはいけない (保存先に無いデータを消すことになるため)。
func deleteBook(book: Book, modelContext: ModelContext, save: () throws -> Void) throws {
    for readingSession in book.readingSessions { modelContext.delete(readingSession) }
    try saveDeletion(modelContext: modelContext, save: save)
}

/// 削除を保存する。保存に失敗した時は、`modelContext` のまだ保存していない変更を取り消してから `save` の error を投げる。
private func saveDeletion(modelContext: ModelContext, save: () throws -> Void) throws {
    do {
        try save()
    } catch {
        // 保存できなかった削除を context に残すと、後の保存 (回答・次の読書) で消えてしまうため、取り消してから投げる。
        throw error
    }
}
