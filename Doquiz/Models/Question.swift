import Foundation
import SwiftData

/// 問い。読んだ範囲から作った 1 問。
@Model final class Question {
    /// 問いを 1 問ずつ区別する値。
    @Attribute(.unique) var id: UUID
    /// 問いを作った日時。
    var createdDateTime: Date
    /// 問いの種類。
    var kind: QuestionKind
    /// 問いの文。穴埋めでは空欄を含む文。
    var text: String
    /// 選択肢。画面に出す順。穴埋めと記述では空。
    var choices: [String]
    /// 模範の答え。選択式では choices のどれかと同じ文字列、穴埋めでは空欄に入る言葉、記述では答えの例。
    var modelAnswer: String
    /// 模範の答えの根拠にした本文の引用。回答の後に見せる。
    var evidenceQuote: String
    /// この問いを作る元になった読書の記録。
    var readingSession: ReadingSession?
    /// この問いへの回答。履歴から答え直すたびに 1 件増える。
    @Relationship(deleteRule: .cascade, inverse: \Answer.question)
    var answers: [Answer]

    /// 回答をまだ持たない問いを作る。回答は、`Answer` を作る時にこの問いを渡して足す。
    init(
        id: UUID,
        createdDateTime: Date,
        kind: QuestionKind,
        text: String,
        choices: [String],
        modelAnswer: String,
        evidenceQuote: String,
        readingSession: ReadingSession?
    ) {
        self.id = id
        self.createdDateTime = createdDateTime
        self.kind = kind
        self.text = text
        self.choices = choices
        self.modelAnswer = modelAnswer
        self.evidenceQuote = evidenceQuote
        self.readingSession = readingSession
        self.answers = []
    }
}
