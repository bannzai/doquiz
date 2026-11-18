/// 問いの種類。
enum QuestionKind: String, Codable {
    /// 内容の理解を確かめる問い (四択)。
    case comprehension
    /// 要約の文が本文と合っているかを答える問い (二択)。
    case summaryTrueFalse
    /// 本文の一部を空欄にした問い (空欄に入る言葉を入力する)。
    case fillInTheBlank
    /// 文で答える問い (記述)。
    case written = "essay"
}
