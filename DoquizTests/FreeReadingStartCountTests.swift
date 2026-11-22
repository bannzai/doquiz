import Foundation
import Security
import Testing

@testable import Doquiz

/// 無料で始めた読書の回数の保存先 (Keychain とメモリ内) と、回数を持つ `FreeReadingStartCount` を確かめる。
///
/// Keychain のテストは、アプリが使うサービス名と別の、テストごとに作るサービス名を使い、終わったら項目を消す (端末の回数に触れないため)。
struct FreeReadingStartCountTests {
    /// 回数の読み書きが失敗する、偽の保存先を作る。`loadFails` が true なら読み出しで、`saveFails` が true なら書き込みで投げる。
    private func makeFailingStore(loadFails: Bool, saveFails: Bool, initialCount: Int) -> FreeReadingStartCountStore {
        FreeReadingStartCountStore(
            load: {
                guard !loadFails else {
                    throw FreeReadingStartCountKeychainError(status: errSecInteractionNotAllowed)
                }
                return initialCount
            },
            save: { _ in
                guard !saveFails else {
                    throw FreeReadingStartCountKeychainError(status: errSecInteractionNotAllowed)
                }
            }
        )
    }

    /// Keychain に一度も保存していない時は 0 回を返し、保存した回数を読み出せ、上書きした後は新しい回数を読み出せる。
    /// 別のサービス名で作った保存先 (アプリを入れ直した後に作る保存先の代わり) からも、同じ回数を読み出せる。
    @Test func 端末のKeychainに保存した回数を読み出せて上書きできる() throws {
        let service = "app.bannzai.doquiz.test.\(UUID().uuidString)"
        defer {
            SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
        }
        let store = makeKeychainFreeReadingStartCountStore(service: service)

        #expect(try store.load() == 0)
        try store.save(3)
        #expect(try store.load() == 3)
        try store.save(20)
        #expect(try store.load() == 20)
        #expect(try makeKeychainFreeReadingStartCountStore(service: service).load() == 20)
    }

    /// メモリ内の保存先は 0 回から始まり、保存した回数を読み出せる。
    @Test func メモリ内の保存先は0回から始まり保存した回数を読み出せる() throws {
        let store = makeInMemoryFreeReadingStartCountStore()

        #expect(try store.load() == 0)
        try store.save(7)
        #expect(try store.load() == 7)
    }

    /// 回数を 1 増やすと、保存先にも 1 増えた回数が保存される。
    @Test func 回数を増やすと保存先にも保存される() throws {
        let store = makeInMemoryFreeReadingStartCountStore()
        try store.save(19)
        let freeReadingStartCount = FreeReadingStartCount(store: store)

        try freeReadingStartCount.increment()

        #expect(freeReadingStartCount.count == 20)
        #expect(try store.load() == 20)
    }

    /// 保存に失敗した時は error を投げ、回数を変えない。
    @Test func 保存に失敗した時は回数を変えない() throws {
        let freeReadingStartCount = FreeReadingStartCount(store: makeFailingStore(loadFails: false, saveFails: true, initialCount: 5))

        #expect(throws: FreeReadingStartCountKeychainError.self) {
            try freeReadingStartCount.increment()
        }
        #expect(freeReadingStartCount.count == 5)
    }

    /// 起動した時に読み出せなかった時は、回数を 0 回にせず nil にし、増やそうとすると `FreeReadingStartCountUnavailableError` を投げる。
    /// もう一度読み出そうとした時も、読み出せなければ保存先の error を投げる。
    @Test func 読み出せなかった時は回数を0回にしない() throws {
        let freeReadingStartCount = FreeReadingStartCount(store: makeFailingStore(loadFails: true, saveFails: false, initialCount: 5))

        #expect(freeReadingStartCount.count == nil)
        #expect(throws: FreeReadingStartCountUnavailableError.self) {
            try freeReadingStartCount.increment()
        }
        #expect(throws: FreeReadingStartCountKeychainError.self) {
            _ = try freeReadingStartCount.loadedCount()
        }
    }
}
