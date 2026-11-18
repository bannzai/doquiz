import Foundation
import Testing

/// ビルドしたアプリの Info.plist が、ホーム画面に出す前提の値になっていることを確かめる。
struct AppBundleTests {
    /// ホーム画面に出る名前 (`CFBundleDisplayName`) が「doquiz」であることを確かめる。
    @Test func ホーム画面に出る名前はdoquiz() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "doquiz")
    }
}
