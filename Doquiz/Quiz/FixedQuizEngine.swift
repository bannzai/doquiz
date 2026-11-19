import FoundationModels

/// 端末内のモデルを呼ばずに、あらかじめ決めた値を返す偽の `QuizEngine`。
///
/// モデルを動かさずに、問いと判定を受け取る側 (画面・保存) を確かめるテストと Preview で使う。
struct FixedQuizEngine: QuizEngine {
    /// 端末内のモデルが使えるかとして返す値。
    let availability: SystemLanguageModel.Availability
    /// どの本文と出題の設定を渡されても返す問い。
    let questions: [Question]
    /// 穴埋めと記述の問いへの、どの答えにも返す判定。
    let modelJudgement: Bool

    /// 引数を読まずに `questions` を返す。エラーは投げない。
    func makeQuestions(
        currentReadingPageTexts: [String],
        previousReadingPageTexts: [String],
        questionKinds: [QuestionKind],
        questionGuidance: String?
    ) async throws -> [Question] {
        questions
    }

    /// 引数を読まずに `modelJudgement` を返す。エラーは投げない。
    func judgeWithModel(question: Question, answerText: String) async throws -> Bool {
        modelJudgement
    }
}
