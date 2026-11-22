import Foundation
import Security
import Testing

@testable import Doquiz

/// 無料で始めた読書の回数のメモリ内の保存先と、回数を持つ `FreeReadingStartCount` を確かめる。
///
/// Keychain の保存先 (`makeKeychainFreeReadingStartCountStore`) はここでは確かめない。CI の署名しないビルドの単体テストでは、
/// Keychain の読み書きが `errSecMissingEntitlement` (-34018) で失敗するため (run https://github.com/bannzai/doquiz/actions/runs/44969559446 で実測)。
/// 実機での確認は https://github.com/bannzai/doquiz/issues/22 に足した。
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
