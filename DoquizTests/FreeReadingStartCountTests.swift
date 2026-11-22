import Foundation
import Security
import Testing

@testable import Doquiz

/// 無料で始めた読書の回数の保存先 (Keychain とメモリ内) と、回数を持つ `FreeReadingStartCount` を確かめる。
///
/// Keychain の保存先は、Security framework の関数の代わりに偽の Keychain の操作を渡して確かめる。CI の署名しないビルドの単体テストでは、
/// 本物の Keychain の読み書きが `errSecMissingEntitlement` (-34018) で失敗するため (run https://github.com/bannzai/doquiz/actions/runs/44969559446 で実測)。
/// 本物の Keychain での確認 (アプリを入れ直した後も残るか) は https://github.com/bannzai/doquiz/issues/22 に足した。
struct FreeReadingStartCountTests {
    /// 回数の読み書きが失敗する、偽の保存先を作る。`loadFails` が true なら読み出しで、`saveFails` が true なら書き込みで投げる。
    /// 読み出せる時は `loadedCount` を返す。
    private func makeFailingStore(loadFails: Bool, saveFails: Bool, loadedCount: Int) -> FreeReadingStartCountStore {
        FreeReadingStartCountStore(
            load: {
                guard !loadFails else {
                    throw FreeReadingStartCountKeychainError(status: errSecInteractionNotAllowed)
                }
                return loadedCount
            },
            save: { _ in
                guard !saveFails else {
                    throw FreeReadingStartCountKeychainError(status: errSecInteractionNotAllowed)
                }
            }
        )
    }

    /// 偽の Keychain。項目の値を 1 つだけ持ち、探す・書き換える・足すの結果のコードを決められる。呼ばれた操作を順に記録する。
    private final class FakeKeychain {
        /// 持っている項目の値。項目が無い時は nil。
        var storedData: Data?
        /// 探す操作が、項目がある時に返す結果のコード。nil の時は成功を返す。
        var copyMatchingFailureStatus: OSStatus?
        /// 書き換える操作が、項目がある時に返す結果のコード。nil の時は成功を返す。
        var updateFailureStatus: OSStatus?
        /// 足す操作が返す結果のコード。nil の時は成功を返す。
        var addFailureStatus: OSStatus?
        /// 呼ばれた操作の名前 (copyMatching・update・add)。
        private(set) var calledOperations: [String] = []

        /// この偽の Keychain を読み書きする操作を返す。
        func operations() -> KeychainOperations {
            KeychainOperations(
                copyMatching: { [self] _, result in
                    calledOperations.append("copyMatching")
                    guard let storedData else {
                        return errSecItemNotFound
                    }
                    if let copyMatchingFailureStatus {
                        return copyMatchingFailureStatus
                    }
                    result.pointee = storedData as CFData
                    return errSecSuccess
                },
                update: { [self] _, attributesToUpdate in
                    calledOperations.append("update")
                    guard storedData != nil else {
                        return errSecItemNotFound
                    }
                    if let updateFailureStatus {
                        return updateFailureStatus
                    }
                    storedData = (attributesToUpdate as NSDictionary)[kSecValueData as String] as? Data
                    return errSecSuccess
                },
                add: { [self] attributes in
                    calledOperations.append("add")
                    if let addFailureStatus {
                        return addFailureStatus
                    }
                    storedData = (attributes as NSDictionary)[kSecValueData as String] as? Data
                    return errSecSuccess
                }
            )
        }
    }

    /// Keychain に項目が無い時は 0 回を返す。初めて保存する時は項目を足し、次に保存する時は項目を書き換える。保存した回数を読み出せる。
    @Test func 端末のKeychainの保存先は項目が無い時は0回で初めは足し次からは書き換える() throws {
        let keychain = FakeKeychain()
        let store = makeKeychainFreeReadingStartCountStore(service: "app.bannzai.doquiz.test", keychain: keychain.operations())

        #expect(try store.load() == 0)
        try store.save(3)
        #expect(try store.load() == 3)
        try store.save(20)
        #expect(try store.load() == 20)
        #expect(keychain.calledOperations == ["copyMatching", "update", "add", "copyMatching", "update", "copyMatching"])
    }

    /// Keychain を探す操作が失敗した時と、保存した値を回数として解釈できない時は、0 回を返さずに error を投げる。
    @Test func 端末のKeychainを読み出せない時と値を解釈できない時は0回にせず投げる() throws {
        let failingKeychain = FakeKeychain()
        failingKeychain.storedData = Data("5".utf8)
        failingKeychain.copyMatchingFailureStatus = errSecInteractionNotAllowed
        #expect(throws: FreeReadingStartCountKeychainError.self) {
            _ = try makeKeychainFreeReadingStartCountStore(service: "app.bannzai.doquiz.test", keychain: failingKeychain.operations()).load()
        }

