import Testing

@testable import Doquiz

/// 問いの数の決め方 (`questionCount`) と、問いごとに端末内のモデルへ渡す本文の選び方 (`planQuestions`) を確かめる。
@MainActor struct QuestionPlanTests {
    /// 本文が空なら 0 問、1 文字でもあれば 1 問、800 文字ごとに 1 問増え、10 問を超えない。本文が増えても問いの数は減らない。
    @Test(arguments: [
        (0, 0),
        (1, 1),
        (800, 1),
        (801, 2),
        (1600, 2),
        (1601, 3),
        (8000, 10),
        (8001, 10),
        (100_000, 10),
    ])
    func 問いの数は本文の文字数で決まる(currentReadingCharacterCount: Int, expectedQuestionCount: Int) {
        #expect(questionCount(currentReadingCharacterCount: currentReadingCharacterCount) == expectedQuestionCount)
    }

    /// ページの本文は、前後の空白と改行を除き、空のページを飛ばして、渡した順に改行でつながる。
    @Test func ページの本文は空のページを除いて順につながる() {
        #expect(joinPageTexts(pageTexts: ["  一ページ目\n", "", " \n ", "二ページ目"]) == "一ページ目\n二ページ目")
        #expect(joinPageTexts(pageTexts: []) == "")
    }

    /// 今回の読書の本文が無い (ページが無い・空白だけ) 時は、前の読書の本文があっても問いを作らない。
    @Test(arguments: [[String](), [""], ["  \n"]])
    func 今回の読書の本文が空なら問いを作らない(currentReadingPageTexts: [String]) {
        #expect(
            planQuestions(
                currentReadingPageTexts: currentReadingPageTexts,
                previousReadingPageTexts: ["前の読書の本文"],
                questionKinds: [.written],
                characterLimit: 100
            ).isEmpty
        )
    }

    /// 問いの種類が 1 つも選ばれていない時は、本文があっても問いを作らない。
    @Test func 問いの種類が選ばれていなければ問いを作らない() {
        #expect(
            planQuestions(
                currentReadingPageTexts: ["今回の読書の本文"],
                previousReadingPageTexts: [],
                questionKinds: [],
                characterLimit: 100
            ).isEmpty
        )
    }

    /// 一度に渡せる文字数が 0 以下の時は問いを作らず、1 文字なら今回の本文の 1 文字だけを渡す。
    @Test func 渡せる文字数が0以下なら問いを作らない() throws {
        #expect(
            planQuestions(
                currentReadingPageTexts: ["今回の読書の本文"],
                previousReadingPageTexts: [],
                questionKinds: [.written],
                characterLimit: 0
            ).isEmpty
        )
        #expect(
            planQuestions(
                currentReadingPageTexts: ["今回の読書の本文"],
                previousReadingPageTexts: [],
                questionKinds: [.written],
                characterLimit: -1
            ).isEmpty
        )
        let questionPlans = planQuestions(
            currentReadingPageTexts: ["今回の読書の本文"],
            previousReadingPageTexts: ["前"],
            questionKinds: [.written],
            characterLimit: 1
        )
        try #require(questionPlans.count == 1)
        #expect(questionPlans[0].currentReadingText == "今")
        #expect(questionPlans[0].previousReadingText == "")
    }

    /// 一度に渡せる文字数を超える本文を渡すと、今回の本文だけが上限の文字数まで残り、前の読書の本文は渡されない。
    @Test func 上限を超える本文は今回の読書を優先して上限に収まる() throws {
        let questionPlans = planQuestions(
            currentReadingPageTexts: [String(repeating: "今", count: 500)],
            previousReadingPageTexts: [String(repeating: "前", count: 500)],
            questionKinds: [.written],
            characterLimit: 300
        )
        try #require(questionPlans.count == 1)
        #expect(questionPlans[0].currentReadingText == String(repeating: "今", count: 300))
        #expect(questionPlans[0].previousReadingText == "")
    }

    /// 今回の本文が上限より短い時は、今回の本文の全部と、前の読書の本文の末尾 (今回の読書に近い側) が、合わせて上限の文字数まで渡される。
    @Test func 上限の残りは前の読書の本文の末尾で埋まる() throws {
        let questionPlans = planQuestions(
            currentReadingPageTexts: [String(repeating: "今", count: 100)],
            previousReadingPageTexts: [String(repeating: "古", count: 400), String(repeating: "新", count: 150)],
            questionKinds: [.written],
            characterLimit: 300
        )
        try #require(questionPlans.count == 1)
        #expect(questionPlans[0].currentReadingText == String(repeating: "今", count: 100))
        // 前の読書の本文は「古」400 文字 + 改行 + 「新」150 文字。末尾の 200 文字は「古」49 文字 + 改行 + 「新」150 文字。
        #expect(
            questionPlans[0].previousReadingText
                == String(repeating: "古", count: 49) + "\n" + String(repeating: "新", count: 150)
        )
    }

    /// 前の読書の本文が上限の残りより短い時は、前の読書の本文の全部が渡される。
    @Test func 前の読書の本文が残りより短ければ全部渡される() throws {
        let questionPlans = planQuestions(
            currentReadingPageTexts: ["今回の本文"],
            previousReadingPageTexts: ["前の本文"],
            questionKinds: [.written],
            characterLimit: 300
        )
        try #require(questionPlans.count == 1)
        #expect(questionPlans[0].currentReadingText == "今回の本文")
        #expect(questionPlans[0].previousReadingText == "前の本文")
    }

    /// 今回の本文は問いの数で等分され、問いごとに別の区間が、読んだ順に渡される。
    @Test func 今回の本文は問いの数で等分して順に渡される() {
        #expect(
            planQuestions(
                currentReadingPageTexts: [String(repeating: "一", count: 800) + String(repeating: "二", count: 800)],
                previousReadingPageTexts: [],
                questionKinds: [.written],
                characterLimit: 2000
            ).map(\.currentReadingText) == [String(repeating: "一", count: 800), String(repeating: "二", count: 800)]
        )
    }

    /// 等分した区間が上限より長い時は、どの問いでも、渡す本文が上限の文字数に収まる。
    @Test func 等分した区間が上限より長くても上限に収まる() {
        let questionPlans = planQuestions(
            currentReadingPageTexts: [String(repeating: "今", count: 20_000)],
            previousReadingPageTexts: [String(repeating: "前", count: 20_000)],
            questionKinds: [.written],
            characterLimit: 1500
        )
        #expect(questionPlans.map(\.currentReadingText.count) == Array(repeating: 1500, count: 10))
        #expect(questionPlans.map(\.previousReadingText.count) == Array(repeating: 0, count: 10))
    }

    /// 問いの種類は、選ばれた種類を先頭から順に繰り返して割り当てられる。
    @Test func 問いの種類は選ばれた種類を順に繰り返す() {
        #expect(
            planQuestions(
                currentReadingPageTexts: [String(repeating: "今", count: 2400)],
                previousReadingPageTexts: [],
                questionKinds: [.written, .comprehension],
                characterLimit: 2000
            ).map(\.questionKind) == [.written, .comprehension, .written]
        )
    }
}
