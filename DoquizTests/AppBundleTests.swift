import Foundation
import Testing

/// ビルドしたアプリの Info.plist が、ホーム画面とストアに出す前提の値になっていることを確かめる。
struct AppBundleTests {
    @Test func ホーム画面に出る名前はdoquiz() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "doquiz")
    }

    @Test func bundleIDはappBannzaiDoquiz() {
        #expect(Bundle.main.bundleIdentifier == "app.bannzai.doquiz")
    }
}
