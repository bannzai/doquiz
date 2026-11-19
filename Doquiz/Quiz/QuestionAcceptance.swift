/// 四択の問いの選択肢の数。問いの種類の定義 (`QuestionKind.comprehension` は四択) による。
let comprehensionChoiceCount = 4

/// 端末内のモデルが返した内容から作った `question` を、利用者に出してよいかを返す。
///
/// `selectedQuestionKinds` は本の出題の設定で選ばれた問いの種類。`currentReadingText` と `previousReadingText` は、
/// この問いを作る時にモデルに渡した本文 (`planQuestions` が返した 2 つ)。次のどれかに当たる問いは false を返す。
///
/// - 種類が `selectedQuestionKinds` に無い
/// - 根拠の引用が空か、渡した本文のどちらにも含まれない。回答の後に見せる引用が、本文に無い文になるのを防ぐ。
///   空白と改行は除いて比べる (ページの本文は画面の行ごとに改行が入っていて、モデルは行をつないだ文を引用として返しうるため)。
///   2 つの本文は別々に比べ、今回の本文の末尾と前の本文の先頭にまたがる引用は含まれないものとする
/// - 四択・要約の正誤で、選択肢の中に模範の答えが無い
/// - 四択で、選択肢が互いに違う `comprehensionChoiceCount` 個になっていない (同じ選択肢が 2 つあると、四択として成り立たないため)
func isAcceptableQuestion(
    question: Question,
    selectedQuestionKinds: [QuestionKind],
    currentReadingText: String,
    previousReadingText: String
) -> Bool {
    let evidenceQuote = question.evidenceQuote.filter { !$0.isWhitespace }
    guard selectedQuestionKinds.contains(question.kind),
        !evidenceQuote.isEmpty,
        currentReadingText.filter({ !$0.isWhitespace }).contains(evidenceQuote)
            || previousReadingText.filter({ !$0.isWhitespace }).contains(evidenceQuote)
    else {
        return false
    }
    switch question.kind {
    case .comprehension:
        return question.choices.contains(question.modelAnswer) && question.choices.count == comprehensionChoiceCount
            && Set(question.choices).count == comprehensionChoiceCount
    case .summaryTrueFalse:
        return question.choices.contains(question.modelAnswer)
    case .fillInTheBlank, .written:
        return true
    }
}
