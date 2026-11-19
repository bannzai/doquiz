import Foundation
import Testing

@testable import Doquiz

/// アプリの設定を読み書きする UserDefaults の選び方を確かめる。
struct AppUserDefaultsTests {
    /// 端末の保存先を使う起動では、端末の標準の UserDefaults を返す。
    @Test func 端末の保存先の起動では標準のUserDefaultsを返す() {
        #expect(makeAppUserDefaults(isStoredInMemoryOnly: false) === UserDefaults.standard)
    }

    /// メモリ内の保存先の起動では、標準とは別の UserDefaults を返し、前の起動で書いた同意済みの値が残っていない。
    @Test func メモリ内の保存先の起動では前に書いた値が残っていない() {
        let previousUserDefaults = makeAppUserDefaults(isStoredInMemoryOnly: true)
        previousUserDefaults.set(true, forKey: hasAgreedToScreenCaptureKey)
        #expect(previousUserDefaults.bool(forKey: hasAgreedToScreenCaptureKey))

        let userDefaults = makeAppUserDefaults(isStoredInMemoryOnly: true)

        #expect(userDefaults !== UserDefaults.standard)
        #expect(userDefaults.object(forKey: hasAgreedToScreenCaptureKey) == nil)
    }
}
