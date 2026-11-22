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

/// Keychain の読み書きが失敗したことを表す error。`status` は Security framework が返した結果のコード。
struct FreeReadingStartCountKeychainError: Error {
    /// `SecItemCopyMatching`・`SecItemAdd`・`SecItemUpdate` が返した結果のコード。
    let status: OSStatus
}

/// 無料で始めた読書の回数を、端末の Keychain の generic password の項目 1 つ (サービス `service`・アカウント `freeReadingStartCount`) に置く保存先を返す。
///
/// - 値は回数の 10 進の文字列を UTF-8 にしたもの
/// - 項目が無い時 (`errSecItemNotFound`) は、まだ一度も保存していないとして 0 を返す。それ以外の失敗は `FreeReadingStartCountKeychainError` を投げる
/// - 読み書きできるのは、端末の起動後に 1 度ロックを解いた後 (`kSecAttrAccessibleAfterFirstUnlock`)。読書を始めるのは利用者が端末を操作している時のため。
///   `ThisDeviceOnly` にしないのは、端末のバックアップから新しい端末へ移した時にも回数を引き継ぐため
/// - アプリを消した後も Keychain の項目が残ることは、Apple の文書が定めた契約ではなく、iOS の今の振る舞い (PR 本文の出典)
func makeKeychainFreeReadingStartCountStore(service: String) -> FreeReadingStartCountStore {
    let itemQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: "freeReadingStartCount",
    ]
    return FreeReadingStartCountStore(
        load: {
            var result: CFTypeRef?
            let status = SecItemCopyMatching(
                itemQuery.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { $1 } as CFDictionary,
                &result
            )
            guard status != errSecItemNotFound else {
                return 0
            }
            guard status == errSecSuccess, let data = result as? Data, let count = Int(String(decoding: data, as: UTF8.self)) else {
                throw FreeReadingStartCountKeychainError(status: status)
            }
            return count
        },
        save: { count in
            let data = Data(String(count).utf8)
            let updateStatus = SecItemUpdate(itemQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecItemNotFound else {
                guard updateStatus == errSecSuccess else {
                    throw FreeReadingStartCountKeychainError(status: updateStatus)
                }
                return
            }
            let addStatus = SecItemAdd(
                itemQuery.merging([kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]) { $1 } as CFDictionary,
                nil
            )
            guard addStatus == errSecSuccess else {
                throw FreeReadingStartCountKeychainError(status: addStatus)
            }
        }
    )
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
