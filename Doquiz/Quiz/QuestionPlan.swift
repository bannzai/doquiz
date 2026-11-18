import Foundation

/// 問い 1 問を作る元にする、今回の読書の本文の文字数。
///
/// 読んだ分量に合わせて問いを増やすための値で、1 問が本文のどこか 1 か所の理解を確かめる大きさとして担当 (agent) が決めた
/// (`documents/DIRECTION.md`「agent に任せること」の「問いの数の決め方」)。実機で作った問いを見て決め直してよい。
let characterCountPerQuestion = 800

/// 読書 1 回の後に出す問いの数の上限。
///
/// 長く読んだ後でも、答える時間と、端末内のモデルが問いを作る時間 (問い 1 問ごとにモデルを 1 回呼ぶ) が伸びすぎないように
/// 担当 (agent) が決めた (`documents/DIRECTION.md`「agent に任せること」の「問いの数の決め方」)。
let maximumQuestionCount = 10

/// 今回の読書の本文の文字数 `currentReadingCharacterCount` から、作る問いの数を返す。
///
/// 0 文字なら 0 問。1 文字以上なら 1 問以上で、`characterCountPerQuestion` 文字ごとに 1 問増え、`maximumQuestionCount` を超えない。
func questionCount(currentReadingCharacterCount: Int) -> Int {
    min(maximumQuestionCount, (currentReadingCharacterCount + characterCountPerQuestion - 1) / characterCountPerQuestion)
}

/// ページの本文 `pageTexts` を、前後の空白と改行を除き、空のページを除いて、渡された順に改行でつないで返す。
func joinPageTexts(pageTexts: [String]) -> String {
    pageTexts
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
}

/// 作る問い 1 問ごとに、問いの種類と、端末内のモデルに渡す本文を決めて返す。
///
/// 端末内のモデルが一度に受け取れる量は限られるため、問い 1 問ごとにモデルを 1 回呼ぶ前提で、1 回に渡す本文を選ぶ
/// (大きい作業を複数のセッションに分ける方法は https://developer.apple.com/documentation/foundationmodels/managing-the-context-window )。
///
/// - 問いの数は `questionCount(currentReadingCharacterCount:)` で決める。今回の読書の本文が空か、`questionKinds` が空か、`characterLimit` が 0 以下なら空の配列を返す
/// - `questionKind` は `questionKinds` を先頭から順に繰り返して割り当てる
/// - `currentReadingText` は、今回の読書の本文 (`currentReadingPageTexts` を `joinPageTexts` でつないだもの) を問いの数で等分した区間の先頭から、`characterLimit` 文字まで
/// - `previousReadingText` は、前の読書の本文の末尾 (今回の読書に近い側) から、`characterLimit` の残りの文字数まで。
///   `currentReadingText` と合わせて `characterLimit` 文字を超えない
func planQuestions(
    currentReadingPageTexts: [String],
    previousReadingPageTexts: [String],
    questionKinds: [QuestionKind],
    characterLimit: Int
) -> [(questionKind: QuestionKind, currentReadingText: String, previousReadingText: String)] {
    guard !questionKinds.isEmpty, characterLimit > 0 else {
        return []
    }
    let currentReadingCharacters = Array(joinPageTexts(pageTexts: currentReadingPageTexts))
    let previousReadingText = joinPageTexts(pageTexts: previousReadingPageTexts)
    let plannedQuestionCount = questionCount(currentReadingCharacterCount: currentReadingCharacters.count)
    return (0..<plannedQuestionCount).map { questionIndex in
        let currentReadingText = String(
            currentReadingCharacters[
                (questionIndex * currentReadingCharacters.count / plannedQuestionCount)..<(
                    (questionIndex + 1) * currentReadingCharacters.count / plannedQuestionCount
                )
            ].prefix(characterLimit)
        )
        return (
            questionKind: questionKinds[questionIndex % questionKinds.count],
            currentReadingText: currentReadingText,
            previousReadingText: String(previousReadingText.suffix(characterLimit - currentReadingText.count))
        )
    }
}
