import Foundation
import Security

/// 無料で始めた読書の回数の保存先。読み出しと書き込みの 2 つの操作を持つ。
///
/// アプリは端末の Keychain に置く (`makeKeychainFreeReadingStartCountStore`)。UserDefaults に置かないのは、アプリを消すと消え、
/// 入れ直すと回数が 0 回に戻るため (owner の決定「それはダメ」 https://github.com/bannzai/doquiz/pull/84#issuecomment-7071830203 )。
/// UI テストとテストは、端末の Keychain に触れないメモリ内の保存先 (`makeInMemoryFreeReadingStartCountStore`) を使う。
struct FreeReadingStartCountStore {
    /// 保存した回数を返す。まだ一度も保存していない時は 0 を返す。読み出せない時は error を投げる。
    let load: () throws -> Int
    /// 回数 `count` を保存する。保存できない時は error を投げる。同じ回数を何度保存しても結果は同じ。
    let save: (_ count: Int) throws -> Void
}

/// Keychain の読み書きが失敗したことを表す error。`status` は Security framework が返した結果のコード
/// (読み出した値を回数として解釈できなかった時は `errSecDecode`)。
struct FreeReadingStartCountKeychainError: Error {
    /// `SecItemCopyMatching`・`SecItemAdd`・`SecItemUpdate` が返した結果のコード。
    let status: OSStatus
}

/// Keychain の項目を読み書きする 3 つの操作。アプリは Security framework の関数をそのまま渡す (`makeKeychainFreeReadingStartCountStore` の既定)。
///
/// 回数の保存先の分岐 (項目が無い時・更新と追加の切り替え・失敗) を、Keychain を使えない CI の単体テストでも確かめられるように、引数で渡す。
struct KeychainOperations {
    /// `SecItemCopyMatching` と同じ契約で、`query` に当たる項目を探し、見つかった値を `result` に入れて結果のコードを返す。
    let copyMatching: (_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>) -> OSStatus
    /// `SecItemUpdate` と同じ契約で、`query` に当たる項目を `attributesToUpdate` で書き換えて結果のコードを返す。
    let update: (_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus
    /// `SecItemAdd` と同じ契約で、`attributes` の項目を足して結果のコードを返す。
    let add: (_ attributes: CFDictionary) -> OSStatus
}

/// 無料で始めた読書の回数を、Keychain の generic password の項目 1 つ (サービス `service`・アカウント `freeReadingStartCount`) に置く保存先を返す。
///
/// - 値は回数の 10 進の文字列を UTF-8 にしたもの
/// - 項目が無い時 (`errSecItemNotFound`) は、まだ一度も保存していないとして 0 を返す。それ以外の失敗と、値を回数として解釈できない時は
///   `FreeReadingStartCountKeychainError` を投げる
/// - 保存は、項目があれば書き換え、無ければ足す
/// - 読み書きできるのは、端末の起動後に 1 度ロックを解いた後 (`kSecAttrAccessibleAfterFirstUnlock`)。読書を始めるのは利用者が端末を操作している時のため。
///   `ThisDeviceOnly` にしないのは、端末のバックアップから新しい端末へ移した時にも回数を引き継ぐため
/// - アプリを消した後も Keychain の項目が残ることは、Apple の文書が定めた契約ではなく、iOS の今の振る舞い (PR 本文の出典)
/// - Parameter keychain: Keychain の操作。既定は Security framework の関数 (アプリはこれを使う。テストだけが偽の操作を渡す)
func makeKeychainFreeReadingStartCountStore(
    service: String,
    keychain: KeychainOperations = KeychainOperations(
        copyMatching: { SecItemCopyMatching($0, $1) },
        update: { SecItemUpdate($0, $1) },
        add: { SecItemAdd($0, nil) }
    )
) -> FreeReadingStartCountStore {
    let itemQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: "freeReadingStartCount",
    ]
    return FreeReadingStartCountStore(
        load: {
            var result: CFTypeRef?
            let status = keychain.copyMatching(
                itemQuery.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { $1 } as CFDictionary,
                &result
            )
            guard status != errSecItemNotFound else {
                return 0
            }
            guard status == errSecSuccess else {
                throw FreeReadingStartCountKeychainError(status: status)
            }
            guard let data = result as? Data, let count = Int(String(decoding: data, as: UTF8.self)) else {
                throw FreeReadingStartCountKeychainError(status: errSecDecode)
            }
            return count
        },
        save: { count in
            let data = Data(String(count).utf8)
            let updateStatus = keychain.update(itemQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecItemNotFound else {
                guard updateStatus == errSecSuccess else {
                    throw FreeReadingStartCountKeychainError(status: updateStatus)
                }
                return
            }
            let addStatus = keychain.add(
                itemQuery.merging([kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]) { $1 } as CFDictionary
            )
            guard addStatus == errSecSuccess else {
                throw FreeReadingStartCountKeychainError(status: addStatus)
            }
        }
    )
}

/// アプリ (UI テスト・単体テストの起動ではない時) が使う、無料で始めた読書の回数の保存先を返す。
///
/// - 実機と、DEBUG ではないビルドは、端末の Keychain に置く (`makeKeychainFreeReadingStartCountStore`)
/// - DEBUG の Simulator のビルドは、`userDefaults` の整数 1 つ (キー `freeReadingStartCount`) に置く。owner が手元で使う `make`
///   (Makefile の `build-ios`) は署名しない Simulator のビルドで、署名しないビルドでは Keychain の読み書きが `errSecMissingEntitlement` (-34018) で
///   失敗するため (CI の同じ署名しないビルドの run https://github.com/bannzai/doquiz/actions/runs/44969559446 で実測)。Simulator ではアプリを入れ直した後に
///   回数を残す必要が無い (公開する版は実機で動く) ため、UserDefaults に置く
func makeAppFreeReadingStartCountStore(userDefaults: UserDefaults) -> FreeReadingStartCountStore {
    #if DEBUG && targetEnvironment(simulator)
        FreeReadingStartCountStore(
            load: { userDefaults.integer(forKey: "freeReadingStartCount") },
            save: { userDefaults.set($0, forKey: "freeReadingStartCount") }
        )
    #else
        makeKeychainFreeReadingStartCountStore(service: "app.bannzai.doquiz.freeReadingStartCount")
    #endif
}

/// 端末の Keychain に触れず、メモリの中だけに回数を置く保存先を返す。UI テストの起動とテストで使う。初めの回数は 0。
func makeInMemoryFreeReadingStartCountStore() -> FreeReadingStartCountStore {
    let storedCount = InMemoryFreeReadingStartCount()
    return FreeReadingStartCountStore(
        load: { storedCount.value },
        save: { storedCount.value = $0 }
    )
}

/// メモリの中だけに置いた回数。`makeInMemoryFreeReadingStartCountStore` の読み出しと書き込みで同じ値を共有するための入れ物。
private final class InMemoryFreeReadingStartCount {
    /// 保存した回数。
    var value = 0
}
