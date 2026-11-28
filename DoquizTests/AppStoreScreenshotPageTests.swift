import Testing
@testable import Doquiz

/// App Store のスクリーンショットの画面を出すかを、起動の引数から決める判定を確かめる。テストは開発用のビルド (DEBUG) で動く。
struct AppStoreScreenshotPageTests {
    /// `-appStoreScreenshotPage` の次の値が、ほかの引数と並んでいても、その値のスクリーンショットになることを確かめる。
    @Test(arguments: [
        (["-appStoreScreenshotPage", "quiz"], AppStoreScreenshotPage.quiz),
        (["/path/to/Doquiz", "-uiTestInMemoryStore", "-appStoreScreenshotPage", "question-kinds"], .questionKinds),
        (["-appStoreScreenshotPage", "history", "-AppleLanguages", "(ja)"], .history),
    ])
    func 引数の値のスクリーンショットを出す(launchArguments: [String], page: AppStoreScreenshotPage) {
        #expect(appStoreScreenshotPage(launchArguments: launchArguments) == page)
    }

    /// 引数が無い時・値が無い時・値がどのスクリーンショットにも当たらない時・引数の名前が違う時は、アプリの画面のまま (nil) にすることを確かめる。
    @Test(arguments: [
        [],
        ["/path/to/Doquiz", "-uiTestInMemoryStore"],
        ["-appStoreScreenshotPage"],
        ["-appStoreScreenshotPage", "questionKinds"],
        ["-appStoreScreenshotPage", "Quiz"],
        ["-appstorescreenshotpage", "quiz"],
        ["appStoreScreenshotPage", "quiz"],
    ])
    func 引数が無いか当たらない時はアプリの画面のままにする(launchArguments: [String]) {
        #expect(appStoreScreenshotPage(launchArguments: launchArguments) == nil)
    }

    /// 製品ページに出す順が DIRECTION.md に記録した順であり、撮影のテストと書き出しのファイル名に使う値であることを確かめる。
    @Test
    func 並びの順と値が撮影に使う値と同じ() {
        #expect(AppStoreScreenshotPage.allCases.map(\.rawValue) == ["quiz", "reading", "question-kinds", "evidence", "privacy", "history"])
    }
}
