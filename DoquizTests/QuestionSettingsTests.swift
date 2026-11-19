import Foundation
import SwiftData
import Testing
@testable import Doquiz

/// 本ごとの出題の設定の保存を、端末に書き込まないメモリ内の保存先で確かめる。
struct QuestionSettingsTests {
    /// 保存を実行する context。
    private let writingContext: ModelContext
    /// 保存先に書かれた結果を読む context。書いた context に残っている値ではなく、保存先の値を確かめるために分ける。
    private let readingContext: ModelContext

    /// テストごとに、メモリ内の保存先を新しく作る。
    init() throws {
        let modelContainer = try makeModelContainer(isStoredInMemoryOnly: true)
        writingContext = ModelContext(modelContainer)
        readingContext = ModelContext(modelContainer)
    }

    /// 問いの種類を 4 種類とも選び、出題への希望に「人物の行動の理由を中心に」と書いた本を 1 冊保存して返す。
    private func insertBookWithAllKindsAndGuidance() throws -> Book {
        let book = Book(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
            title: "潮見町の灯台日誌",
            questionKinds: [.comprehension, .summaryTrueFalse, .fillInTheBlank, .written],
            questionGuidance: "人物の行動の理由を中心に"
        )
        writingContext.insert(book)
        try writingContext.save()
        return book
    }

    /// 保存先にある本を 1 冊だけ読んで返す。1 冊でない時はテストを失敗にする。
    private func fetchOnlyBook() throws -> Book {
        let fetchedBooks = try readingContext.fetch(FetchDescriptor<Book>())
        try #require(fetchedBooks.count == 1)
        return fetchedBooks[0]
    }

    /// 問いの種類を 1 つ外し、出題への希望を書き換えて保存すると、true が返り、その内容が保存先に書かれることを確かめる。
    @Test func 問いの種類と出題への希望を保存できる() throws {
        #expect(
            try saveQuestionSettings(
                book: try insertBookWithAllKindsAndGuidance(),
                questionKinds: [.comprehension, .summaryTrueFalse, .fillInTheBlank],
                questionGuidance: "用語の定義を中心に",
                save: writingContext.save
            )
        )

        let fetchedBook = try fetchOnlyBook()
        #expect(fetchedBook.questionKinds == [.comprehension, .summaryTrueFalse, .fillInTheBlank])
        #expect(fetchedBook.questionGuidance == "用語の定義を中心に")
    }

    /// 問いの種類を 1 つも選んでいない出題の設定は、false が返り、本の問いの種類も出題への希望も前のまま変わらないことを確かめる。
    @Test func 問いの種類を1つも選んでいない出題の設定は保存されない() throws {
        let book = try insertBookWithAllKindsAndGuidance()

        #expect(
            try saveQuestionSettings(
                book: book,
                questionKinds: [],
                questionGuidance: "書き換えた希望",
                save: writingContext.save
            ) == false
        )

        #expect(book.questionKinds == [.comprehension, .summaryTrueFalse, .fillInTheBlank, .written])
        #expect(book.questionGuidance == "人物の行動の理由を中心に")
        let fetchedBook = try fetchOnlyBook()
        #expect(fetchedBook.questionKinds == [.comprehension, .summaryTrueFalse, .fillInTheBlank, .written])
        #expect(fetchedBook.questionGuidance == "人物の行動の理由を中心に")
    }

    /// 問いの種類を 1 つだけ選んだ出題の設定は保存されることを確かめる (1 つも選んでいない時との境界)。
    @Test(arguments: [QuestionKind.comprehension, .summaryTrueFalse, .fillInTheBlank, .written])
    func 問いの種類を1つだけ選んだ出題の設定は保存される(questionKind: QuestionKind) throws {
        #expect(
            try saveQuestionSettings(
                book: try insertBookWithAllKindsAndGuidance(),
                questionKinds: [questionKind],
                questionGuidance: "人物の行動の理由を中心に",
                save: writingContext.save
            )
        )

        #expect(try fetchOnlyBook().questionKinds == [questionKind])
    }

    /// 希望の文を空、または空白と改行だけにして保存すると、出題への希望が値を持たない状態 (nil) になることを確かめる。
    @Test(arguments: ["", " ", "　\n", "\n\n"])
    func 希望の文を空にして保存すると値を持たない状態になる(questionGuidance: String) throws {
        #expect(
            try saveQuestionSettings(
                book: try insertBookWithAllKindsAndGuidance(),
                questionKinds: [.written],
                questionGuidance: questionGuidance,
                save: writingContext.save
            )
        )

        #expect(try fetchOnlyBook().questionGuidance == nil)
    }

    /// 希望の文の前後の空白と改行は除いて保存し、文の途中の改行は残すことを確かめる。
    @Test func 希望の文の前後の空白は除いて保存する() throws {
        #expect(
            try saveQuestionSettings(
                book: try insertBookWithAllKindsAndGuidance(),
                questionKinds: [.written],
                questionGuidance: " \n用語の定義を中心に\n数字も聞いてほしい　\n",
                save: writingContext.save
            )
        )

        #expect(try fetchOnlyBook().questionGuidance == "用語の定義を中心に\n数字も聞いてほしい")
    }

    /// 問いの種類は、選んだ順に関わらず、四択・要約の正誤・穴埋め・記述の順に並べて保存することを確かめる。
    @Test func 問いの種類は決まった順に並べて保存する() throws {
        let book = try insertBookWithAllKindsAndGuidance()
        book.questionKinds = [.written, .comprehension]
        try writingContext.save()

        #expect(
            try saveQuestionSettings(
                book: book,
                questionKinds: Set([.written, .fillInTheBlank, .comprehension]),
                questionGuidance: "",
                save: writingContext.save
            )
        )

        #expect(try fetchOnlyBook().questionKinds == [.comprehension, .fillInTheBlank, .written])
    }

    /// 保存先への書き込みが失敗した出題の設定の保存は、エラーを投げ、本の問いの種類と出題への希望を保存の前の内容に戻すことを確かめる。
    @Test func 保存に失敗した出題の設定は本を前の内容に戻す() throws {
        let book = try insertBookWithAllKindsAndGuidance()

        #expect(throws: SaveFailure.self) {
            _ = try saveQuestionSettings(
                book: book,
                questionKinds: [.written],
                questionGuidance: "書き換えた希望",
                save: { throw SaveFailure() }
            )
        }

        #expect(book.questionKinds == [.comprehension, .summaryTrueFalse, .fillInTheBlank, .written])
        #expect(book.questionGuidance == "人物の行動の理由を中心に")
        try writingContext.save()
        #expect(try fetchOnlyBook().questionKinds == [.comprehension, .summaryTrueFalse, .fillInTheBlank, .written])
        #expect(try fetchOnlyBook().questionGuidance == "人物の行動の理由を中心に")
    }

    /// 問いの種類の画面に出す名前が、四択・要約の正誤・穴埋め・記述であることを確かめる。
    @Test(arguments: [
        (QuestionKind.comprehension, "四択"),
        (.summaryTrueFalse, "要約の正誤"),
        (.fillInTheBlank, "穴埋め"),
        (.written, "記述"),
    ])
    func 問いの種類の名前(questionKind: QuestionKind, expectedLabel: String) {
        #expect(questionKindLabel(questionKind: questionKind) == expectedLabel)
    }
}
