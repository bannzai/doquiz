import XCTest

/// App Store の製品ページに出す日本語のスクリーンショットを撮り、テスト結果に添付する UI テスト。
///
/// `.github/workflows/appstore-screenshots.yml` が、Apple が必須にしている大きさの iPhone の Simulator で動かし、
/// 添付した画像を `scripts/generate_screenshots/organize_appstore_screenshots.sh` が掲載順のファイル名に直す。
/// 画面の中身は、アプリの `Doquiz/AppStoreScreenshots/` が描く。
final class AppStoreScreenshotTests: XCTestCase {
    /// 撮るスクリーンショット。並びの順が製品ページに出す順で、値はアプリの `AppStoreScreenshotPage` の値と同じ。
    /// UI テストはアプリの型を読めないため、値を書き写している。アプリ側の値を変えた時は、ここも手で合わせる
    /// (合っていない値は、アプリが `nil` を返してアプリの画面のまま起動し、下のキャッチコピーの待ちで落ちる)。
    private let pages = ["quiz", "reading", "question-kinds", "evidence", "privacy", "history"]

    /// 各スクリーンショットの画面を開いて、`appstore-ja-<掲載順の 2 桁>-<値>` の名前で添付する。
    ///
    /// 根拠の本文のスクリーンショット (`evidence`) は、要約の正誤の問いで合っている選択肢 (合っていない) を押して、答えた後の画面を撮る。
    @MainActor
    func testAppStoreの日本語のスクリーンショットを撮る() {
        for (pageIndex, page) in pages.enumerated() {
            let app = XCUIApplication()
            // 日本語の字形で描くよう、端末の言語と地域を日本語にする (英語のままだと、漢字が中国語の字形で出ることがある)。
            app.launchArguments += ["-uiTestInMemoryStore", "-appStoreScreenshotPage", page, "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
            app.launch()
            // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、ほかの UI テストの起動と同じく 30 秒待つ。
            XCTAssertTrue(app.staticTexts["app_store_screenshot_title"].waitForExistence(timeout: 30), "\(page) の画面が出ない")
            if page == "evidence" {
                XCTAssertEqual(app.buttons["quiz_choice_1"].label, "合っていない")
                app.buttons["quiz_choice_1"].tap()
                XCTAssertTrue(app.staticTexts["quiz_evidence_quote"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
                XCTAssertEqual(app.staticTexts["quiz_judgement"].label, "合っています")
            }
            // 答えた時の紙吹雪 (遅れ 0.45 秒の後に 1.4 秒かけて落ちる。`Doquiz/Quiz/QuizAnswerMotion.swift`) と、
            // 進み具合の線が伸びる動き (0.5 秒) が終わってから撮るため、長い方の 1.85 秒に余りを足した 3 秒待つ。
            sleep(3)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = String(format: "appstore-ja-%02d-%@", pageIndex + 1, page)
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }
}
