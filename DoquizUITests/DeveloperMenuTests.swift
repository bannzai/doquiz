import XCTest

/// 開発用のビルドだけに出る開発者メニューを、起動直後の画面から開いて操作できることを確かめる UI テスト。
final class DeveloperMenuTests: XCTestCase {
    /// 開発者メニューが出している保存データの件数が、本・読書の記録・ページ・問い・回答の順に `expectedCounts` と同じになるまで待つ。
    ///
    /// 件数の表示は操作の後に遅れて変わるため、変わるまで待ってから比べる。待ちの上限を過ぎても違う時はテストを失敗にする。
    @MainActor
    private func assertSavedCounts(app: XCUIApplication, expectedCounts: [String]) {
        for (countIdentifier, expectedCount) in zip(
            [
                "developer_menu_book_count",
                "developer_menu_reading_session_count",
                "developer_menu_captured_page_count",
                "developer_menu_question_count",
                "developer_menu_answer_count",
            ],
            expectedCounts
        ) {
            let countText = app.staticTexts[countIdentifier]
            // 上限の 10 秒は、起動の待ち (30 秒) と違い、同じ画面の中の表示の更新だけを待つため短くしている。
            XCTAssertEqual(
                XCTWaiter().wait(
                    for: [
                        XCTNSPredicateExpectation(
                            predicate: NSPredicate(format: "label == %@", expectedCount),
                            object: countText
                        )
                    ],
                    timeout: 10
                ),
                .completed,
                "\(countIdentifier) の件数が \(expectedCount) にならなかった (表示: \(countText.exists ? countText.label : "要素が無い"))"
            )
        }
    }

    /// 起動直後の画面から開発者メニューを開き、全部消すと 5 つの型が 0 件、見本のデータを入れると本 2 冊・読書の記録 3 件・ページ 4 件・
    /// 問い 6 問・回答 7 件になることを確かめ、見本を入れた時のメニューの画面を `developer-menu` の名前で添付する。
    /// 最後にもう一度全部消して、ほかの UI テストに見本のデータを残さない。
    @MainActor
    func test開発者メニューで見本のデータを入れて全部消せる() {
        let app = XCUIApplication()
        app.launch()
        // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、待ちの上限を長めに取る (ScreenshotTests と同じ値)。
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.buttons["developer_menu_delete_all_saved_data"].waitForExistence(timeout: 10))

        app.buttons["developer_menu_delete_all_saved_data"].tap()
        assertSavedCounts(app: app, expectedCounts: ["0", "0", "0", "0", "0"])

        app.buttons["developer_menu_replace_sample_data"].tap()
        assertSavedCounts(app: app, expectedCounts: ["2", "3", "4", "6", "7"])
        XCTAssertFalse(app.staticTexts["developer_menu_failure_description"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "developer-menu"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["developer_menu_delete_all_saved_data"].tap()
        assertSavedCounts(app: app, expectedCounts: ["0", "0", "0", "0", "0"])
    }
}
