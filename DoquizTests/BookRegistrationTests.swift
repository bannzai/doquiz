import Foundation
import SwiftData
import Testing
@testable import Doquiz

/// 新しい本の登録を、端末に書き込まないメモリ内の保存先で確かめる。
struct BookRegistrationTests {
    /// 登録を実行する context。
    private let writingContext: ModelContext
    /// 保存先に書かれた結果を読む context。書いた context に残っている値ではなく、保存先の値を確かめるために分ける。
    private let readingContext: ModelContext

    /// テストごとに、メモリ内の保存先を新しく作る。
    init() throws {
        let modelContainer = try makeModelContainer(isStoredInMemoryOnly: true)
        writingContext = ModelContext(modelContainer)
        readingContext = ModelContext(modelContainer)
    }

    /// 名前を入れて登録した本が、その名前で 1 冊保存され、問いの種類が 4 種類とも選ばれ、出題への希望を書いていない状態で始まることを確かめる。
    @Test func 新しく登録した本は問いの種類が4種類とも選ばれている() throws {
        let registeredBook = try #require(try registerBook(title: "潮見町の灯台日誌", modelContext: writingContext, save: writingContext.save))

        let fetchedBooks = try readingContext.fetch(FetchDescriptor<Book>())
        try #require(fetchedBooks.count == 1)
        #expect(fetchedBooks[0].id == registeredBook.id)
        #expect(fetchedBooks[0].title == "潮見町の灯台日誌")
        #expect(fetchedBooks[0].questionKinds == [.comprehension, .summaryTrueFalse, .fillInTheBlank, .written])
        #expect(fetchedBooks[0].questionGuidance == nil)
        #expect(fetchedBooks[0].readingSessions.isEmpty)
    }

    /// 名前が空、または空白と改行だけの時は、nil が返り、本が 1 冊も保存されないことを確かめる。
    @Test(arguments: ["", " ", "　", "\n", " \n　\t"])
    func 名前が空の本は登録されない(title: String) throws {
        #expect(try registerBook(title: title, modelContext: writingContext, save: writingContext.save) == nil)

        #expect(try readingContext.fetchCount(FetchDescriptor<Book>()) == 0)
    }

    /// 名前が 1 文字の本は登録されることを確かめる (空との境界)。
    @Test func 名前が1文字の本は登録される() throws {
        #expect(try registerBook(title: "a", modelContext: writingContext, save: writingContext.save) != nil)

        #expect(try readingContext.fetch(FetchDescriptor<Book>()).map(\.title) == ["a"])
    }

    /// 名前の前後の空白と改行は除いて保存し、名前の途中の空白は残すことを確かめる。
    @Test func 名前の前後の空白は除いて保存する() throws {
        #expect(try registerBook(title: " \n はじめての 堆肥づくり　\n", modelContext: writingContext, save: writingContext.save) != nil)

        #expect(try readingContext.fetch(FetchDescriptor<Book>()).map(\.title) == ["はじめての 堆肥づくり"])
    }

    /// 同じ名前で 2 回登録すると、区別する値の違う本が 2 冊保存されることを確かめる。
    @Test func 同じ名前の本を別の本として登録できる() throws {
        #expect(
            try #require(try registerBook(title: "同じ名前", modelContext: writingContext, save: writingContext.save)).id
                != #require(try registerBook(title: "同じ名前", modelContext: writingContext, save: writingContext.save)).id
        )
        #expect(try readingContext.fetch(FetchDescriptor<Book>()).map(\.title) == ["同じ名前", "同じ名前"])
    }

    /// 保存先への書き込みが失敗した登録は、エラーを投げ、足した本を残さないことを確かめる。
    /// 失敗の後に同じ名前で登録し直すと、保存される本が 2 冊ではなく 1 冊であることを確かめる。
    @Test func 保存に失敗した登録は本を残さず登録し直しても1冊になる() throws {
        #expect(throws: SaveFailure.self) {
            _ = try registerBook(title: "潮見町の灯台日誌", modelContext: writingContext, save: { throw SaveFailure() })
        }
        try writingContext.save()
        #expect(try readingContext.fetchCount(FetchDescriptor<Book>()) == 0)

        #expect(try registerBook(title: "潮見町の灯台日誌", modelContext: writingContext, save: writingContext.save) != nil)
        #expect(try readingContext.fetch(FetchDescriptor<Book>()).map(\.title) == ["潮見町の灯台日誌"])
    }

    /// 登録できる名前かの判定が、空と空白だけの名前では nil、文字のある名前では前後の空白を除いた名前を返すことを確かめる。
    @Test func 登録できる名前は前後の空白を除いた名前で空なら無い() {
        #expect(registrableBookTitle(title: "") == nil)
        #expect(registrableBookTitle(title: " 　\n") == nil)
        #expect(registrableBookTitle(title: "本") == "本")
        #expect(registrableBookTitle(title: "  本 の 名前\n") == "本 の 名前")
    }
}

/// テストで保存先への書き込みの失敗として投げるエラー。
struct SaveFailure: Error {}
