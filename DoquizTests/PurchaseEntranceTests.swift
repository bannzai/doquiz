import Foundation
import SwiftData
import Testing

@testable import Doquiz

/// ホーム (本を選ぶ画面) に購入の画面への入口を出すかを、メモリ内の保存先に入れた本と読書の記録で確かめる。
struct PurchaseEntranceTests {
    /// テストごとに作る、メモリ内の保存先。
    private let modelContext: ModelContext

    /// メモリ内の保存先を作る。端末の保存データには触れない。
    init() throws {
        modelContext = ModelContext(try makeModelContainer(isStoredInMemoryOnly: true))
    }

    /// 読書の記録を `readingSessionCount` 件持つ本を、保存先に入れて返す。
    private func insertBook(readingSessionCount: Int) -> Book {
        let book = Book(id: UUID(), createdDateTime: Date(timeIntervalSince1970: 0), title: "テストの本", questionKinds: [.written], questionGuidance: nil)
        modelContext.insert(book)
        for _ in 0..<readingSessionCount {
            modelContext.insert(ReadingSession(id: UUID(), startedDateTime: Date(timeIntervalSince1970: 0), endedDateTime: nil, book: book))
        }
        return book
    }

    /// 本が 1 冊も無い利用者には、入口を出さない。
    @Test func 本が無い時は入口を出さない() {
        #expect(showsPurchaseEntrance(books: []) == false)
    }

    /// 本を登録しただけで、まだ読書を始めていない利用者には、入口を出さない。
    @Test func 読書を始めていない時は入口を出さない() {
        #expect(showsPurchaseEntrance(books: [insertBook(readingSessionCount: 0), insertBook(readingSessionCount: 0)]) == false)
    }

    /// 読書を 1 回始めた利用者 (終えていない読書の記録が 1 件) には、入口を出す。
    @Test func 読書を1回始めた後は入口を出す() {
        #expect(showsPurchaseEntrance(books: [insertBook(readingSessionCount: 1)]))
    }

    /// 読書の記録がある本が、並びの最初ではなくても、入口を出す。
    @Test func 読書の記録がある本が1冊でもあれば入口を出す() {
        #expect(showsPurchaseEntrance(books: [insertBook(readingSessionCount: 0), insertBook(readingSessionCount: 3)]))
    }
}
