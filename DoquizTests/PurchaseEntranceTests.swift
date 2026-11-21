import Foundation
import SwiftData
import Testing

@testable import Doquiz

/// ホーム (本を選ぶ画面) に購入の画面への入口と無料の残りの回数を出すかを、メモリ内の保存先に入れた本と読書の記録と、購入の状態で確かめる。
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
        #expect(showsPurchaseEntrance(books: [], purchaseState: .notPurchased) == false)
    }

    /// 本を登録しただけで、まだ読書を始めていない利用者には、入口を出さない (最初の読書の前)。
    @Test func 読書を始めていない時は入口を出さない() {
        #expect(
            showsPurchaseEntrance(
                books: [insertBook(readingSessionCount: 0), insertBook(readingSessionCount: 0)],
                purchaseState: .notPurchased
            ) == false
        )
    }

    /// 読書を 1 回始めた利用者 (終えていない読書の記録が 1 件) には、入口を出す。
    @Test func 読書を1回始めた後は入口を出す() {
        #expect(showsPurchaseEntrance(books: [insertBook(readingSessionCount: 1)], purchaseState: .notPurchased))
    }

    /// 読書の記録がある本が、並びの最初ではなくても、入口を出す。
    @Test func 読書の記録がある本が1冊でもあれば入口を出す() {
        #expect(
            showsPurchaseEntrance(
                books: [insertBook(readingSessionCount: 0), insertBook(readingSessionCount: 3)],
                purchaseState: .notPurchased
            )
        )
    }

    /// トライアル中と購入済みの利用者には、読書を始めた後でも、入口を出さない。
    @Test(arguments: [PurchaseState.inTrial, .purchased])
    func トライアル中と購入済みの時は入口を出さない(purchaseState: PurchaseState) {
        #expect(
            showsPurchaseEntrance(books: [insertBook(readingSessionCount: 1)], purchaseState: purchaseState) == false
        )
    }

    /// 購入の状態をまだ確かめていない間と、確かめて取得できなかった時 (どちらも nil) は、読書を始めた後でも、入口を出さない。
    @Test func 購入の状態が分からない間は入口を出さない() {
        #expect(showsPurchaseEntrance(books: [insertBook(readingSessionCount: 1)], purchaseState: nil) == false)
    }
}
