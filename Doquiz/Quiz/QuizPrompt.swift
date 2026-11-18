/// 要約の正誤の問いの選択肢。画面に出す順。端末内のモデルは、模範の答えとしてこのどちらかを返す。
let summaryTrueFalseChoices = ["正しい", "誤り"]

/// 端末内のモデルに渡す、出題への希望の文 (`Book.questionGuidance`) の文字数の上限。
///
/// 出題への希望は利用者が自由に書く文で長さに上限が無く、そのまま渡すと、モデルが一度に受け取れる量から本文に使える分が減る。
/// 「用語の定義を中心に」のような短い文を書く欄として、数文が入る長さで切る (担当 (agent) が決めた)。
let questionGuidanceCharacterLimit = 200

/// 種類 `questionKind` の問いの作り方を、端末内のモデルに頼む文を返す。
///
/// 文の中の `questionText`・`modelAnswer`・`wrongChoices` は、モデルの出力の型 (`GeneratedQuestion`・`GeneratedChoiceQuestion`) の値の名前。
func makeQuestionKindRequest(questionKind: QuestionKind) -> String {
    switch questionKind {
    case .comprehension:
        return "本文の内容の理解を確かめる四択の問いを 1 問作る。modelAnswer に正しい選択肢を、wrongChoices に誤りの選択肢を 3 つ書く。"
    case .summaryTrueFalse:
        return "本文の内容を要約した文を 1 つ questionText に書く。要約は、本文と合っている文でも、合っていない文でもよい。"
            + "本文と合っていれば modelAnswer に「\(summaryTrueFalseChoices[0])」、合っていなければ「\(summaryTrueFalseChoices[1])」と書く。"
    case .fillInTheBlank:
        return "本文の 1 文を選び、その中の大事な言葉 1 つを「＿＿」に置き換えた文を questionText に書く。置き換えた言葉を modelAnswer に書く。"
    case .written:
        return "本文の内容の理解を確かめる、文で答える問いを 1 問作る。答えの例を modelAnswer に書く。"
    }
}

/// 問い 1 問を作る時に端末内のモデルに渡す依頼の文を返す。
///
/// `questionKind` は作る問いの種類、`currentReadingText` と `previousReadingText` は `planQuestions` が選んだ本文、
/// `questionGuidance` は本の出題への希望。`previousReadingText` が空なら前の読書の節を、`questionGuidance` が nil か空なら希望の行を入れない。
/// `questionGuidance` は先頭から `questionGuidanceCharacterLimit` 文字までを入れる。
func makeQuestionPrompt(
    questionKind: QuestionKind,
    currentReadingText: String,
    previousReadingText: String,
    questionGuidance: String?
) -> String {
    ([
        makeQuestionKindRequest(questionKind: questionKind),
        questionGuidance.flatMap { (guidance: String) -> String? in
            guidance.isEmpty ? nil : "出題への希望: " + guidance.prefix(questionGuidanceCharacterLimit)
        },
        previousReadingText.isEmpty ? nil : "前に読んだ本文:\n" + previousReadingText,
        "今回読んだ本文:\n" + currentReadingText,
    ] as [String?])
    .compactMap { $0 }
    .joined(separator: "\n\n")
}

/// 穴埋めか記述の `question` への答え `answerText` の判定を、端末内のモデルに頼む文を返す。
///
/// 問いの文・模範の答え・根拠の引用・利用者の答えを、この順に 1 行ずつ入れる。
func makeJudgementPrompt(question: Question, answerText: String) -> String {
    """
    問い: \(question.text)
    模範の答え: \(question.modelAnswer)
    根拠の本文: \(question.evidenceQuote)
    利用者の答え: \(answerText)
    """
}
