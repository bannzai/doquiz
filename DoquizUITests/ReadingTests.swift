import XCTest

/// 本の画面の「読書を始める」から「読書を終える」までを操作して確かめ、画面のスクリーンショットをテスト結果に添付する UI テスト。
///
/// 画面の取り込みは iOS Simulator で動かないため、開発者メニューで偽の取り込みに切り替えて確かめる。
final class ReadingTests: XCTestCase {
    /// 今の画面を `name` の名前でテスト結果に添付する。
    @MainActor
    private func attachScreenshot(app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// `element` が `predicateFormat` の条件を満たすまで待つ。待ちの上限を過ぎても満たさない時はテストを失敗にする。
    @MainActor
    private func assertEventually(element: XCUIElement, predicateFormat: String, argument: String) {
        // 上限の 10 秒は、起動の待ち (30 秒) と違い、同じ画面の中の表示の更新だけを待つため短くしている (DeveloperMenuTests と同じ値)。
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: predicateFormat, argument), object: element)],
                timeout: 10
            ),
            .completed,
            "\(element) が \(predicateFormat) (\(argument)) にならなかった (表示: \(element.exists ? element.label : "要素が無い"))"
        )
    }

    /// `element` が画面から無くなるまで待つ。待ちの上限を過ぎても残っている時はテストを失敗にする。
    @MainActor
    private func assertDisappears(element: XCUIElement) {
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)],
                timeout: 10
            ),
            .completed,
            "\(element) が画面に残っている"
        )
    }

    /// 起動直後の一覧から開発者メニューを開き、読書を偽の取り込みに、読書を終えた後のクイズを問いを返さない偽のクイズに切り替えて、一覧に戻る。
    ///
    /// クイズを偽物にするのは、端末内のモデルが GitHub の runner の Simulator で使えるかに結果が左右されないようにするため。
    @MainActor
    private func switchToFakeReading(app: XCUIApplication) {
        // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、待ちの上限を長めに取る (ScreenshotTests と同じ値)。
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.buttons["developer_menu_toggle_fake_reading"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["developer_menu_uses_fake_reading_state"].label, "オフ")
        app.buttons["developer_menu_toggle_fake_reading"].tap()
        assertEventually(element: app.staticTexts["developer_menu_uses_fake_reading_state"], predicateFormat: "label == %@", argument: "オン")
        // クイズの切り替えは一覧の下にあり、画面に入っていないことがあるため、上へ送ってから押す。
        app.swipeUp()
        XCTAssertTrue(app.buttons["developer_menu_cycle_fake_quiz_behavior"].waitForExistence(timeout: 10))
        app.buttons["developer_menu_cycle_fake_quiz_behavior"].tap()
        assertEventually(element: app.staticTexts["developer_menu_fake_quiz_behavior_state"], predicateFormat: "label == %@", argument: "問いを返す")
        app.buttons["developer_menu_cycle_fake_quiz_behavior"].tap()
        assertEventually(element: app.staticTexts["developer_menu_fake_quiz_behavior_state"], predicateFormat: "label == %@", argument: "問いを返さない")
        app.navigationBars.buttons.firstMatch.tap()
    }

    /// 読書を終えた後に出るクイズの画面 (問いが 1 問も無い時の案内) から、「本の画面に戻る」で本の画面に戻る。
    @MainActor
    private func leaveQuizWithoutQuestions(app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["quiz_guide"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["quiz_guide"].label.contains("今回の読書のクイズはありません"))
        app.buttons["quiz_leave"].tap()
        assertDisappears(element: app.buttons["quiz_leave"])
    }

    /// 起動直後の一覧から開発者メニューを開き、読書を偽の取り込みに切り替え、その取り込みが途中で止まるようにして、一覧に戻る。
    @MainActor
    private func switchToInterruptedFakeReading(app: XCUIApplication) {
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.buttons["developer_menu_toggle_fake_reading"].waitForExistence(timeout: 10))
        app.buttons["developer_menu_toggle_fake_reading"].tap()
        assertEventually(element: app.staticTexts["developer_menu_uses_fake_reading_state"], predicateFormat: "label == %@", argument: "オン")
        // 途中で止める切り替えは一覧の下にあり、画面に入っていないことがあるため、上へ送ってから押す。
        app.swipeUp()
        XCTAssertTrue(app.buttons["developer_menu_toggle_interrupts_fake_reading"].waitForExistence(timeout: 10))
        app.buttons["developer_menu_toggle_interrupts_fake_reading"].tap()
        assertEventually(element: app.staticTexts["developer_menu_interrupts_fake_reading_state"], predicateFormat: "label == %@", argument: "オン")
        app.navigationBars.buttons.firstMatch.tap()
    }

    /// 起動直後の一覧から、名前が `title` の本を登録して、その本の画面を開き、「読書を始める」が出るまで待つ。
    @MainActor
    private func registerBookAndOpen(app: XCUIApplication, title: String) {
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: 30))
        app.buttons["book_registration_entrance"].tap()
        XCTAssertTrue(app.textFields["book_registration_title_field"].waitForExistence(timeout: 10))
        typeTextAfterKeyboardFocus(element: app.textFields["book_registration_title_field"], text: title)
        app.buttons["book_registration_submit"].tap()
        let bookRow = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "book_list_row", title)).firstMatch
        XCTAssertTrue(bookRow.waitForExistence(timeout: 10))
        bookRow.tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: 10))
    }

    /// 本の画面から一覧に戻って開発者メニューを開き、保存されている読書の記録の件数が `expectedCount` になるまで待つ。
    @MainActor
    private func assertSavedReadingSessionCount(app: XCUIApplication, expectedCount: String) {
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 10))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.staticTexts["developer_menu_reading_session_count"].waitForExistence(timeout: 10))
        assertEventually(element: app.staticTexts["developer_menu_reading_session_count"], predicateFormat: "label == %@", argument: expectedCount)
    }

    /// 初めて「読書を始める」を押すと同意の説明が出て、同意すると取り込み中の表示・読んでいる本の名前・「読書を終える」が出る。
    /// 「読書を終える」を押すとクイズの画面に切り替わり、そこから本の画面に戻ると、読書の回数が 1 回になっている。
    /// 2 回目に「読書を始める」を押した時は、同意の説明が出ずに読書中の画面が出て、終えると読書の記録が 2 件保存されている。
    /// 「読書を始める」のある本の画面を `book-reading-start`、同意の説明を `screen-capture-consent`、読書中の画面を `reading` の名前で添付する。
    @MainActor
    func test初回だけ同意の説明が出て読書を始めて終えると本の画面に戻る() {
        let app = launchAppWithInMemoryStore()
        switchToFakeReading(app: app)
        registerBookAndOpen(app: app, title: "潮見町の灯台日誌")
        XCTAssertEqual(app.staticTexts["book_reading_summary"].label, "まだ読んでいません")
        XCTAssertFalse(app.staticTexts["reading_guide"].exists)
        attachScreenshot(app: app, name: "book-reading-start")

        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.staticTexts["screen_capture_consent_title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["reading_end"].exists)
        attachScreenshot(app: app, name: "screen-capture-consent")

        app.buttons["screen_capture_consent_agree"].tap()
        XCTAssertTrue(app.buttons["reading_end"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["reading_capturing_indicator"].label, "取り込み中")
        XCTAssertEqual(app.staticTexts["reading_book_title"].label, "潮見町の灯台日誌")
        XCTAssertEqual(app.staticTexts["reading_elapsed_time"].label, "0 分")
        XCTAssertFalse(app.staticTexts["screen_capture_consent_title"].exists)
        attachScreenshot(app: app, name: "reading")

        app.buttons["reading_end"].tap()
        assertDisappears(element: app.buttons["reading_end"])
        leaveQuizWithoutQuestions(app: app)
        XCTAssertEqual(app.staticTexts["book_title"].label, "潮見町の灯台日誌")
        assertEventually(element: app.staticTexts["book_reading_summary"], predicateFormat: "label BEGINSWITH %@", argument: "読書 1 回 ・ 最後に読んだのは")
        XCTAssertFalse(app.staticTexts["reading_guide"].exists)

        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["reading_end"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["screen_capture_consent_title"].exists)
        app.buttons["reading_end"].tap()
        assertDisappears(element: app.buttons["reading_end"])
        leaveQuizWithoutQuestions(app: app)
        assertEventually(element: app.staticTexts["book_reading_summary"], predicateFormat: "label BEGINSWITH %@", argument: "読書 2 回 ・ 最後に読んだのは")

        assertSavedReadingSessionCount(app: app, expectedCount: "2")
    }

    /// 同意の説明で「やめる」を押すと、読書中の画面が出ずに本の画面に戻り、次に「読書を始める」を押した時にもう一度同意の説明が出る。
    @MainActor
    func test同意の説明でやめると読書は始まらず次もまた説明が出る() {
        let app = launchAppWithInMemoryStore()
        switchToFakeReading(app: app)
        registerBookAndOpen(app: app, title: "はじめての堆肥づくり")

        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["screen_capture_consent_cancel"].waitForExistence(timeout: 10))
        app.buttons["screen_capture_consent_cancel"].tap()
        assertDisappears(element: app.staticTexts["screen_capture_consent_title"])
        XCTAssertFalse(app.buttons["reading_end"].exists)
        XCTAssertEqual(app.staticTexts["book_reading_summary"].label, "まだ読んでいません")

        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.staticTexts["screen_capture_consent_title"].waitForExistence(timeout: 10))
        app.buttons["screen_capture_consent_cancel"].tap()
        assertDisappears(element: app.staticTexts["screen_capture_consent_title"])

        assertSavedReadingSessionCount(app: app, expectedCount: "0")
    }

    /// 取り込みが途中で止まった時は、「読書を終える」を押さなくても読書中の画面が閉じ、クイズの画面は出ずに、本の画面に途中で止まったことの案内が出て、
    /// 終えた読書の記録が 1 件残る (読書の回数が 1 回になる)。
    /// 案内の出た本の画面を `book-reading-interrupted` の名前で添付する。
    @MainActor
    func test取り込みが途中で止まると読書中の画面が閉じて案内が出る() {
        let app = launchAppWithInMemoryStore()
        switchToInterruptedFakeReading(app: app)
        registerBookAndOpen(app: app, title: "潮見町の灯台日誌")

        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["screen_capture_consent_agree"].waitForExistence(timeout: 10))
        app.buttons["screen_capture_consent_agree"].tap()
        XCTAssertTrue(app.buttons["reading_end"].waitForExistence(timeout: 10))

        // 偽の取り込みは、画像 2 枚 (1 枚ごとに 1 秒待つ) を流した後に止まる。
        assertDisappears(element: app.buttons["reading_end"])
        XCTAssertTrue(app.staticTexts["reading_guide"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["reading_guide"].label.contains("取り込みが途中で止まったため 読書を終えました"))
        // クイズの画面が出る時は、問いを作っている間の表示か、クイズを出さない時の案内のどちらかが出る。
        XCTAssertFalse(app.staticTexts["quiz_preparing"].exists)
        XCTAssertFalse(app.staticTexts["quiz_guide"].exists)
        assertEventually(element: app.staticTexts["book_reading_summary"], predicateFormat: "label BEGINSWITH %@", argument: "読書 1 回 ・ 最後に読んだのは")
        attachScreenshot(app: app, name: "book-reading-interrupted")

        assertSavedReadingSessionCount(app: app, expectedCount: "1")
    }

    /// 取り込みを始められない時 (偽の取り込みに切り替えていない iOS Simulator は、画面の取り込みを使えない) は、
    /// 読書中の画面が出ず、本の画面に始められないことの案内が出て、読書の記録が 1 件も残らない。
    /// 同意は済んでいるため、もう一度「読書を始める」を押した時は、同意の説明が出ない。
    /// 案内の出た本の画面を `book-reading-start-failure` の名前で添付する。
    @MainActor
    func test取り込みを始められない時は案内が出て読書の記録が残らない() {
        let app = launchAppWithInMemoryStore()
        registerBookAndOpen(app: app, title: "潮見町の灯台日誌")

        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["screen_capture_consent_agree"].waitForExistence(timeout: 10))
        app.buttons["screen_capture_consent_agree"].tap()

        XCTAssertTrue(app.staticTexts["reading_guide"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["reading_guide"].label.contains("画面の取り込みを使えない"))
        XCTAssertFalse(app.buttons["reading_end"].exists)
        XCTAssertEqual(app.staticTexts["book_reading_summary"].label, "まだ読んでいません")
        attachScreenshot(app: app, name: "book-reading-start-failure")

        // 同意は済んでいるため、もう一度押した時は同意の説明が出ずに、同じ案内が出る。
        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.staticTexts["reading_guide"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["screen_capture_consent_title"].exists)
        XCTAssertFalse(app.buttons["reading_end"].exists)

        assertSavedReadingSessionCount(app: app, expectedCount: "0")
    }
}
