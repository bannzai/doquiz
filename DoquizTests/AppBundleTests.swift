import Foundation
import Testing

/// ビルドしたアプリの Info.plist が、ホーム画面とストアに出す前提の値になっていることを確かめる。
struct AppBundleTests {
    /// ホーム画面に出る名前 (`CFBundleDisplayName`) が「doquiz」であることを確かめる。
    @Test func ホーム画面に出る名前はdoquiz() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "doquiz")
    }

    /// bundle ID が、ストアに登録する前提の `app.bannzai.doquiz` であることを確かめる。
    @Test func bundleIDはappBannzaiDoquiz() {
        #expect(Bundle.main.bundleIdentifier == "app.bannzai.doquiz")
    }
}