        let brokenKeychain = FakeKeychain()
        brokenKeychain.storedData = Data("五".utf8)
        #expect(throws: FreeReadingStartCountKeychainError.self) {
            _ = try makeKeychainFreeReadingStartCountStore(service: "app.bannzai.doquiz.test", keychain: brokenKeychain.operations()).load()
        }
    }

    /// 書き換えが失敗した時と、足すのが失敗した時は、error を投げる。書き換えが失敗した時は足さない。
    @Test func 端末のKeychainに保存できない時は投げる() throws {
        let updateFailingKeychain = FakeKeychain()
        updateFailingKeychain.storedData = Data("5".utf8)
        updateFailingKeychain.updateFailureStatus = errSecInteractionNotAllowed
        #expect(throws: FreeReadingStartCountKeychainError.self) {
            try makeKeychainFreeReadingStartCountStore(service: "app.bannzai.doquiz.test", keychain: updateFailingKeychain.operations()).save(6)
        }
        #expect(updateFailingKeychain.calledOperations == ["update"])
        #expect(updateFailingKeychain.storedData == Data("5".utf8))

        let addFailingKeychain = FakeKeychain()
        addFailingKeychain.addFailureStatus = errSecInteractionNotAllowed
        #expect(throws: FreeReadingStartCountKeychainError.self) {
            try makeKeychainFreeReadingStartCountStore(service: "app.bannzai.doquiz.test", keychain: addFailingKeychain.operations()).save(1)
        }
        #expect(addFailingKeychain.storedData == nil)
    }

    #if DEBUG && targetEnvironment(simulator)
        /// DEBUG の Simulator のビルドでアプリが使う保存先は、UserDefaults の回数を読み書きし、まだ保存していない時は 0 回を返す
        /// (署名しない Simulator のビルドでは Keychain を使えないため。CI の単体テストはこのビルドで動く)。
        @Test func 開発用のSimulatorのビルドではUserDefaultsに回数を置く() throws {
            let suiteName = "app.bannzai.doquiz.test.\(UUID().uuidString)"
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            let userDefaults = try #require(UserDefaults(suiteName: suiteName))
            let store = makeAppFreeReadingStartCountStore(userDefaults: userDefaults)

            #expect(try store.load() == 0)
            try store.save(4)
            #expect(try store.load() == 4)
            #expect(userDefaults.integer(forKey: "freeReadingStartCount") == 4)
        }
    #endif

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

    /// 保存に失敗した時は error を投げ、回数を変えない。回数を置き換える時も同じ。
    @Test func 保存に失敗した時は回数を変えない() throws {
        let freeReadingStartCount = FreeReadingStartCount(store: makeFailingStore(loadFails: false, saveFails: true, loadedCount: 5))

        #expect(throws: FreeReadingStartCountKeychainError.self) {
            try freeReadingStartCount.increment()
        }
        #expect(throws: FreeReadingStartCountKeychainError.self) {
            try freeReadingStartCount.replace(newCount: 19)
        }
        #expect(freeReadingStartCount.count == 5)
    }

    /// 回数を置き換えると、保存先にも置き換えた回数が保存される。
    @Test func 回数を置き換えると保存先にも保存される() throws {
        let store = makeInMemoryFreeReadingStartCountStore()
        let freeReadingStartCount = FreeReadingStartCount(store: store)

        try freeReadingStartCount.replace(newCount: 19)

        #expect(freeReadingStartCount.count == 19)
        #expect(try store.load() == 19)
    }

    /// 起動した時に読み出せなかった時は、回数を 0 回にせず nil にし、増やそうとすると `FreeReadingStartCountUnavailableError` を投げる。
    /// もう一度読み出そうとした時も、読み出せなければ保存先の error を投げる。
    @Test func 読み出せなかった時は回数を0回にしない() throws {
        let freeReadingStartCount = FreeReadingStartCount(store: makeFailingStore(loadFails: true, saveFails: false, loadedCount: 5))

        #expect(freeReadingStartCount.count == nil)
        #expect(throws: FreeReadingStartCountUnavailableError.self) {
            try freeReadingStartCount.increment()
        }
        #expect(throws: FreeReadingStartCountKeychainError.self) {
            _ = try freeReadingStartCount.loadedCount()
        }
    }

    /// 起動した時に読み出せなかった後で、読み出せるようになると、その回数を返して持つ。
    @Test func 起動した時に読み出せなかった後で読み出せると回数を持つ() throws {
        let freeReadingStartCount = FreeReadingStartCount(
            store: FreeReadingStartCountStore(load: LoadsAfterFirstFailure(loadedCount: 7).load, save: { _ in })
        )
        #expect(freeReadingStartCount.count == nil)

        #expect(try freeReadingStartCount.loadedCount() == 7)
        #expect(freeReadingStartCount.count == 7)
    }

    /// 1 回目の読み出しだけ失敗し、2 回目からは `loadedCount` を返す読み出し。
    private final class LoadsAfterFirstFailure {
        /// 2 回目から返す回数。
        private let loadedCount: Int
        /// 読み出しが呼ばれた回数。
        private var loadCallCount = 0

        /// 2 回目から返す回数 `loadedCount` を決めて作る。
        init(loadedCount: Int) {
            self.loadedCount = loadedCount
        }

        /// 1 回目は error を投げ、2 回目からは回数を返す。
        func load() throws -> Int {
            loadCallCount += 1
            guard loadCallCount > 1 else {
                throw FreeReadingStartCountKeychainError(status: errSecInteractionNotAllowed)
            }
            return loadedCount
        }
    }
}
