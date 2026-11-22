import XCTest

/// 購入もトライアルもしていない利用者が無料で始められる読書の回数 (20 回) を、ホームの残りの表示と「読書を始める」の操作で確かめ、
/// 画面のスクリーンショットをテスト結果に添付する UI テスト。
///
/// 画面の取り込みは iOS Simulator で動かないため偽の取り込みに、App Store の商品は取得できないため偽の購入に、開発者メニューで切り替えて確かめる。
/// 20 回の読書を実際に始めずに境界を作るため、無料で始めた読書の回数は開発者メニューで 0 回 → 19 回 → 20 回の順に切り替える。
final class FreeReadingLimitTests: XCTestCase {
    /// 今の画面を `name` の名前でテスト結果に添付する。
    @MainActor
    private func attachScreenshot(app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// `object` (画面の要素か、要素を探す条件) が `predicateFormat` の条件を満たすまで待つ。待ちの上限を過ぎても満たさない時はテストを失敗にする。
    @MainActor
    private func assertEventually(object: NSObject, predicateFormat: String, argument: CVarArg) {
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: predicateFormat, argument), object: object)],
                timeout: sameScreenChangeWaitTimeout
            ),
            .completed,
            "\(object) が \(predicateFormat) (\(argument)) にならなかった"
        )
    }

    /// 開発者メニューの `element` が押せる位置に来るまで、メニューを上へ送る。
    ///
    /// 押せる位置にある時にも送ると、要素がナビゲーションバーの下まで進んで押せないことがあるため、押せない時だけ送る (読書の UI テストと同じ送り方)。
    /// 上限の 8 回は、メニューの section (7 つと、失敗した時だけ出る 1 つ) を 1 回に 1 つずつしか送れなくても、いちばん下まで届く回数。
    @MainActor
    private func scrollDeveloperMenu(app: XCUIApplication, element: XCUIElement) {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: sameScreenChangeWaitTimeout))
    }

    /// 開発者メニューの切り替えのボタン `buttonIdentifier` を `tapCount` 回押し、今の値の行 `stateIdentifier` が `expectedLabel` になるまで待つ。
    @MainActor
    private func cycleDeveloperMenu(app: XCUIApplication, buttonIdentifier: String, stateIdentifier: String, tapCount: Int, expectedLabel: String) {
        // ボタンのすぐ下の今の値の行が画面に入るまで送る (ボタンだけが画面に入った位置で止めると、押した後の値を読めない)。
        scrollDeveloperMenu(app: app, element: app.staticTexts[stateIdentifier])
        for _ in 0..<tapCount {
            app.buttons[buttonIdentifier].tap()
        }
        assertEventually(object: app.staticTexts[stateIdentifier], predicateFormat: "label == %@", argument: expectedLabel)
    }

    /// 開発者メニューを開き、`body` で切り替えてから、ホームに戻る。
    @MainActor
    private func withDeveloperMenu(app: XCUIApplication, body: () -> Void) {
        // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、待ちの上限を長めに取る (ScreenshotTests と同じ値)。
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.buttons["developer_menu_replace_sample_data"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        body()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
    }

    /// ホームの、名前が `title` の本の行を返す。
    @MainActor
    private func bookRow(app: XCUIApplication, title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "book_list_row", title)).firstMatch
    }

    /// ホームから、名前が `title` の本を登録して、ホームにその本の行が出るまで待つ。
    @MainActor
    private func registerBook(app: XCUIApplication, title: String) {
        app.buttons["book_registration_entrance"].tap()
        XCTAssertTrue(app.textFields["book_registration_title_field"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        typeTextAfterKeyboardFocus(element: app.textFields["book_registration_title_field"], text: title)
        app.buttons["book_registration_submit"].tap()
        XCTAssertTrue(bookRow(app: app, title: title).waitForExistence(timeout: sameScreenChangeWaitTimeout))
    }

    /// 読書中の画面で「読書を終える」を押し、問いを返さない偽のクイズの案内から本の画面に戻る。
    @MainActor
    private func endReadingWithoutQuestions(app: XCUIApplication) {
        app.buttons["reading_end"].tap()
        XCTAssertTrue(app.buttons["quiz_leave"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["quiz_leave"].tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
    }

    /// 購入していない利用者は、最初の読書の前にはホームに残りの回数も購入の画面への入口も出ず、読書を 1 回始めると「あと 19 回」と入口が出る。
    /// 19 回始めた後の 20 回目の「読書を始める」は読書を始め、ホームの残りが使い切ったことの文に変わる。
    /// 21 回目の「読書を始める」は読書を始めずに購入の画面を出す。購入の画面で購入して閉じると、読書は自動では始まらず、使い切ったことの案内が消え、
    /// もう一度「読書を始める」を押すと読書が始まる。
    /// 残りの回数と入口が出たホームを `book-list-free-reading-remaining`、使い切った後のホームを `book-list-free-readings-used-up`、
    /// 21 回目に「読書を始める」を押した後の画面を `free-readings-used-up-purchase` の名前で添付する。
    @MainActor
    func test無料で20回始めた後の21回目は購入の画面が出て購入した後にもう一度押すと読書が始まる() {
        let app = launchAppWithInMemoryStore()
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["free_reading_remaining"].exists)
        XCTAssertFalse(app.buttons["purchase_entrance"].exists)
        withDeveloperMenu(app: app) {
            app.buttons["developer_menu_toggle_fake_reading"].tap()
            assertEventually(object: app.staticTexts["developer_menu_uses_fake_reading_state"], predicateFormat: "label == %@", argument: "オン")
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_fake_quiz_behavior",
                stateIdentifier: "developer_menu_fake_quiz_behavior_state",
                tapCount: 2,
                expectedLabel: "問いを返さない"
            )
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_fake_purchase_behavior",
                stateIdentifier: "developer_menu_fake_purchase_behavior_state",
                tapCount: 1,
                expectedLabel: "商品を返す"
            )
        }
        registerBook(app: app, title: "潮見町の灯台日誌")
        XCTAssertFalse(app.staticTexts["free_reading_remaining"].exists)
        XCTAssertFalse(app.buttons["purchase_entrance"].exists)

        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["screen_capture_consent_agree"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["screen_capture_consent_agree"].tap()
        XCTAssertTrue(app.buttons["reading_end"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        endReadingWithoutQuestions(app: app)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["free_reading_remaining"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["free_reading_remaining"].label, "無料で始められる読書 あと 19 回")
        XCTAssertTrue(app.buttons["purchase_entrance"].exists)
        attachScreenshot(app: app, name: "book-list-free-reading-remaining")

        withDeveloperMenu(app: app) {
            // 1 回から 0 回に戻り、次の 1 回で 19 回になる。
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_free_reading_start_count",
                stateIdentifier: "developer_menu_free_reading_start_count_state",
                tapCount: 2,
                expectedLabel: "19 回"
            )
        }
        assertEventually(object: app.staticTexts["free_reading_remaining"], predicateFormat: "label == %@", argument: "無料で始められる読書 あと 1 回")

        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["reading_end"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        endReadingWithoutQuestions(app: app)
        app.navigationBars.buttons.firstMatch.tap()
        assertEventually(object: app.staticTexts["free_reading_remaining"], predicateFormat: "label == %@", argument: "無料で始められる読書を使い切りました")
        XCTAssertTrue(app.buttons["purchase_entrance"].exists)
        attachScreenshot(app: app, name: "book-list-free-readings-used-up")

        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["purchase_button"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.buttons["reading_end"].exists)
        attachScreenshot(app: app, name: "free-readings-used-up-purchase")

        app.buttons["purchase_button"].tap()
        XCTAssertTrue(app.staticTexts["purchase_state_title"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["purchase_close_button"].tap()
        // 購入の画面を閉じても読書は自動では始まらず、使い切ったことの案内が消える。
        assertEventually(object: app.staticTexts["reading_guide"], predicateFormat: "exists == %@", argument: NSNumber(value: false))
        // 購入の画面を閉じた後に購入の状態を確かめてから案内を消すため、閉じた直後に無いだけでは始まらないと言えない。
        // 偽の購入は待たずに状態を返し、始まる時は偽の取り込みがすぐ読書中の画面を出すため、3 秒待っても出なければ始まっていない。
        XCTAssertFalse(app.buttons["reading_end"].waitForExistence(timeout: 3))

        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["reading_end"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        endReadingWithoutQuestions(app: app)
        XCTAssertFalse(app.staticTexts["reading_guide"].exists)
    }

    /// 購入していない利用者が 21 回目の「読書を始める」で出た購入の画面を、購入せずに閉じると、読書は始まらず、
    /// 本の画面に使い切ったことの案内が残る。
    @MainActor
    func test使い切った後に購入せずに購入の画面を閉じると読書は始まらず案内が残る() {
        let app = launchAppWithInMemoryStore()
        withDeveloperMenu(app: app) {
            app.buttons["developer_menu_toggle_fake_reading"].tap()
            assertEventually(object: app.staticTexts["developer_menu_uses_fake_reading_state"], predicateFormat: "label == %@", argument: "オン")
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_fake_purchase_behavior",
                stateIdentifier: "developer_menu_fake_purchase_behavior_state",
                tapCount: 1,
                expectedLabel: "商品を返す"
            )
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_free_reading_start_count",
                stateIdentifier: "developer_menu_free_reading_start_count_state",
                tapCount: 2,
                expectedLabel: "20 回"
            )
        }
        registerBook(app: app, title: "はじめての堆肥づくり")
        bookRow(app: app, title: "はじめての堆肥づくり").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_start"].tap()
        // 初めての読書のため、購入の画面より先に同意の説明が出る。
        XCTAssertTrue(app.buttons["screen_capture_consent_agree"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["screen_capture_consent_agree"].tap()
        XCTAssertTrue(app.buttons["purchase_close_button"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.buttons["reading_end"].exists)

        app.buttons["purchase_close_button"].tap()
        assertEventually(object: app.buttons["purchase_close_button"], predicateFormat: "exists == %@", argument: NSNumber(value: false))
        XCTAssertTrue(app.staticTexts["reading_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["reading_guide"].label.contains("無料で始められる読書を使い切りました"))
        XCTAssertTrue(app.staticTexts["reading_guide"].label.contains("続けて読むには購入のプランを選んでください"))
        // 購入の画面を閉じた後に購入の状態を確かめてから始めるかを決めるため、閉じた直後に無いだけでは始まらないと言えない。
        // 偽の購入は待たずに状態を返し、始まる時は偽の取り込みがすぐ読書中の画面を出すため、3 秒待っても出なければ始まっていない。
        XCTAssertFalse(app.buttons["reading_end"].waitForExistence(timeout: 3))
    }

    /// 購入していない利用者が読書を 1 回始めた後にトライアルを始めると、ホームの残りの回数と購入の画面への入口が消える
    /// (開発者メニューで偽の購入を「トライアル中」に変えてホームに戻った時に、購入の状態を確かめ直す)。
    /// トライアル中の利用者は、無料の回数を使い切っていても、購入の画面を出さずに読書を始められる。
    @MainActor
    func testトライアル中は使い切っていても購入の画面を出さずに読書が始まる() {
        let app = launchAppWithInMemoryStore()
        withDeveloperMenu(app: app) {
            app.buttons["developer_menu_toggle_fake_reading"].tap()
            assertEventually(object: app.staticTexts["developer_menu_uses_fake_reading_state"], predicateFormat: "label == %@", argument: "オン")
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_fake_quiz_behavior",
                stateIdentifier: "developer_menu_fake_quiz_behavior_state",
                tapCount: 2,
                expectedLabel: "問いを返さない"
            )
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_fake_purchase_behavior",
                stateIdentifier: "developer_menu_fake_purchase_behavior_state",
                tapCount: 1,
                expectedLabel: "商品を返す"
            )
        }
        registerBook(app: app, title: "潮見町の灯台日誌")
        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["screen_capture_consent_agree"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["screen_capture_consent_agree"].tap()
        XCTAssertTrue(app.buttons["reading_end"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        endReadingWithoutQuestions(app: app)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["free_reading_remaining"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.buttons["purchase_entrance"].exists)

        withDeveloperMenu(app: app) {
            // 商品を返す → 商品を取得できない → トライアル中
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_fake_purchase_behavior",
                stateIdentifier: "developer_menu_fake_purchase_behavior_state",
                tapCount: 2,
                expectedLabel: "トライアル中"
            )
            // 1 回 → 0 回 → 19 回 → 20 回
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_free_reading_start_count",
                stateIdentifier: "developer_menu_free_reading_start_count_state",
                tapCount: 3,
                expectedLabel: "20 回"
            )
        }
        assertEventually(object: app.buttons["purchase_entrance"], predicateFormat: "exists == %@", argument: NSNumber(value: false))
        XCTAssertFalse(app.staticTexts["free_reading_remaining"].exists)

        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["reading_end"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.buttons["purchase_close_button"].exists)
        endReadingWithoutQuestions(app: app)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(bookRow(app: app, title: "潮見町の灯台日誌").waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.staticTexts["free_reading_remaining"].exists)
        XCTAssertFalse(app.buttons["purchase_entrance"].exists)
    }

    /// 購入していない利用者が無料の回数を使い切っていても、本の登録・出題の設定・履歴の閲覧・「もう一度答える」・読書の記録と本の削除は、
    /// 購入の画面を出さずに使える。本を消した後も、ホームの残りは使い切ったままで増えない。
    /// 開発者メニューの「保存データを全部消す」の後も無料で始めた読書の回数は 20 回のままで、新しく登録した本の「読書を始める」で購入の画面が出る。
    @MainActor
    func test使い切った後も読書を始める以外の操作は購入の画面を出さずに使える() {
        let app = launchAppWithInMemoryStore()
        withDeveloperMenu(app: app) {
            app.buttons["developer_menu_replace_sample_data"].tap()
            assertEventually(object: app.staticTexts["developer_menu_answer_count"], predicateFormat: "label == %@", argument: "7")
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_fake_quiz_behavior",
                stateIdentifier: "developer_menu_fake_quiz_behavior_state",
                tapCount: 1,
                expectedLabel: "問いを返す"
            )
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_fake_purchase_behavior",
                stateIdentifier: "developer_menu_fake_purchase_behavior_state",
                tapCount: 1,
                expectedLabel: "商品を返す"
            )
            cycleDeveloperMenu(
                app: app,
                buttonIdentifier: "developer_menu_cycle_free_reading_start_count",
                stateIdentifier: "developer_menu_free_reading_start_count_state",
                tapCount: 2,
                expectedLabel: "20 回"
            )
        }
        assertEventually(object: app.staticTexts["free_reading_remaining"], predicateFormat: "label == %@", argument: "無料で始められる読書を使い切りました")

        registerBook(app: app, title: "海辺の天気図")

        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["question_settings_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["question_settings_entrance"].tap()
        XCTAssertTrue(app.buttons["question_settings_cancel"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["question_settings_cancel"].tap()
        XCTAssertTrue(app.buttons["history_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["history_entrance"].tap()
        XCTAssertTrue(app.staticTexts["history_book_title"].waitForExistence(timeout: sameScreenChangeWaitTimeout))

        app.buttons.matching(identifier: "history_reanswer").element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["quiz_question_text"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.buttons["purchase_close_button"].exists)
        app.buttons["quiz_leave"].tap()
        XCTAssertTrue(app.buttons["history_book_delete"].waitForExistence(timeout: sameScreenChangeWaitTimeout))

        app.buttons.matching(identifier: "history_reading_session").element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["reading_session_delete"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_session_delete"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.alerts.buttons["消す"].tap()
        XCTAssertTrue(app.buttons["history_book_delete"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        assertEventually(object: app.buttons.matching(identifier: "history_reading_session"), predicateFormat: "count == %d", argument: 1)

        app.buttons["history_book_delete"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.alerts.buttons["消す"].tap()
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        assertEventually(object: bookRow(app: app, title: "潮見町の灯台日誌"), predicateFormat: "exists == %@", argument: NSNumber(value: false))
        XCTAssertFalse(app.buttons["purchase_close_button"].exists)
        XCTAssertEqual(app.staticTexts["free_reading_remaining"].label, "無料で始められる読書を使い切りました")

        withDeveloperMenu(app: app) {
            app.buttons["developer_menu_delete_all_saved_data"].tap()
            assertEventually(object: app.staticTexts["developer_menu_book_count"], predicateFormat: "label == %@", argument: "0")
            scrollDeveloperMenu(app: app, element: app.staticTexts["developer_menu_free_reading_start_count_state"])
            XCTAssertEqual(app.staticTexts["developer_menu_free_reading_start_count_state"].label, "20 回")
        }
        registerBook(app: app, title: "海辺の天気図")
        bookRow(app: app, title: "海辺の天気図").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_start"].tap()
        // 初めての読書のため、購入の画面より先に同意の説明が出る。
        XCTAssertTrue(app.buttons["screen_capture_consent_agree"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["screen_capture_consent_agree"].tap()
        XCTAssertTrue(app.buttons["purchase_close_button"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
    }
}
