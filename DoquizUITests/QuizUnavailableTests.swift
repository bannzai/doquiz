import XCTest

/// 端末内のモデルが使えない時に、本の一覧と本の画面に案内が出て「読書を始める」を押せないことを操作して確かめ、
/// 案内の出た画面のスクリーンショットをテスト結果に添付する UI テスト。
///
/// 使えない状態は、対応していない端末か設定を切った実機でしか作れないため、開発者メニューで偽の値に切り替えて確かめる。
/// UI テストの起動は、偽の「使える」から始まる。
final class QuizUnavailableTests: XCTestCase {
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
    private func assertEventually(element: XCUIElement, predicateFormat: String) {
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: predicateFormat), object: element)],
                timeout: sameScreenChangeWaitTimeout
            ),
            .completed,
            "\(element) が \(predicateFormat) にならなかった"
        )
    }

    /// ホーム画面へ出てからアプリに戻る (ほかのアプリから戻ってきた時に当たる)。
    @MainActor
    private func leaveAndReturn(app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: sameScreenChangeWaitTimeout))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: sameScreenChangeWaitTimeout))
    }

    /// 一覧から開発者メニューを開き、端末内のモデルが使えるかを `quizAvailability` (開発者メニューの確かめ方の名前) に切り替えて、一覧に戻る。
    /// 切り替えた値は、アプリが次に確かめるまで画面に出ない。
    @MainActor
    private func switchQuizAvailability(app: XCUIApplication, quizAvailability: String) {
        // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、待ちの上限を長めに取る (ScreenshotTests と同じ値)。
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.buttons["developer_menu_replace_sample_data"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        let quizAvailabilityButton = app.buttons["developer_menu_quiz_availability_\(quizAvailability)"]
        // 切り替えのボタンはメニューのいちばん下にあり、画面に入っていない間は要素が無いため、押せる位置に来るまで上へ送る。
        // 上限の 5 回は、メニューの 5 つの section を 1 回に 1 つずつしか送れなくても、いちばん下まで届く回数。
        for _ in 0..<5 where !(quizAvailabilityButton.exists && quizAvailabilityButton.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(quizAvailabilityButton.waitForExistence(timeout: sameScreenChangeWaitTimeout))
        quizAvailabilityButton.tap()
        assertEventually(element: quizAvailabilityButton, predicateFormat: "isSelected == true")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
    }

    /// 起動直後の一覧から、名前が `title` の本を登録して、一覧にその本の行が出るまで待つ。
    @MainActor
    private func registerBook(app: XCUIApplication, title: String) {
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: 30))
        app.buttons["book_registration_entrance"].tap()
        XCTAssertTrue(app.textFields["book_registration_title_field"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        typeTextAfterKeyboardFocus(element: app.textFields["book_registration_title_field"], text: title)
        app.buttons["book_registration_submit"].tap()
        XCTAssertTrue(bookRow(app: app, title: title).waitForExistence(timeout: sameScreenChangeWaitTimeout))
    }

    /// 一覧の行のうち、名前が `title` の本の行を返す。
    @MainActor
    private func bookRow(app: XCUIApplication, title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "book_list_row", title)).firstMatch
    }

    /// 使える状態で開くと、本の一覧と本の画面に案内が出ず、「読書を始める」を押せる。
    /// 使えない状態 (Apple Intelligence がオフ) にすると、本の一覧と本の画面に、クイズを出せないことと理由と直し方の案内が出て、
    /// 「読書を始める」を押せず、押しても同意の説明が出ない。出題の設定の入口は押せるままである。
    /// 使える状態に戻すと、案内が消えて「読書を始める」を押せ、押すと同意の説明が出る。
    /// 使えない状態への切り替えは、ほかのアプリから戻ってきた時に初めて画面に出る (戻る前は案内が出ない)。
    /// 使える状態への切り替えは、アプリを開いたままでも画面に出る (使えない間は確かめ直しているため)。
    /// 案内の出た本の一覧を `book-list-quiz-unavailable`、本の画面を `book-quiz-unavailable` の名前で添付する。
    @MainActor
    func test使えない間は案内が出て読書を始められず使えるようになると始められる() {
        let app = launchAppWithInMemoryStore()
        registerBook(app: app, title: "潮見町の灯台日誌")
        XCTAssertFalse(app.staticTexts["quiz_unavailable_guide"].exists)
        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.buttons["reading_start"].isEnabled)
        XCTAssertFalse(app.staticTexts["quiz_unavailable_guide"].exists)
        app.navigationBars.buttons.firstMatch.tap()

        switchQuizAvailability(app: app, quizAvailability: "appleIntelligenceNotEnabled")
        XCTAssertFalse(app.staticTexts["quiz_unavailable_guide"].exists)
        leaveAndReturn(app: app)

        XCTAssertTrue(app.staticTexts["quiz_unavailable_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["quiz_unavailable_guide"].label.contains("クイズを出せません"))
        XCTAssertTrue(app.staticTexts["quiz_unavailable_guide"].label.contains("Apple Intelligence がオフになっています"))
        XCTAssertTrue(app.staticTexts["quiz_unavailable_guide"].label.contains("設定アプリで Apple Intelligence をオンにする"))
        attachScreenshot(app: app, name: "book-list-quiz-unavailable")

        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["quiz_unavailable_guide"].label.contains("Apple Intelligence がオフになっています"))
        XCTAssertFalse(app.buttons["reading_start"].isEnabled)
        XCTAssertTrue(app.buttons["question_settings_entrance"].isEnabled)
        attachScreenshot(app: app, name: "book-quiz-unavailable")
        app.buttons["reading_start"].tap()
        XCTAssertFalse(app.staticTexts["screen_capture_consent_title"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()

        switchQuizAvailability(app: app, quizAvailability: "available")

        assertEventually(element: app.staticTexts["quiz_unavailable_guide"], predicateFormat: "exists == false")
        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.staticTexts["quiz_unavailable_guide"].exists)
        XCTAssertTrue(app.buttons["reading_start"].isEnabled)
        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.staticTexts["screen_capture_consent_title"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
    }

    /// 使えない理由が違うと、本の一覧と本の画面に出る案内の文が変わり、どの理由でも「読書を始める」を押せない。
    /// 端末が対応していない時の本の画面を `book-quiz-unavailable-device-not-eligible`、
    /// モデルの準備中の時の本の画面を `book-quiz-unavailable-model-not-ready` の名前で添付する。
    @MainActor
    func test使えない理由ごとに案内の文が変わる() {
        let app = launchAppWithInMemoryStore()
        registerBook(app: app, title: "潮見町の灯台日誌")

        for (quizAvailability, guidePart, screenshotName) in [
            ("deviceNotEligible", "この iPhone が対応していない", "book-quiz-unavailable-device-not-eligible"),
            ("modelNotReady", "クイズを作るモデルを iPhone が準備しています", "book-quiz-unavailable-model-not-ready"),
        ] {
            switchQuizAvailability(app: app, quizAvailability: quizAvailability)
            leaveAndReturn(app: app)

            assertEventually(element: app.staticTexts["quiz_unavailable_guide"], predicateFormat: "label CONTAINS '\(guidePart)'")
            bookRow(app: app, title: "潮見町の灯台日誌").tap()
            XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
            XCTAssertTrue(app.staticTexts["quiz_unavailable_guide"].label.contains(guidePart))
            XCTAssertFalse(app.buttons["reading_start"].isEnabled)
            attachScreenshot(app: app, name: screenshotName)
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    /// 使える状態で「読書を始める」を押して同意の説明を出し、その間に使えなくなった時は、同意の説明が閉じて読書が始まらない。
    /// 読書を始めようとした時に出る案内 (iOS Simulator では画面の取り込みを使えない案内) が出ず、
    /// 使えない時の案内が出て「読書を始める」を押せない。
    @MainActor
    func test同意の説明を出している間に使えなくなると説明が閉じて読書が始まらない() {
        let app = launchAppWithInMemoryStore()
        registerBook(app: app, title: "潮見町の灯台日誌")
        switchQuizAvailability(app: app, quizAvailability: "appleIntelligenceNotEnabled")
        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.buttons["reading_start"].isEnabled)
        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["screen_capture_consent_agree"].waitForExistence(timeout: sameScreenChangeWaitTimeout))

        leaveAndReturn(app: app)

        assertEventually(element: app.buttons["screen_capture_consent_agree"], predicateFormat: "exists == false")
        XCTAssertTrue(app.staticTexts["quiz_unavailable_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.staticTexts["reading_guide"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reading_start"].isEnabled)
    }
}
