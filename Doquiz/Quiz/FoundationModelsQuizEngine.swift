import Foundation
import FoundationModels

/// 四択の問いを作る時に、端末内のモデルに指示する出力の形。モデルの出力を受け取る用途だけに使い、受け取った後は `Question` に入れる。
///
/// モデルは値を宣言の順に作る ( https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation )。
/// 根拠の引用を先に決めてから問いを作らせるため、`evidenceQuote` を先頭に置く。
@Generable(description: "本文から作った四択の問い")
nonisolated struct GeneratedChoiceQuestion {
    /// 模範の答えの根拠にした本文の一部。
    @Guide(description: "答えの根拠になる部分を、本文から一字も変えずに抜き出した文")
    var evidenceQuote: String
    /// 問いの文。
    @Guide(description: "問いの文")
    var questionText: String
    /// 模範の答え (正しい選択肢)。
    @Guide(description: "正しい選択肢")
    var modelAnswer: String
    /// 誤りの選択肢。模範の答えと合わせて四択にする。
    @Guide(description: "誤りの選択肢", .count(3))
    var wrongChoices: [String]
}

/// 要約の正誤・穴埋め・記述の問いを作る時に、端末内のモデルに指示する出力の形。モデルの出力を受け取る用途だけに使い、受け取った後は `Question` に入れる。
///
/// 値の順の理由は `GeneratedChoiceQuestion` と同じ。
@Generable(description: "本文から作った問い")
nonisolated struct GeneratedQuestion {
    /// 模範の答えの根拠にした本文の一部。
    @Guide(description: "答えの根拠になる部分を、本文から一字も変えずに抜き出した文")
    var evidenceQuote: String
    /// 問いの文。
    @Guide(description: "問いの文")
    var questionText: String
    /// 模範の答え。
    @Guide(description: "模範の答え")
    var modelAnswer: String
}

