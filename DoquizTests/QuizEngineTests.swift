import Foundation
import FoundationModels
import Testing

@testable import Doquiz

/// 偽の `FixedQuizEngine` が決めた値を返すことと、`QuizEngine` の判定 (`judge`) が問いの種類で判定の方法を分けることを確かめる。
@MainActor struct QuizEngineTests {
    /// 保存しない問いを作る。
    private func makeQuestion(kind: QuestionKind, choices: [String], modelAnswer: String) -> Question {
        Question(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
            kind: kind,
            text: "問いの文",
            choices: choices,
            modelAnswer: modelAnswer,
            evidenceQuote: "根拠の引用",
            readingSession: nil
        )
    }

    /// 端末内のモデルが使えない状態の時に、使えない理由 (端末が対応していない・Apple Intelligence が無効・モデルの準備ができていない) を呼び出し側が受け取れる。
    @Test(arguments: [
        SystemLanguageModel.Availability.UnavailableReason.deviceNotEligible,
        .appleIntelligenceNotEnabled,
        .modelNotReady,
    ])
    func 使えない時は使えない理由を受け取れる(unavailableReason: SystemLanguageModel.Availability.UnavailableReason) {
        #expect(
            FixedQuizEngine(availability: .unavailable(unavailableReason), questions: [], modelJudgement: false).availability
                == .unavailable(unavailableReason)
        )
    }

    /// 端末内のモデルが使える状態の時は、使えるという値を受け取れる。
    @Test func 使える時は使えるという値を受け取れる() {
        #expect(FixedQuizEngine(availability: .available, questions: [], modelJudgement: false).availability == .available)
    }

    /// 偽の実装は、渡した本文と出題の設定に関係なく、決めた問いをそのまま返す。
    @Test func 偽の実装は決めた問いを返す() async throws {
        let question = makeQuestion(kind: .comprehension, choices: ["犬", "猫", "人", "鳥"], modelAnswer: "猫")
        #expect(
            try await FixedQuizEngine(availability: .available, questions: [question], modelJudgement: false)
                .makeQuestions(
                    currentReadingPageTexts: [],
                    previousReadingPageTexts: [],
                    questionKinds: [],
                    questionGuidance: nil
                )
                .map(\.id) == [question.id]
        )
    }

    /// 四択と要約の正誤は、選んだ選択肢が模範の答えと同じなら合っていると判定され、端末内のモデルの判定 (ここでは「合っていない」) は使われない。
    @Test(arguments: [
        (QuestionKind.comprehension, ["犬", "猫", "人", "鳥"], "猫"),
        (QuestionKind.summaryTrueFalse, ["正しい", "誤り"], "誤り"),
    ])
    func 選択式は模範の答えと同じ選択肢なら合っている(kind: QuestionKind, choices: [String], modelAnswer: String) async throws {
        #expect(
            try await FixedQuizEngine(availability: .available, questions: [], modelJudgement: false)
                .judge(question: makeQuestion(kind: kind, choices: choices, modelAnswer: modelAnswer), answerText: modelAnswer)
        )
    }

    /// 四択と要約の正誤は、選んだ選択肢が模範の答えと違えば合っていないと判定され、端末内のモデルの判定 (ここでは「合っている」) は使われない。
    @Test(arguments: [
        (QuestionKind.comprehension, ["犬", "猫", "人", "鳥"], "猫", "犬"),
        (QuestionKind.summaryTrueFalse, ["正しい", "誤り"], "誤り", "正しい"),
    ])
    func 選択式は模範の答えと違う選択肢なら合っていない(
        kind: QuestionKind,
        choices: [String],
        modelAnswer: String,
        answerText: String
    ) async throws {
        #expect(
            try await !FixedQuizEngine(availability: .available, questions: [], modelJudgement: true)
                .judge(question: makeQuestion(kind: kind, choices: choices, modelAnswer: modelAnswer), answerText: answerText)
        )
    }

    /// 穴埋めと記述は、答えが模範の答えと同じ文字列かに関係なく、端末内のモデルの判定がそのまま返る。
    @Test(arguments: [
        (QuestionKind.fillInTheBlank, true),
        (QuestionKind.fillInTheBlank, false),
        (QuestionKind.written, true),
        (QuestionKind.written, false),
    ])
    func 穴埋めと記述は端末内のモデルの判定が返る(kind: QuestionKind, modelJudgement: Bool) async throws {
        let fixedQuizEngine = FixedQuizEngine(availability: .available, questions: [], modelJudgement: modelJudgement)
        #expect(
            try await fixedQuizEngine.judge(
                question: makeQuestion(kind: kind, choices: [], modelAnswer: "猫"),
                answerText: "猫"
            ) == modelJudgement
        )
        #expect(
            try await fixedQuizEngine.judge(
                question: makeQuestion(kind: kind, choices: [], modelAnswer: "猫"),
                answerText: "犬"
            ) == modelJudgement
        )
    }
}
