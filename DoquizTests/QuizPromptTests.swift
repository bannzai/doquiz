import Foundation
import Testing

@testable import Doquiz

/// 端末内のモデルに渡す依頼の文 (`makeQuestionPrompt`・`makeJudgementPrompt`) に、渡した本文と出題への希望が決めた形で入ることを確かめる。
@MainActor struct QuizPromptTests {
    /// 出題への希望と前の読書の本文がある時は、問いの作り方・希望・前に読んだ本文・今回読んだ本文の順に入る。
    @Test func 希望と前の読書の本文がある時は順に入る() {
        #expect(
            makeQuestionPrompt(
                questionKind: .written,
                currentReadingText: "今回の本文",
                previousReadingText: "前の本文",
                questionGuidance: "用語の定義を中心に"
            )
                == """
                \(makeQuestionKindRequest(questionKind: .written))

                出題への希望: 用語の定義を中心に

                前に読んだ本文:
                前の本文

                今回読んだ本文:
                今回の本文
                """
        )
    }

    /// 出題への希望が無い (nil か空) 時と、前の読書の本文が空の時は、その行と節が入らない。
    @Test(arguments: [String?.none, ""])
    func 希望と前の読書の本文が無い時はその節が入らない(questionGuidance: String?) {
        #expect(
            makeQuestionPrompt(
                questionKind: .written,
                currentReadingText: "今回の本文",
                previousReadingText: "",
                questionGuidance: questionGuidance
            )
                == """
                \(makeQuestionKindRequest(questionKind: .written))

                今回読んだ本文:
                今回の本文
                """
        )
    }

    /// 出題への希望は、200 文字ちょうどならそのまま入り、201 文字なら先頭の 200 文字だけが入る。
    @Test func 出題への希望は200文字までが入る() {
        #expect(
            makeQuestionPrompt(
                questionKind: .written,
                currentReadingText: "今回の本文",
                previousReadingText: "",
                questionGuidance: String(repeating: "希", count: 200)
            ).contains("出題への希望: " + String(repeating: "希", count: 200) + "\n")
        )
        #expect(
            makeQuestionPrompt(
                questionKind: .written,
                currentReadingText: "今回の本文",
                previousReadingText: "",
                questionGuidance: String(repeating: "希", count: 200) + "望"
            ).contains("出題への希望: " + String(repeating: "希", count: 200) + "\n")
        )
    }

    /// 問いの作り方の文は、4 つの種類で互いに違い、要約の正誤の文には選択肢の 2 つの言葉が入る。
    @Test func 問いの作り方の文は種類ごとに違う() {
        #expect(
            Set(
                [QuestionKind.comprehension, .summaryTrueFalse, .fillInTheBlank, .written].map {
                    makeQuestionKindRequest(questionKind: $0)
                }
            ).count == 4
        )
        #expect(makeQuestionKindRequest(questionKind: .summaryTrueFalse).contains("「正しい」"))
        #expect(makeQuestionKindRequest(questionKind: .summaryTrueFalse).contains("「誤り」"))
    }

    /// 判定を頼む文には、問いの文・模範の答え・根拠の引用・利用者の答えが、この順に 1 行ずつ入る。
    @Test func 判定を頼む文に問いと答えが入る() {
        #expect(
            makeJudgementPrompt(
                question: Question(
                    id: UUID(),
                    createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
                    kind: .fillInTheBlank,
                    text: "吾輩は＿＿である",
                    choices: [],
                    modelAnswer: "猫",
                    evidenceQuote: "吾輩は猫である。",
                    readingSession: nil
                ),
                answerText: "ねこ"
            )
                == """
                問い: 吾輩は＿＿である
                模範の答え: 猫
                根拠の本文: 吾輩は猫である。
                利用者の答え: ねこ
                """
        )
    }
}
