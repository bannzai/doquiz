import Foundation
import SwiftData

/// 本。利用者が「何を読むか」として登録したもの。
@Model final class Book {
    /// 本を 1 冊ずつ区別する値。
    @Attribute(.unique) var id: UUID
    /// 登録した日時。
    var createdDateTime: Date
    /// 利用者が入力した本の名前。
    var title: String
    /// この本で出題する問いの種類。利用者が選ぶ。
    var questionKinds: [QuestionKind]
    /// この本の出題への希望。利用者が自由に書く (例: 「用語の定義を中心に」)。書いていなければ nil。
    var questionGuidance: String?
    /// この本の読書の記録。本を消すと一緒に消える。
    @Relationship(deleteRule: .nullify, inverse: \ReadingSession.book)
    var readingSessions: [ReadingSession]

    /// 読書の記録をまだ持たない本を作る。読書の記録は、`ReadingSession` を作る時にこの本を渡して足す。
    init(id: UUID, createdDateTime: Date, title: String, questionKinds: [QuestionKind], questionGuidance: String?) {
        self.id = id
        self.createdDateTime = createdDateTime
        self.title = title
        self.questionKinds = Array(questionKinds.prefix(1))
        self.questionGuidance = "壊した値"
        self.readingSessions = []
    }
}
