import Foundation
import FoundationModels
import SwiftData
import Testing

@testable import Doquiz

/// 履歴の処理 (読書の記録を並べる・問いに答え直す・読書の記録と本を消す) と、履歴に出す文を、端末に書き込まないメモリ内の保存先で確かめる。
@MainActor struct HistoryTests {
    /// 履歴の処理を実行する context。
    private let writingContext: ModelContext
    /// 保存先に書かれた結果を読む context。書いた context に残っている値ではなく、保存先の値を確かめるために分ける。
    private let readingContext: ModelContext
    /// 履歴を見る本。読書の記録を 3 件持つ。
    private let book: Book
    /// `book` のいちばん古い読書の記録 (ページ 2 件・問い 2 問・回答 2 件)。
    private let oldestReadingSession: ReadingSession
    /// `book` の 2 番目に古い読書の記録 (終えた日時が無い。ページ 1 件・問い 0 問)。
    private let middleReadingSession: ReadingSession
    /// `book` のいちばん新しい読書の記録 (ページ 1 件・問い 1 問・回答 1 件)。
    private let newestReadingSession: ReadingSession
    /// `oldestReadingSession` の、回答を 2 件持つ四択の問い (1 件目は合っていない「犬」、2 件目は合っている「猫」)。
    private let answeredQuestion: Question
    /// `oldestReadingSession` の、回答をまだ持たない穴埋めの問い。`answeredQuestion` より後に作った。
    private let unansweredQuestion: Question
    /// もう 1 冊の本。読書の記録 1 件・ページ 1 件・問い 1 問・回答 1 件を持つ。
    private let otherBook: Book

    /// テストごとに、メモリ内の保存先を新しく作り、本 2 冊・読書の記録 4 件・ページ 5 件・問い 4 問・回答 4 件を保存する。
    ///
    /// 読書の記録・問い・回答・ページは、日時の順と違う順に足す (保存した順ではなく、日時で並ぶことを確かめるため)。
    init() throws {
        let modelContainer = try makeModelContainer(isStoredInMemoryOnly: true)
        writingContext = ModelContext(modelContainer)
        readingContext = ModelContext(modelContainer)
        book = Book(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 0),
            title: "潮見町の灯台日誌",
            questionKinds: [.comprehension, .fillInTheBlank],
            questionGuidance: nil
        )
        writingContext.insert(book)

