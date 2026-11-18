import Foundation
import SwiftData
import Testing
@testable import Doquiz

/// 本・読書の記録・ページ・問い・回答を、端末に書き込まないメモリ内の保存先に保存・読み出し・削除した時の挙動を確かめる。
struct ModelPersistenceTests {
    /// 保存と削除に使う context。
    private let writingContext: ModelContext
    /// 保存先に書かれた結果を読む context。書いた context に残っている値ではなく、保存先の値を確かめるために分ける。
    private let readingContext: ModelContext

    /// テストごとに、メモリ内の保存先を新しく作る。
    init() throws {
        let modelContainer = try makeModelContainer(isStoredInMemoryOnly: true)
        writingContext = ModelContext(modelContainer)
        readingContext = ModelContext(modelContainer)
    }

    /// 読書の記録 1 件と、その下のページ 1 件・問い 1 件・回答 1 件を `book` の下に足し、足した読書の記録を返す。保存 (`save`) は呼び出し側が行う。
    private func insertReadingSessionWithOneOfEach(book: Book) -> ReadingSession {
        let readingSession = ReadingSession(
            id: UUID(),
            startedDateTime: Date(timeIntervalSince1970: 1_800_000_000),
            endedDateTime: nil,
            book: book
        )
        writingContext.insert(readingSession)
        writingContext.insert(
            CapturedPage(
                id: UUID(),
                capturedDateTime: Date(timeIntervalSince1970: 1_800_000_010),
                text: "ページの本文",
                readingSession: readingSession
            )
        )
        let question = Question(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 1_800_000_020),
            kind: .written,
            text: "問いの文",
            choices: [],
            modelAnswer: "模範の答え",
            evidenceQuote: "根拠の引用",
            readingSession: readingSession
        )
        writingContext.insert(question)
        writingContext.insert(
            Answer(
                id: UUID(),
                answeredDateTime: Date(timeIntervalSince1970: 1_800_000_030),
                text: "利用者の答え",
                isCorrect: false,
                question: question
            )
        )
        return readingSession
    }

    /// 出題の設定を持たない本 1 冊を足して返す。保存 (`save`) は呼び出し側が行う。
    private func insertBook(title: String) -> Book {
        let book = Book(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
            title: title,
            questionKinds: [],
            questionGuidance: nil
        )
        writingContext.insert(book)
        return book
    }

    /// 本 → 読書の記録 → ページと問い → 回答 を保存し、別の context で読み出した値が、保存した値と同じであることを確かめる。
    @Test func 本から回答までを保存して読み出すと保存した値と同じ() throws {
        let bookID = UUID()
        let readingSessionID = UUID()
        let capturedPageID = UUID()
        let questionID = UUID()
        let answerID = UUID()
        let book = Book(
            id: bookID,
            createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
            title: "吾輩は猫である",
            questionKinds: [.comprehension],
            questionGuidance: "用語の定義を中心に"
        )
        writingContext.insert(book)
        let readingSession = ReadingSession(
            id: readingSessionID,
            startedDateTime: Date(timeIntervalSince1970: 1_800_000_100),
            endedDateTime: Date(timeIntervalSince1970: 1_800_003_700),
            book: book
        )
        writingContext.insert(readingSession)
        writingContext.insert(
            CapturedPage(
                id: capturedPageID,
                capturedDateTime: Date(timeIntervalSince1970: 1_800_000_200),
                text: "吾輩は猫である。名前はまだ無い。",
                readingSession: readingSession
            )
        )
        let question = Question(
            id: questionID,
            createdDateTime: Date(timeIntervalSince1970: 1_800_003_800),
            kind: .comprehension,
            text: "語り手は何か",
            choices: ["犬", "猫", "人", "鳥"],
            modelAnswer: "猫",
            evidenceQuote: "吾輩は猫である。",
            readingSession: readingSession
        )
        writingContext.insert(question)
        writingContext.insert(
            Answer(
                id: answerID,
                answeredDateTime: Date(timeIntervalSince1970: 1_800_003_900),
                text: "猫",
                isCorrect: true,
                question: question
            )
        )
        try writingContext.save()

        let fetchedBooks = try readingContext.fetch(FetchDescriptor<Book>())
        try #require(fetchedBooks.count == 1)
        let fetchedBook = fetchedBooks[0]
        #expect(fetchedBook.id == bookID)
        #expect(fetchedBook.createdDateTime == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(fetchedBook.title == "吾輩は猫である")
        #expect(fetchedBook.questionKinds == [.comprehension])
        #expect(fetchedBook.questionGuidance == "用語の定義を中心に")

        try #require(fetchedBook.readingSessions.count == 1)
        let fetchedReadingSession = fetchedBook.readingSessions[0]
        #expect(fetchedReadingSession.id == readingSessionID)
        #expect(fetchedReadingSession.startedDateTime == Date(timeIntervalSince1970: 1_800_000_100))
        #expect(fetchedReadingSession.endedDateTime == Date(timeIntervalSince1970: 1_800_003_700))
        #expect(fetchedReadingSession.book?.id == bookID)

        try #require(fetchedReadingSession.capturedPages.count == 1)
        let fetchedCapturedPage = fetchedReadingSession.capturedPages[0]
        #expect(fetchedCapturedPage.id == capturedPageID)
        #expect(fetchedCapturedPage.capturedDateTime == Date(timeIntervalSince1970: 1_800_000_200))
        #expect(fetchedCapturedPage.text == "吾輩は猫である。名前はまだ無い。")
        #expect(fetchedCapturedPage.readingSession?.id == readingSessionID)

        try #require(fetchedReadingSession.questions.count == 1)
        let fetchedQuestion = fetchedReadingSession.questions[0]
        #expect(fetchedQuestion.id == questionID)
        #expect(fetchedQuestion.createdDateTime == Date(timeIntervalSince1970: 1_800_003_800))
        #expect(fetchedQuestion.kind == .comprehension)
        #expect(fetchedQuestion.text == "語り手は何か")
        #expect(fetchedQuestion.choices == ["犬", "猫", "人", "鳥"])
        #expect(fetchedQuestion.modelAnswer == "猫")
        #expect(fetchedQuestion.evidenceQuote == "吾輩は猫である。")
        #expect(fetchedQuestion.readingSession?.id == readingSessionID)

        try #require(fetchedQuestion.answers.count == 1)
        let fetchedAnswer = fetchedQuestion.answers[0]
        #expect(fetchedAnswer.id == answerID)
        #expect(fetchedAnswer.answeredDateTime == Date(timeIntervalSince1970: 1_800_003_900))
        #expect(fetchedAnswer.text == "猫")
        #expect(fetchedAnswer.isCorrect == true)
        #expect(fetchedAnswer.question?.id == questionID)
    }

    /// 値が無いことを表す状態 (出題への希望を書いていない・問いの種類を 1 つも選んでいない・読書中・選択肢が無い・合っていないと判定した) が、保存して読み出しても同じであることを確かめる。
    @Test func 値が無い状態を保存して読み出しても同じ() throws {
        _ = insertReadingSessionWithOneOfEach(book: insertBook(title: "本"))
        try writingContext.save()

        let fetchedBooks = try readingContext.fetch(FetchDescriptor<Book>())
        try #require(fetchedBooks.count == 1)
        #expect(fetchedBooks[0].questionKinds == [])
        #expect(fetchedBooks[0].questionGuidance == nil)
        let fetchedReadingSessions = try readingContext.fetch(FetchDescriptor<ReadingSession>())
        try #require(fetchedReadingSessions.count == 1)
        #expect(fetchedReadingSessions[0].endedDateTime == nil)
        let fetchedQuestions = try readingContext.fetch(FetchDescriptor<Question>())
        try #require(fetchedQuestions.count == 1)
        #expect(fetchedQuestions[0].choices == [])
        let fetchedAnswers = try readingContext.fetch(FetchDescriptor<Answer>())
        try #require(fetchedAnswers.count == 1)
        #expect(fetchedAnswers[0].isCorrect == false)
    }

    /// 問いの種類の 4 つの値のそれぞれが、問いに保存して読み出しても同じであることを確かめる。
    @Test(arguments: [QuestionKind.comprehension, .summaryTrueFalse, .fillInTheBlank, .written])
    func 問いの種類を問いに保存して読み出しても同じ(questionKind: QuestionKind) throws {
        writingContext.insert(
            Question(
                id: UUID(),
                createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
                kind: questionKind,
                text: "問いの文",
                choices: [],
                modelAnswer: "模範の答え",
                evidenceQuote: "根拠の引用",
                readingSession: nil
            )
        )
        try writingContext.save()

        let fetchedQuestions = try readingContext.fetch(FetchDescriptor<Question>())
        try #require(fetchedQuestions.count == 1)
        #expect(fetchedQuestions[0].kind == questionKind)
    }

    /// 保存済みのデータに書かれる問いの種類の値 (rawValue) が、型定義の case の名前のままであることを確かめる (変えると保存済みの値を読めなくなる)。
    @Test func 問いの種類の保存される値はcaseの名前と同じ() {
        #expect(QuestionKind.comprehension.rawValue == "comprehension")
        #expect(QuestionKind.summaryTrueFalse.rawValue == "summaryTrueFalse")
        #expect(QuestionKind.fillInTheBlank.rawValue == "fillInTheBlank")
        #expect(QuestionKind.written.rawValue == "written")
    }

    /// 本に入れた複数の問いの種類が、保存して読み出しても、入れた順のまま同じであることを確かめる。
    @Test func 本に入れた複数の問いの種類を保存して読み出しても同じ() throws {
        writingContext.insert(
            Book(
                id: UUID(),
                createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
                title: "本",
                questionKinds: [.written, .comprehension, .fillInTheBlank, .summaryTrueFalse],
                questionGuidance: nil
            )
        )
        try writingContext.save()

        let fetchedBooks = try readingContext.fetch(FetchDescriptor<Book>())
        try #require(fetchedBooks.count == 1)
        #expect(fetchedBooks[0].questionKinds == [.written, .comprehension, .fillInTheBlank, .summaryTrueFalse])
    }

    /// 本を消すと、その本の読書の記録・ページ・問い・回答がすべて消え、別の本とその下のデータは残ることを確かめる。
    @Test func 本を消すとその本の読書の記録とページと問いと回答が消える() throws {
        let deletedBook = insertBook(title: "消す本")
        _ = insertReadingSessionWithOneOfEach(book: deletedBook)
        _ = insertReadingSessionWithOneOfEach(book: deletedBook)
        let remainingBook = insertBook(title: "残す本")
        let remainingReadingSession = insertReadingSessionWithOneOfEach(book: remainingBook)
        try writingContext.save()
        try #require(try readingContext.fetchCount(FetchDescriptor<ReadingSession>()) == 3)
        try #require(try readingContext.fetchCount(FetchDescriptor<CapturedPage>()) == 3)
        try #require(try readingContext.fetchCount(FetchDescriptor<Question>()) == 3)
        try #require(try readingContext.fetchCount(FetchDescriptor<Answer>()) == 3)

        writingContext.delete(deletedBook)
        try writingContext.save()

        #expect(try readingContext.fetch(FetchDescriptor<Book>()).map(\.id) == [remainingBook.id])
        #expect(try readingContext.fetch(FetchDescriptor<ReadingSession>()).map(\.id) == [remainingReadingSession.id])
        #expect(try readingContext.fetch(FetchDescriptor<CapturedPage>()).map(\.readingSession?.id) == [remainingReadingSession.id])
        #expect(try readingContext.fetch(FetchDescriptor<Question>()).map(\.readingSession?.id) == [remainingReadingSession.id])
        #expect(try readingContext.fetch(FetchDescriptor<Answer>()).map(\.question?.readingSession?.id) == [remainingReadingSession.id])
    }

    /// 読書の記録を 1 件消すと、そのページ・問い・回答が消え、本と、同じ本のほかの読書の記録とその下のデータは残ることを確かめる。
    @Test func 読書の記録を消すとそのページと問いと回答が消え本とほかの読書の記録は残る() throws {
        let book = insertBook(title: "本")
        let deletedReadingSession = insertReadingSessionWithOneOfEach(book: book)
        let remainingReadingSession = insertReadingSessionWithOneOfEach(book: book)
        try writingContext.save()
        try #require(try readingContext.fetchCount(FetchDescriptor<CapturedPage>()) == 2)
        try #require(try readingContext.fetchCount(FetchDescriptor<Question>()) == 2)
        try #require(try readingContext.fetchCount(FetchDescriptor<Answer>()) == 2)

        writingContext.delete(deletedReadingSession)
        try writingContext.save()

        #expect(try readingContext.fetch(FetchDescriptor<Book>()).map(\.id) == [book.id])
        #expect(try readingContext.fetch(FetchDescriptor<ReadingSession>()).map(\.id) == [remainingReadingSession.id])
        #expect(try readingContext.fetch(FetchDescriptor<CapturedPage>()).map(\.readingSession?.id) == [remainingReadingSession.id])
        #expect(try readingContext.fetch(FetchDescriptor<Question>()).map(\.readingSession?.id) == [remainingReadingSession.id])
        #expect(try readingContext.fetch(FetchDescriptor<Answer>()).map(\.question?.readingSession?.id) == [remainingReadingSession.id])
    }

    /// 問いを消すと、その問いへの回答が消えることを確かめる。
    @Test func 問いを消すとその問いへの回答が消える() throws {
        let readingSession = insertReadingSessionWithOneOfEach(book: insertBook(title: "本"))
        try writingContext.save()
        try #require(try readingContext.fetchCount(FetchDescriptor<Answer>()) == 1)

        try #require(readingSession.questions.count == 1)
        writingContext.delete(readingSession.questions[0])
        try writingContext.save()

        #expect(try readingContext.fetchCount(FetchDescriptor<Question>()) == 0)
        #expect(try readingContext.fetchCount(FetchDescriptor<Answer>()) == 0)
        #expect(try readingContext.fetchCount(FetchDescriptor<ReadingSession>()) == 1)
    }

    /// 同じ問いに回答を 2 件足すと、2 件とも残ることを確かめる (履歴から答え直した時に、前の回答を上書きしない)。
    @Test func 同じ問いに回答を2件足すと2件とも残る() throws {
        let question = Question(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
            kind: .fillInTheBlank,
            text: "吾輩は＿＿である",
            choices: [],
            modelAnswer: "猫",
            evidenceQuote: "吾輩は猫である。",
            readingSession: nil
        )
        writingContext.insert(question)
        writingContext.insert(
            Answer(
                id: UUID(),
                answeredDateTime: Date(timeIntervalSince1970: 1_800_000_100),
                text: "犬",
                isCorrect: false,
                question: question
            )
        )
        writingContext.insert(
            Answer(
                id: UUID(),
                answeredDateTime: Date(timeIntervalSince1970: 1_800_000_200),
                text: "猫",
                isCorrect: true,
                question: question
            )
        )
        try writingContext.save()

        let fetchedQuestions = try readingContext.fetch(FetchDescriptor<Question>())
        try #require(fetchedQuestions.count == 1)
        #expect(
            fetchedQuestions[0].answers.sorted { $0.answeredDateTime < $1.answeredDateTime }.map(\.text) == ["犬", "猫"]
        )
        #expect(
            fetchedQuestions[0].answers.sorted { $0.answeredDateTime < $1.answeredDateTime }.map(\.isCorrect)
                == [false, true]
        )
    }
}
