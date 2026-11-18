import Foundation
import SwiftData

/// 回答。問いへの 1 回分の答え。
@Model final class Answer {
    /// 回答を 1 件ずつ区別する値。
    @Attribute(.unique) var id: UUID
    /// 答えた日時。
    var answeredDateTime: Date
    /// 利用者の答え。選択式では選んだ選択肢、穴埋めと記述では入力した文。
    var text: String
    /// 合っていると判定したか。選択式は模範の答えと同じか、穴埋めと記述は端末内モデルの判定。
    var isCorrect: Bool
    /// 答えた問い。
    var question: Question?

    /// 問いへの回答を作る。
    init(id: UUID, answeredDateTime: Date, text: String, isCorrect: Bool, question: Question?) {
        self.id = id
        self.answeredDateTime = answeredDateTime
        self.text = text
        self.isCorrect = isCorrect
        self.question = question
    }
}