        middleReadingSession = ReadingSession(id: UUID(), startedDateTime: Date(timeIntervalSince1970: 2_000), endedDateTime: nil, book: book)
        writingContext.insert(middleReadingSession)
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 2_100), text: "二回目の一枚目", readingSession: middleReadingSession))

        newestReadingSession = ReadingSession(
            id: UUID(),
            startedDateTime: Date(timeIntervalSince1970: 3_000),
            endedDateTime: Date(timeIntervalSince1970: 3_600),
            book: book
        )
        writingContext.insert(newestReadingSession)
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 3_100), text: "三回目の一枚目", readingSession: newestReadingSession))
        let newestQuestion = Question(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 3_700),
            kind: .written,
            text: "三回目の問い",
            choices: [],
            modelAnswer: "答えの例",
            evidenceQuote: "三回目の一枚目",
            readingSession: newestReadingSession
        )
        writingContext.insert(newestQuestion)
        writingContext.insert(Answer(id: UUID(), answeredDateTime: Date(timeIntervalSince1970: 3_800), text: "三回目の答え", isCorrect: true, question: newestQuestion))

        oldestReadingSession = ReadingSession(
            id: UUID(),
            startedDateTime: Date(timeIntervalSince1970: 1_000),
            endedDateTime: Date(timeIntervalSince1970: 1_600),
            book: book
        )
        writingContext.insert(oldestReadingSession)
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 1_200), text: "一回目の二枚目", readingSession: oldestReadingSession))
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 1_100), text: "一回目の一枚目", readingSession: oldestReadingSession))
        unansweredQuestion = Question(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 1_701),
            kind: .fillInTheBlank,
            text: "灯台守は＿＿を拭く",
            choices: [],
            modelAnswer: "レンズ",
            evidenceQuote: "一回目の二枚目",
            readingSession: oldestReadingSession
        )
        writingContext.insert(unansweredQuestion)
        answeredQuestion = Question(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 1_700),
            kind: .comprehension,
            text: "灯台にいた動物は何か",
            choices: ["犬", "猫", "人", "鳥"],
            modelAnswer: "猫",
            evidenceQuote: "一回目の一枚目",
            readingSession: oldestReadingSession
        )
        writingContext.insert(answeredQuestion)
        writingContext.insert(Answer(id: UUID(), answeredDateTime: Date(timeIntervalSince1970: 9_000), text: "猫", isCorrect: true, question: answeredQuestion))
        writingContext.insert(Answer(id: UUID(), answeredDateTime: Date(timeIntervalSince1970: 1_800), text: "犬", isCorrect: false, question: answeredQuestion))

        otherBook = Book(id: UUID(), createdDateTime: Date(timeIntervalSince1970: 0), title: "はじめての堆肥づくり", questionKinds: [.summaryTrueFalse], questionGuidance: nil)
        writingContext.insert(otherBook)
        let otherBookReadingSession = ReadingSession(
            id: UUID(),
            startedDateTime: Date(timeIntervalSince1970: 2_500),
            endedDateTime: Date(timeIntervalSince1970: 2_900),
            book: otherBook
        )
        writingContext.insert(otherBookReadingSession)
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 2_600), text: "別の本のページ", readingSession: otherBookReadingSession))
        let otherBookQuestion = Question(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 2_950),
            kind: .summaryTrueFalse,
            text: "別の本の問い",
            choices: ["正しい", "誤り"],
            modelAnswer: "正しい",
            evidenceQuote: "別の本のページ",
            readingSession: otherBookReadingSession
        )
        writingContext.insert(otherBookQuestion)
        writingContext.insert(Answer(id: UUID(), answeredDateTime: Date(timeIntervalSince1970: 2_960), text: "誤り", isCorrect: false, question: otherBookQuestion))
        try writingContext.save()
    }

    /// 保存先への書き込みに起こさせる失敗。
    private struct SaveFailure: Error {}

    /// 保存先にある本・読書の記録・ページ・問い・回答の件数を、この順に返す。
    private func savedCounts() throws -> [Int] {
        [
            try readingContext.fetchCount(FetchDescriptor<Book>()),
            try readingContext.fetchCount(FetchDescriptor<ReadingSession>()),
            try readingContext.fetchCount(FetchDescriptor<CapturedPage>()),
            try readingContext.fetchCount(FetchDescriptor<Question>()),
            try readingContext.fetchCount(FetchDescriptor<Answer>()),
        ]
    }

    /// 履歴に並ぶ読書の記録は、その本のものだけで、読書を始めた日時の新しい順に並ぶ (終えた日時の無い読書の記録も含む)。
    @Test func 履歴の読書の記録はその本のものだけが新しい順に並ぶ() throws {
        #expect(
            try readingContext.fetch(historyReadingSessionsDescriptor(bookID: book.id)).map(\.id)
                == [newestReadingSession.id, middleReadingSession.id, oldestReadingSession.id]
        )
        #expect(try readingContext.fetch(historyReadingSessionsDescriptor(bookID: otherBook.id)).map(\.startedDateTime) == [Date(timeIntervalSince1970: 2_500)])
    }

    /// 読書の記録が 1 件も無い本と、保存先に無い本の `id` では、履歴の読書の記録が 0 件になる。
    @Test func 読書の記録が無い本の履歴は0件になる() throws {
        let newBook = Book(id: UUID(), createdDateTime: Date(timeIntervalSince1970: 0), title: "霧の岬の航海記", questionKinds: [.written], questionGuidance: nil)
        writingContext.insert(newBook)
        try writingContext.save()

        #expect(try readingContext.fetch(historyReadingSessionsDescriptor(bookID: newBook.id)).isEmpty)
        #expect(try readingContext.fetch(historyReadingSessionsDescriptor(bookID: UUID())).isEmpty)
    }

    /// 読書の記録の問いは作った日時の古い順、問いへの回答は答えた日時の古い順、ページは取り込んだ日時の古い順に並ぶ。
    @Test func 問いと回答とページは日時の古い順に並ぶ() {
        #expect(historyQuestions(readingSession: oldestReadingSession).map(\.id) == [answeredQuestion.id, unansweredQuestion.id])
        #expect(historyAnswers(question: answeredQuestion).map(\.text) == ["犬", "猫"])
        #expect(historyCapturedPages(readingSession: oldestReadingSession).map(\.text) == ["一回目の一枚目", "一回目の二枚目"])
        #expect(historyQuestions(readingSession: middleReadingSession).isEmpty)
        #expect(historyAnswers(question: unansweredQuestion).isEmpty)
    }

    /// 履歴の問いに答え直すと、その問いの回答が 1 件増え、前の 2 件の回答は答えも判定も変わらずに残り、新しい回答がいちばん新しい回答になる。
    @Test func 履歴の問いに答え直すと回答が1件増えて前の回答が残る() async throws {
        let reanswer = try await answerQuizQuestion(
            question: answeredQuestion,
            answerText: "鳥",
            quizEngine: FixedQuizEngine(availability: .available, questions: [], modelJudgement: true),
            modelContext: writingContext,
            currentDateTime: { Date(timeIntervalSince1970: 10_000) },
            save: writingContext.save
        )

        #expect(try savedCounts() == [2, 4, 5, 4, 5])
        let fetchedQuestion = try #require(try readingContext.fetch(FetchDescriptor<Question>()).first { $0.id == answeredQuestion.id })
        #expect(historyAnswers(question: fetchedQuestion).map(\.text) == ["犬", "猫", "鳥"])
        #expect(historyAnswers(question: fetchedQuestion).map(\.isCorrect) == [false, true, false])
        #expect(historyAnswers(question: fetchedQuestion).last?.id == reanswer.id)
    }

    /// まだ答えていない問いに履歴から答えると、回答が 1 件になる。
    @Test func まだ答えていない問いに答えると回答が1件になる() async throws {
        _ = try await answerQuizQuestion(
            question: unansweredQuestion,
            answerText: "レンズ",
            quizEngine: FixedQuizEngine(availability: .available, questions: [], modelJudgement: true),
            modelContext: writingContext,
            currentDateTime: { Date(timeIntervalSince1970: 10_000) },
            save: writingContext.save
        )

        #expect(historyAnswers(question: unansweredQuestion).map(\.text) == ["レンズ"])
        #expect(historyAnswers(question: unansweredQuestion).map(\.isCorrect) == [true])
        #expect(try savedCounts() == [2, 4, 5, 4, 5])
    }

    /// 読書の記録を 1 件消すと、そのページ 2 件・問い 2 問・回答 2 件が消え、本と、同じ本のほかの読書の記録 2 件と、別の本のデータは残る。
    @Test func 読書の記録を消すとそのページと問いと回答が消えて本とほかの読書の記録は残る() throws {
        try deleteReadingSession(readingSession: oldestReadingSession, modelContext: writingContext, save: writingContext.save)

        #expect(try savedCounts() == [2, 3, 3, 2, 2])
        #expect(
            try readingContext.fetch(historyReadingSessionsDescriptor(bookID: book.id)).map(\.id)
                == [newestReadingSession.id, middleReadingSession.id]
        )
        #expect(try readingContext.fetch(FetchDescriptor<CapturedPage>()).map(\.text).sorted() == ["三回目の一枚目", "二回目の一枚目", "別の本のページ"])
        #expect(try readingContext.fetch(FetchDescriptor<Question>()).map(\.text).sorted() == ["三回目の問い", "別の本の問い"])
        #expect(try readingContext.fetch(FetchDescriptor<Answer>()).map(\.text).sorted() == ["三回目の答え", "誤り"])
    }

    /// ページも問いも無い読書の記録を消すと、その読書の記録だけが消える。
    @Test func ページも問いも無い読書の記録を消すとその記録だけが消える() throws {
        let emptyReadingSession = ReadingSession(id: UUID(), startedDateTime: Date(timeIntervalSince1970: 4_000), endedDateTime: nil, book: book)
        writingContext.insert(emptyReadingSession)
        try writingContext.save()
        #expect(try savedCounts() == [2, 5, 5, 4, 4])

        try deleteReadingSession(readingSession: emptyReadingSession, modelContext: writingContext, save: writingContext.save)

        #expect(try savedCounts() == [2, 4, 5, 4, 4])
    }

    /// 本を消すと、その本の読書の記録 3 件・ページ 4 件・問い 3 問・回答 3 件がすべて消え、別の本とそのデータは残る。
    @Test func 本を消すとその本のデータがすべて消えてほかの本のデータは残る() throws {
        try deleteBook(book: book, modelContext: writingContext, save: writingContext.save)

        #expect(try savedCounts() == [1, 1, 1, 1, 1])
        #expect(try readingContext.fetch(FetchDescriptor<Book>()).map(\.title) == ["はじめての堆肥づくり"])
        #expect(try readingContext.fetch(historyReadingSessionsDescriptor(bookID: otherBook.id)).count == 1)
        #expect(try readingContext.fetch(FetchDescriptor<CapturedPage>()).map(\.text) == ["別の本のページ"])
        #expect(try readingContext.fetch(FetchDescriptor<Question>()).map(\.text) == ["別の本の問い"])
        #expect(try readingContext.fetch(FetchDescriptor<Answer>()).map(\.text) == ["誤り"])
    }

    /// 読書の記録が無い本を消すと、その本だけが消える。
    @Test func 読書の記録が無い本を消すとその本だけが消える() throws {
        let newBook = Book(id: UUID(), createdDateTime: Date(timeIntervalSince1970: 0), title: "霧の岬の航海記", questionKinds: [.written], questionGuidance: nil)
        writingContext.insert(newBook)
        try writingContext.save()

        try deleteBook(book: newBook, modelContext: writingContext, save: writingContext.save)

        #expect(try savedCounts() == [2, 4, 5, 4, 4])
    }

    /// 読書の記録の削除の保存に失敗した時は、保存の error が投げられ、後の保存でもその読書の記録とページ・問い・回答は消えない。
    @Test func 読書の記録の削除の保存に失敗した時は後の保存でも消えない() throws {
        #expect(throws: SaveFailure.self) {
            try deleteReadingSession(readingSession: oldestReadingSession, modelContext: writingContext, save: { throw SaveFailure() })
        }

        try writingContext.save()
        #expect(try savedCounts() == [2, 4, 5, 4, 4])
    }

    /// 本の削除の保存に失敗した時は、保存の error が投げられ、後の保存でもその本とその下のデータは消えない。
    @Test func 本の削除の保存に失敗した時は後の保存でも消えない() throws {
        #expect(throws: SaveFailure.self) {
            try deleteBook(book: book, modelContext: writingContext, save: { throw SaveFailure() })
        }

        try writingContext.save()
        #expect(try savedCounts() == [2, 4, 5, 4, 4])
    }

    /// ページの数と問いの数の文は、保存済みのページと問いから数えた数で出る (0 件の時も数を出す)。
    @Test func ページの数と問いの数の文は保存済みのデータから数える() {
        #expect(historyReadingSessionCountsText(readingSession: oldestReadingSession) == "2 ページ ・ 2 問")
        #expect(historyReadingSessionCountsText(readingSession: middleReadingSession) == "1 ページ ・ 0 問")
        #expect(
            historyReadingSessionCountsText(
                readingSession: ReadingSession(id: UUID(), startedDateTime: Date(timeIntervalSince1970: 0), endedDateTime: nil, book: nil)
            ) == "0 ページ ・ 0 問"
        )
    }

    /// 履歴の一覧の読書の記録の見出しは、読書を始めた日時を今から見た言い方にした「昨日の読書」の形になる。
    @Test func 読書の記録の見出しは読書を始めた日時を今から見た言い方になる() {
        // `oldestReadingSession` は 1970-01-01 00:16:40 (UTC) に始めた。
        #expect(
            historyReadingSessionTitle(readingSession: oldestReadingSession, currentDateTime: Date(timeIntervalSince1970: 1_000 + 86_400))
                == "昨日の読書"
        )
        // 4 日前の言い方は、数字と「日前」の間の空きを iOS が決めるため、数字と終わりの形で確かめる。
        #expect(
            historyReadingSessionTitle(readingSession: oldestReadingSession, currentDateTime: Date(timeIntervalSince1970: 1_000 + 86_400 * 4))
                .hasPrefix("4")
        )
        #expect(
            historyReadingSessionTitle(readingSession: oldestReadingSession, currentDateTime: Date(timeIntervalSince1970: 1_000 + 86_400 * 4))
                .hasSuffix("日前の読書")
        )
        // 新しい読書の記録は、同じ今から見て、古い読書の記録と違う見出しになる。
        #expect(
            historyReadingSessionTitle(readingSession: newestReadingSession, currentDateTime: Date(timeIntervalSince1970: 1_000 + 86_400))
                != "昨日の読書"
        )
    }

    /// 履歴に出す日時の文は、渡した時間帯の日付と時刻で、日本語の書き方になる。
    @Test func 日時の文は渡した時間帯の日本語の日付と時刻になる() throws {
        // 2026-11-06 10:40 (UTC)。東京では同じ日の 19:40、ホノルルでは同じ日の 0:40。
        let dateTime = Date(timeIntervalSince1970: 1_793_961_600)

        #expect(historyDateTimeText(dateTime: dateTime, timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))) == "2026年11月6日 19:40")
        #expect(historyDateTimeText(dateTime: dateTime, timeZone: try #require(TimeZone(identifier: "UTC"))) == "2026年11月6日 10:40")
        #expect(historyDateTimeText(dateTime: dateTime, timeZone: try #require(TimeZone(identifier: "Pacific/Honolulu"))) == "2026年11月6日 0:40")
    }

    /// 履歴の判定の文は、四択と要約の正誤では言い切り、穴埋めと記述ではそう判定したことだけを書く。
    @Test func 履歴の判定の文は選択式では言い切り穴埋めと記述では言い切らない() {
        #expect(historyJudgementText(questionKind: .comprehension, isCorrect: true) == "合っていました")
        #expect(historyJudgementText(questionKind: .comprehension, isCorrect: false) == "合っていませんでした")
        #expect(historyJudgementText(questionKind: .summaryTrueFalse, isCorrect: true) == "合っていました")
        #expect(historyJudgementText(questionKind: .summaryTrueFalse, isCorrect: false) == "合っていませんでした")
        #expect(historyJudgementText(questionKind: .fillInTheBlank, isCorrect: true) == "合っていると判定しました")
        #expect(historyJudgementText(questionKind: .fillInTheBlank, isCorrect: false) == "合っていないと判定しました")
        #expect(historyJudgementText(questionKind: .written, isCorrect: true) == "合っていると判定しました")
        #expect(historyJudgementText(questionKind: .written, isCorrect: false) == "合っていないと判定しました")
    }

    /// 端末内のモデルが使える時は、4 種類のどの問いにも答え直しを始められる。
    @Test func 端末内のモデルが使える時はどの種類の問いにも答え直せる() {
        for questionKind in QuestionKind.allCases {
            #expect(historyCanReanswer(questionKind: questionKind, availability: .available))
        }
    }

    /// 端末内のモデルが使えない時は、使えない理由がどれでも、四択と要約の正誤には答え直しを始められ、穴埋めと記述には始められない。
    @Test func 端末内のモデルが使えない時は穴埋めと記述にだけ答え直せない() {
        for unavailableReason in [SystemLanguageModel.Availability.UnavailableReason.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady] {
            #expect(historyCanReanswer(questionKind: .comprehension, availability: .unavailable(unavailableReason)))
            #expect(historyCanReanswer(questionKind: .summaryTrueFalse, availability: .unavailable(unavailableReason)))
            #expect(!historyCanReanswer(questionKind: .fillInTheBlank, availability: .unavailable(unavailableReason)))
            #expect(!historyCanReanswer(questionKind: .written, availability: .unavailable(unavailableReason)))
        }
    }

    /// 消す前の確認の文は、一緒に消えるページ・問い・回答 (本では読書の記録も) の数を保存済みのデータから数えて出し、元に戻せないことを伝える。
    @Test func 消す前の確認の文は一緒に消えるものの数と元に戻せないことを伝える() {
        #expect(
            historyReadingSessionDeletionWarning(readingSession: oldestReadingSession)
                == "この読書のページ 2 件 問い 2 問 回答 2 件も消えます\n消した後は元に戻せません"
        )
        #expect(
            historyReadingSessionDeletionWarning(readingSession: middleReadingSession)
                == "この読書のページ 1 件 問い 0 問 回答 0 件も消えます\n消した後は元に戻せません"
        )
        #expect(
            historyBookDeletionWarning(book: book)
                == "この本の読書の記録 3 件 ページ 4 件 問い 3 問 回答 3 件も消えます\n消した後は元に戻せません"
        )
        #expect(
            historyBookDeletionWarning(book: otherBook)
                == "この本の読書の記録 1 件 ページ 1 件 問い 1 問 回答 1 件も消えます\n消した後は元に戻せません"
        )
    }
}
