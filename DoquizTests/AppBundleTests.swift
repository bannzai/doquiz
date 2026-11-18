import Foundation
import Testing

/// ビルドしたアプリの Info.plist が、ホーム画面に出す前提の値になっていることを確かめる。
struct AppBundleTests {
    /// ホーム画面に出る名前 (`CFBundleDisplayName`) が「doquiz」であることを確かめる。
    @Test func ホーム画面に出る名前はdoquiz() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "doquiz")
    }

    /// 背面で動かす処理の宣言 (`UIBackgroundModes`) が、画面の取り込み (`screen-capture`) だけであることを確かめる。
    /// 読書アプリを表示している間 (doquiz が背面にある間) も取り込みを続けるのに要る。
    @Test func 背面で動かす処理の宣言は画面の取り込みだけ() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] == ["screen-capture"])
    }
}
