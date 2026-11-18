import Foundation
import SwiftData

/// 読書の記録。「読書を始める」から「読書を終える」までの 1 回分。
@Model final class ReadingSession {
    /// 読書の記録を 1 件ずつ区別する値。
    @Attribute(.unique) var id: UUID
    /// 読書を始めた (画面の取り込みを始めた) 日時。
    var startedDateTime: Date
    /// 読書を終えてアプリに戻った日時。読書中は nil。
    var endedDateTime: Date?
    /// 読んだ本。
    var book: Book?
    /// この読書で取り込んだページ。読書の記録を消すと一緒に消える。
    @Relationship(deleteRule: .cascade, inverse: \CapturedPage.readingSession)
    var capturedPages: [CapturedPage]
    /// この読書の後に作った問い。読書の記録を消すと一緒に消える。
    @Relationship(deleteRule: .cascade, inverse: \Question.readingSession)
    var questions: [Question]

    /// ページと問いをまだ持たない読書の記録を作る。ページと問いは、`CapturedPage` と `Question` を作る時にこの読書の記録を渡して足す。
    init(id: UUID, startedDateTime: Date, endedDateTime: Date?, book: Book?) {
        self.id = id
        self.startedDateTime = startedDateTime
        self.endedDateTime = endedDateTime
        self.book = book
        self.capturedPages = []
        self.questions = []
    }
}
