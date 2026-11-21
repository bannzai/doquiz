import XCTest

/// 設定の画面を操作して確かめ、画面のスクリーンショットをテスト結果に添付する UI テスト。
final class SettingsTests: XCTestCase {
    /// 今の画面を `name` の名前でテスト結果に添付する。
    @MainActor
    private func attachScreenshot(app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 画面のうち、identifier が `identifier` の要素を返す。
    /// SwiftUI の `Link` が UI テストでどの種類の要素として見えるかに依らないよう、種類を限らずに探す (購入の UI テストと同じ探し方)。
    @MainActor
    private func element(app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// ホームの左上の歯車から設定の画面を開くと、購入のプランを見る行・利用規約・プライバシーポリシー・特定商取引法に基づく表記・お問い合わせの 5 つの行が出る。
    /// 購入のプランを見る行を押すと購入の画面が出て、閉じると設定の画面に戻る。
    /// 購入の画面への入口は、読書を 1 回も始めていない利用者にも出る (ホームの入口と違い、設定の画面の入口はいつも出す)。
    /// 設定の画面を `settings` の名前で添付する。
    @MainActor
    func test設定の画面に購入の入口と文書の行と問い合わせの行が出る() {
        let app = launchAppWithInMemoryStore()
        // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、待ちの上限を長めに取る (ScreenshotTests と同じ値)。
        XCTAssertTrue(app.buttons["settings_entrance"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["purchase_entrance"].exists)
        app.buttons["settings_entrance"].tap()

        XCTAssertTrue(app.buttons["settings_purchase_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.buttons["settings_purchase_entrance"].label.contains("購入のプランを見る"))
        for (identifier, title) in [
            ("settings_terms_of_use_link", "利用規約"),
            ("settings_privacy_policy_link", "プライバシーポリシー"),
            ("settings_specified_commercial_transaction_act_link", "特定商取引法に基づく表記"),
            ("settings_contact_link", "お問い合わせ"),
        ] {
            let row = element(app: app, identifier: identifier)
            XCTAssertTrue(row.exists, "\(identifier) の行が無い")
            XCTAssertTrue(row.label.contains(title), "\(identifier) の行の名前が \(row.label)")
        }
        attachScreenshot(app: app, name: "settings")

        app.buttons["settings_purchase_entrance"].tap()
        XCTAssertTrue(app.buttons["purchase_close_button"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["purchase_close_button"].tap()
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["purchase_close_button"])],
                timeout: sameScreenChangeWaitTimeout
            ),
            .completed,
            "購入の画面が閉じなかった"
        )
        XCTAssertTrue(app.buttons["settings_purchase_entrance"].exists)
    }
}
