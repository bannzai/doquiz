import XCTest

/// 初めて「読書を始める」を押した後に出る取り込みの手順の案内で「次へ」を押し、続く同意の説明で「同意して始める」を押す。
///
/// 前提: `app` は「読書を始める」を押した直後で、まだ同意していない。
@MainActor
func agreeToScreenCaptureAfterGuide(app: XCUIApplication) {
    XCTAssertTrue(app.buttons["screen_capture_guide_next"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
    app.buttons["screen_capture_guide_next"].tap()
    XCTAssertTrue(app.buttons["screen_capture_consent_agree"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
    app.buttons["screen_capture_consent_agree"].tap()
}