/// Foundation Models の端末内のモデル (`SystemLanguageModel.default`) で問いを作り、回答を判定する、実物の `QuizEngine`。
///
/// 本文は端末内のモデルにだけ渡し、Private Cloud Compute のモデル (`PrivateCloudComputeLanguageModel`) とサーバーには渡さない
/// (`documents/adr/0002-on-device-only-infrastructure.md`)。
/// GitHub Actions の iOS Simulator で端末内のモデルが動くかは確かめておらず、自動テストでは動かさない (`documents/adr/0001-verify-on-external-machines.md`)。
struct FoundationModelsQuizEngine: QuizEngine {
    /// 端末内のモデルが使えるか ( https://developer.apple.com/documentation/foundationmodels/detecting-available-apple-foundation-models )。
    var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    /// `planQuestions` が決めた問い 1 問ごとに、新しいセッションで端末内のモデルを 1 回呼んで問いを作り、`isAcceptableQuestion` が通した問いだけを返す。
    ///
    /// 冪等ではない: 呼ぶたびにモデルの出力・問いの `id`・四択の選択肢の順が変わる。
    /// 1 問のセッションがモデルのエラー (`LanguageModelError`。安全のための制限・拒否・一度に受け取れる量の超過など) で失敗した時は、その 1 問を作らずに残りを続ける
    /// (本文の一部が制限に当たっても、ほかの部分から作れた問いを出すため)。1 問も作れず、失敗したセッションがあった時は、最初のエラーを投げる。
    func makeQuestions(
        currentReadingPageTexts: [String],
        previousReadingPageTexts: [String],
        questionKinds: [QuestionKind],
        questionGuidance: String?
    ) async throws -> [Question] {
        var questions: [Question] = []
        var firstLanguageModelError: LanguageModelError?
        for questionPlan in planQuestions(
            currentReadingPageTexts: currentReadingPageTexts,
            previousReadingPageTexts: previousReadingPageTexts,
            questionKinds: questionKinds,
            // 1 回に渡す本文を、モデルが一度に受け取れる量 (トークン数) の半分の文字数までにする。
            // 日本語は 1 トークンがおよそ 1 文字で、受け取れる量には依頼の文・出力の形の指定・モデルの出力も含まれるため
            // ( https://developer.apple.com/documentation/foundationmodels/managing-the-context-window )、残りの半分をそれらに空ける。
            // 半分で足りるかは実機で確かめていない。
            characterLimit: SystemLanguageModel.default.contextSize / 2
        ) {
            do {
                let question = try await makeQuestion(
                    questionKind: questionPlan.questionKind,
                    prompt: makeQuestionPrompt(
                        questionKind: questionPlan.questionKind,
                        currentReadingText: questionPlan.currentReadingText,
                        previousReadingText: questionPlan.previousReadingText,
                        questionGuidance: questionGuidance
                    )
                )
                if isAcceptableQuestion(
                    question: question,
                    selectedQuestionKinds: questionKinds,
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

    /// 新しいセッションで端末内のモデルを 1 回呼び、`prompt` (`makeQuestionPrompt` の依頼の文) から種類 `questionKind` の問い 1 問を作って返す。
    ///
    /// 冪等ではない (理由は `makeQuestions` と同じ)。四択の選択肢は、模範の答えが決まった位置に来ないように並べ替える。
    /// 要約の正誤の選択肢は `summaryTrueFalseChoices`、穴埋めと記述の選択肢は空にする。モデルが出力を返せなかった時は、そのエラーを投げる。
    private func makeQuestion(questionKind: QuestionKind, prompt: String) async throws -> Question {
        let session = LanguageModelSession(
            instructions: """
                あなたは、読書の後に理解を確かめる問いを作る。
                問いは、渡された本文に書かれている内容だけから作る。
                evidenceQuote には、答えの根拠になる部分を、本文から一字も変えずに抜き出す。
                問いと答えは、本文と同じ言語で書く。
                """
        )
        switch questionKind {
        case .comprehension:
            let generatedChoiceQuestion = try await session.respond(to: prompt, generating: GeneratedChoiceQuestion.self).content
            return Question(
                id: UUID(),
                createdDateTime: Date(),
                kind: questionKind,
                text: generatedChoiceQuestion.questionText,
                choices: ([generatedChoiceQuestion.modelAnswer] + generatedChoiceQuestion.wrongChoices).shuffled(),
                modelAnswer: generatedChoiceQuestion.modelAnswer,
                evidenceQuote: generatedChoiceQuestion.evidenceQuote,
                readingSession: nil
            )
        case .summaryTrueFalse, .fillInTheBlank, .written:
            let generatedQuestion = try await session.respond(to: prompt, generating: GeneratedQuestion.self).content
            return Question(
                id: UUID(),
                createdDateTime: Date(),
                kind: questionKind,
                text: generatedQuestion.questionText,
                choices: questionKind == .summaryTrueFalse ? summaryTrueFalseChoices : [],
                modelAnswer: generatedQuestion.modelAnswer,
                evidenceQuote: generatedQuestion.evidenceQuote,
                readingSession: nil
            )
        }
    }

    /// 新しいセッションで端末内のモデルを 1 回呼び、`answerText` が `question` の模範の答えと同じ意味かを判定して返す。
    ///
    /// 冪等ではない: 同じ答えでも、モデルが違う判定を返すことがある。モデルが判定を返せなかった時は、そのエラーを投げる。
    func judgeWithModel(question: Question, answerText: String) async throws -> Bool {
        try await LanguageModelSession(
            instructions: """
                あなたは、読書の理解を確かめる問いへの答えを判定する。
                利用者の答えが模範の答えと同じ意味なら true、違う意味なら false を返す。
                表記や言い回しの違いは、同じ意味として扱う。
                """
        )
        .respond(to: makeJudgementPrompt(question: question, answerText: answerText), generating: Bool.self)
        .content
    }
}
