import Foundation
import Testing

@testable import Doquiz

/// 端末内のモデルが返した値から問いを組み立てる形 (`assembleQuestion`) と、問い 1 問ごとの失敗と検査の扱い (`collectAcceptableQuestions`) を、モデルを呼ばずに確かめる。
@MainActor struct QuestionAssemblyTests {
    /// 問い 1 問を作る処理の失敗を表す、テスト用のエラー。`label` でどの問いの失敗かを見分ける。
    private struct MakeQuestionError: Error, Equatable {
        /// どの問いの失敗かを表す文字列。
        let label: String
    }

    /// 本文 `currentReadingText` から記述の問いを 1 問作る計画を返す。
    private func makeQuestionPlan(
        currentReadingText: String
    ) -> (questionKind: QuestionKind, currentReadingText: String, previousReadingText: String) {
        (questionKind: .written, currentReadingText: currentReadingText, previousReadingText: "")
    }

    /// `evidenceQuote` を根拠の引用にした記述の問いを返す。渡した本文と同じ文字列なら検査を通る。
    private func makeWrittenQuestion(evidenceQuote: String) -> Question {
        assembleQuestion(
            questionKind: .written,
            questionText: "問いの文",
            modelAnswer: "模範の答え",
            wrongChoices: [],
            evidenceQuote: evidenceQuote
        )
    }

    /// 四択の選択肢は、模範の答えと誤りの選択肢 3 つを合わせた 4 つになり、問いの文・模範の答え・根拠の引用はモデルが返した値のまま入る。
    @Test func 四択は模範の答えと誤りの選択肢を合わせた四つになる() {
        let question = assembleQuestion(
            questionKind: .comprehension,
            questionText: "吾輩は何か",
            modelAnswer: "猫",
            wrongChoices: ["犬", "人", "鳥"],
            evidenceQuote: "吾輩は猫である。"
        )
        #expect(Set(question.choices) == ["猫", "犬", "人", "鳥"])
        #expect(question.choices.count == 4)
        #expect(question.kind == .comprehension)
        #expect(question.text == "吾輩は何か")
        #expect(question.modelAnswer == "猫")
        #expect(question.evidenceQuote == "吾輩は猫である。")
        #expect(question.readingSession == nil)
    }

    /// 要約の正誤の選択肢は、モデルが誤りの選択肢を返していても「正しい」「誤り」の 2 つになる。
    @Test func 要約の正誤の選択肢は正しいと誤りの二つになる() {
        #expect(
            assembleQuestion(
                questionKind: .summaryTrueFalse,
                questionText: "吾輩は犬である",
                modelAnswer: "誤り",
                wrongChoices: ["余計な選択肢"],
                evidenceQuote: "吾輩は猫である。"
            ).choices == ["正しい", "誤り"]
        )
    }

    /// 穴埋めと記述は、モデルが誤りの選択肢を返していても選択肢が空になる。
    @Test(arguments: [QuestionKind.fillInTheBlank, .written])
    func 穴埋めと記述の選択肢は空になる(questionKind: QuestionKind) {
        #expect(
            assembleQuestion(
                questionKind: questionKind,
                questionText: "問いの文",
                modelAnswer: "猫",
                wrongChoices: ["余計な選択肢"],
                evidenceQuote: "吾輩は猫である。"
            ).choices.isEmpty
        )
    }

    /// 途中の 1 問が失敗しても、残りの問いが、計画の順に返る。
    @Test func 一問が失敗しても残りの問いが返る() async throws {
        #expect(
            try await collectAcceptableQuestions(
                questionPlans: ["一問目", "二問目", "三問目"].map { makeQuestionPlan(currentReadingText: $0) },
                selectedQuestionKinds: [.written],
                makeQuestion: { questionPlan in
                    if questionPlan.currentReadingText == "二問目" {
                        throw MakeQuestionError(label: "二問目")
                    }
                    return makeWrittenQuestion(evidenceQuote: questionPlan.currentReadingText)
                }
            ).map(\.evidenceQuote) == ["一問目", "三問目"]
        )
    }

    /// 全部の問いが失敗した時は、最初の問いのエラーが投げられる。
    @Test func 全問が失敗した時は最初のエラーが投げられる() async {
        await #expect(throws: MakeQuestionError(label: "一問目")) {
            _ = try await collectAcceptableQuestions(
                questionPlans: ["一問目", "二問目"].map { makeQuestionPlan(currentReadingText: $0) },
                selectedQuestionKinds: [.written],
                makeQuestion: { questionPlan in
                    throw MakeQuestionError(label: questionPlan.currentReadingText)
                }
            )
        }
    }

    /// 1 問が失敗し、残りの問いが検査で捨てられて 1 問も残らない時も、失敗した問いのエラーが投げられる。
    @Test func 失敗と検査で一問も残らない時は失敗のエラーが投げられる() async {
        await #expect(throws: MakeQuestionError(label: "二問目")) {
            _ = try await collectAcceptableQuestions(
                questionPlans: ["一問目", "二問目"].map { makeQuestionPlan(currentReadingText: $0) },
                selectedQuestionKinds: [.written],
                makeQuestion: { questionPlan in
                    if questionPlan.currentReadingText == "二問目" {
                        throw MakeQuestionError(label: "二問目")
                    }
                    return makeWrittenQuestion(evidenceQuote: "本文に無い引用")
                }
            )
        }
    }

    /// 失敗が 1 回も無く、作った問いが検査ですべて捨てられた時は、エラーを投げずに 0 問が返る。計画が無い時も 0 問が返る。
    @Test func 失敗が無く検査で全問が捨てられた時は0問が返る() async throws {
        #expect(
            try await collectAcceptableQuestions(
                questionPlans: ["一問目", "二問目"].map { makeQuestionPlan(currentReadingText: $0) },
                selectedQuestionKinds: [.written],
                makeQuestion: { _ in makeWrittenQuestion(evidenceQuote: "本文に無い引用") }
            ).isEmpty
        )
        #expect(
            try await collectAcceptableQuestions(
                questionPlans: [],
                selectedQuestionKinds: [.written],
                makeQuestion: { _ in throw MakeQuestionError(label: "呼ばれない") }
            ).isEmpty
        )
    }

    /// 検査で捨てられる問いと通る問いが混ざっている時は、通る問いだけが返る。
    @Test func 検査を通った問いだけが返る() async throws {
        #expect(
            try await collectAcceptableQuestions(
                questionPlans: ["一問目", "二問目"].map { makeQuestionPlan(currentReadingText: $0) },
                selectedQuestionKinds: [.written],
                makeQuestion: { questionPlan in
                    makeWrittenQuestion(evidenceQuote: questionPlan.currentReadingText == "一問目" ? "本文に無い引用" : questionPlan.currentReadingText)
                }
            ).map(\.evidenceQuote) == ["二問目"]
        )
    }

    /// 中止は、先に作れた問いがあっても飲み込まれず、そのまま投げられる。
    @Test func 中止はそのまま投げられる() async {
        await #expect(throws: CancellationError.self) {
            _ = try await collectAcceptableQuestions(
                questionPlans: ["一問目", "二問目"].map { makeQuestionPlan(currentReadingText: $0) },
                selectedQuestionKinds: [.written],
                makeQuestion: { questionPlan in
                    if questionPlan.currentReadingText == "二問目" {
                        throw CancellationError()
                    }
                    return makeWrittenQuestion(evidenceQuote: questionPlan.currentReadingText)
                }
            )
        }
    }
}
