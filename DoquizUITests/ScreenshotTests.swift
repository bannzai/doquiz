import XCTest

/// 画面のスクリーンショットをテスト結果に添付し、CI の artifact から見た目を確かめられるようにする UI テスト。
final class ScreenshotTests: XCTestCase {
    /// 起動直後の画面にアプリの名前が出ていることを確かめ、その画面を `launch` の名前で添付する。
    @MainActor
    func test起動直後の画面にアプリの名前が出る() {
        let app = XCUIApplication()
        app.launch()
        // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、待ちの上限を長めに取る。
        // CI の実測 (https://github.com/bannzai/doquiz/actions/runs/43983732332) では、起動を含むテスト全体が 57 秒で、この上限の中で表示された。
        XCTAssertTrue(app.staticTexts["doquiz"].waitForExistence(timeout: 30))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
