import XCTest

/// 画面のスクリーンショットをテスト結果に添付し、CI の artifact から見た目を確かめられるようにする UI テスト。
final class ScreenshotTests: XCTestCase {
    /// 起動直後の画面にアプリの名前が出ていることを確かめ、その画面を `launch` の名前で添付する。
    @MainActor
    func test起動直後の画面にアプリの名前が出る() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["doquiz"].waitForExistence(timeout: 30))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
