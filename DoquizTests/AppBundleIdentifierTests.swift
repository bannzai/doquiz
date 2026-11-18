import Foundation
import Testing

/// ビルドしたアプリの bundle ID が、ストアに登録する前提の値になっていることを確かめる。
struct AppBundleIdentifierTests {
    /// bundle ID が、ストアに登録する前提の `app.bannzai.doquiz` であることを確かめる。
    @Test func bundleIDはappBannzaiDoquiz() {
        #expect(Bundle.main.bundleIdentifier == "app.bannzai.doquiz")
    }
}
