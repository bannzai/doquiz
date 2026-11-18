import Foundation
import Testing

@testable import Doquiz

/// 端末内のモデルが返した問いの検査 (`isAcceptableQuestion`) が、出してはいけない問いだけを捨てることを確かめる。
@MainActor struct QuestionAcceptanceTests {
    /// 検査に渡す、今回の読書の本文。画面の行ごとに改行が入っている。
    private let currentReadingText = "吾輩は猫である。名前は\nまだ無い。"
    /// 検査に渡す、前の読書の本文。
    private let previousReadingText = "どこで生れたか頓と見当がつかぬ。"

    /// 保存しない問いを作る。
    private func makeQuestion(kind: QuestionKind, choices: [String], modelAnswer: String, evidenceQuote: String) -> Question {
        Question(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
            kind: kind,
            text: "問いの文",
            choices: choices,
            modelAnswer: modelAnswer,
            evidenceQuote: evidenceQuote,
            readingSession: nil
        )
    }

    /// `question` を、テストの本文と `selectedQuestionKinds` で検査した結果を返す。
    private func isAcceptable(question: Question, selectedQuestionKinds: [QuestionKind]) -> Bool {
        isAcceptableQuestion(
            question: question,
            selectedQuestionKinds: selectedQuestionKinds,
            currentReadingText: currentReadingText,
            previousReadingText: previousReadingText
        )
    }

    /// 選ばれた種類で、根拠の引用が本文にあり、選択式なら選択肢に模範の答えがある問いは、4 つの種類のどれも残る。
    @Test func 条件を満たす問いは残る() {
        #expect(
            isAcceptable(
                question: makeQuestion(
                    kind: .comprehension,
                    choices: ["犬", "猫", "人", "鳥"],
                    modelAnswer: "猫",
                    evidenceQuote: "吾輩は猫である。"
                ),
                selectedQuestionKinds: [.comprehension]
            )
        )
        #expect(
            isAcceptable(
                question: makeQuestion(
                    kind: .summaryTrueFalse,
                    choices: ["正しい", "誤り"],
                    modelAnswer: "誤り",
                    evidenceQuote: "吾輩は猫である。"
                ),
                selectedQuestionKinds: [.summaryTrueFalse]
            )
        )
        #expect(
            isAcceptable(
                question: makeQuestion(kind: .fillInTheBlank, choices: [], modelAnswer: "猫", evidenceQuote: "吾輩は猫である。"),
                selectedQuestionKinds: [.fillInTheBlank]
            )
        )
        #expect(
            isAcceptable(
                question: makeQuestion(kind: .written, choices: [], modelAnswer: "猫", evidenceQuote: "吾輩は猫である。"),
                selectedQuestionKinds: [.written]
            )
        )
    }

    /// 同じ問いでも、種類が選ばれていなければ捨てられ、選ばれていれば残る。
    @Test func 選ばれていない種類の問いは捨てられる() {
        let question = makeQuestion(kind: .written, choices: [], modelAnswer: "猫", evidenceQuote: "吾輩は猫である。")
        #expect(!isAcceptable(question: question, selectedQuestionKinds: [.comprehension, .summaryTrueFalse, .fillInTheBlank]))
        #expect(!isAcceptable(question: question, selectedQuestionKinds: []))
        #expect(isAcceptable(question: question, selectedQuestionKinds: [.comprehension, .written]))
    }

    /// 根拠の引用が、渡した本文に無い文・本文と 1 文字違う文・空・空白だけの時は捨てられる。
    @Test(arguments: ["吾輩は犬である。", "本文に無い文", "", " \n "])
    func 根拠の引用が本文に無い問いは捨てられる(evidenceQuote: String) {
        #expect(
            !isAcceptable(
                question: makeQuestion(kind: .written, choices: [], modelAnswer: "猫", evidenceQuote: evidenceQuote),
                selectedQuestionKinds: [.written]
            )
        )
    }

    /// 根拠の引用は、本文の改行をまたいでいても、引用の側に空白や改行が入っていても、前の読書の本文の一部でも、本文に含まれるとして残る。
    @Test(arguments: ["名前はまだ無い。", "名前は まだ無い。", "吾輩は猫である。\n名前は", "頓と見当がつかぬ。"])
    func 根拠の引用は空白と改行を除いて本文と比べる(evidenceQuote: String) {
        #expect(
            isAcceptable(
                question: makeQuestion(kind: .written, choices: [], modelAnswer: "猫", evidenceQuote: evidenceQuote),
                selectedQuestionKinds: [.written]
            )
        )
    }

    /// 今回の本文の末尾と前の本文の先頭 (またはその逆) をつないだ文は、どちらの本文にも無いので捨てられる。
    @Test(arguments: ["まだ無い。どこで生れたか", "見当がつかぬ。吾輩は猫"])
    func 二つの本文にまたがる根拠の引用は捨てられる(evidenceQuote: String) {
        #expect(
            !isAcceptable(
                question: makeQuestion(kind: .written, choices: [], modelAnswer: "猫", evidenceQuote: evidenceQuote),
                selectedQuestionKinds: [.written]
            )
        )
    }

    /// 四択と要約の正誤は、選択肢の中に模範の答えが無ければ捨てられる。選択肢が空の時も同じ。
    @Test(arguments: [
        (QuestionKind.comprehension, ["犬", "虎", "人", "鳥"], "猫"),
        (QuestionKind.comprehension, [String](), "猫"),
        (QuestionKind.summaryTrueFalse, ["正しい", "誤り"], "合っている"),
        (QuestionKind.summaryTrueFalse, [String](), "正しい"),
    ])
    func 選択肢に模範の答えが無い選択式の問いは捨てられる(kind: QuestionKind, choices: [String], modelAnswer: String) {
        #expect(
            !isAcceptable(
                question: makeQuestion(kind: kind, choices: choices, modelAnswer: modelAnswer, evidenceQuote: "吾輩は猫である。"),
                selectedQuestionKinds: [kind]
            )
        )
    }
}
