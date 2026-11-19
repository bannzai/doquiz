import XCTest

/// 読む本を選ぶ画面・本の登録・本の画面・出題の設定を操作して確かめ、画面のスクリーンショットをテスト結果に添付する UI テスト。
///
/// 添付した画像は、CI の artifact `screenshots` から取り出して見た目を確かめるのに使う。
final class ScreenshotTests: XCTestCase {
    /// 今の画面を `name` の名前でテスト結果に添付する。
    @MainActor
    private func attachScreenshot(app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// `element` が画面から無くなるまで待つ。待ちの上限を過ぎても残っている時はテストを失敗にする。
    @MainActor
    private func assertDisappears(element: XCUIElement) {
        // 上限の 10 秒は、起動の待ち (30 秒) と違い、同じ画面の中の表示の更新だけを待つため短くしている (DeveloperMenuTests と同じ値)。
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)],
                timeout: 10
            ),
            .completed,
            "\(element) が画面に残っている"
        )
    }

    /// 一覧の行のうち、名前が `title` の本の行を返す。
    @MainActor
    private func bookRow(app: XCUIApplication, title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "book_list_row", title))
            .firstMatch
    }

    /// 起動直後の一覧から、名前が `title` の本を登録して、一覧にその本の行が出るまで待つ。
    @MainActor
    private func registerBook(app: XCUIApplication, title: String) {
        // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、待ちの上限を長めに取る。
        // CI の実測 (https://github.com/bannzai/doquiz/actions/runs/43983732332) では、起動を含むテスト全体が 57 秒で、この上限の中で表示された。
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: 30))
        app.buttons["book_registration_entrance"].tap()
        XCTAssertTrue(app.textFields["book_registration_title_field"].waitForExistence(timeout: 10))
        app.textFields["book_registration_title_field"].tap()
        app.textFields["book_registration_title_field"].typeText(title)
        app.buttons["book_registration_submit"].tap()
        XCTAssertTrue(bookRow(app: app, title: title).waitForExistence(timeout: 10))
    }

    /// 名前が `title` の本を登録し、その本の画面から出題の設定を開いて、保存のボタンが出るまで待つ。
    @MainActor
    private func registerBookAndOpenQuestionSettings(app: XCUIApplication, title: String) {
        registerBook(app: app, title: title)
        bookRow(app: app, title: title).tap()
        openQuestionSettings(app: app)
    }

    /// 本の画面から出題の設定を開いて、保存のボタンが出るまで待つ。
    @MainActor
    private func openQuestionSettings(app: XCUIApplication) {
        XCTAssertTrue(app.buttons["question_settings_entrance"].waitForExistence(timeout: 10))
        app.buttons["question_settings_entrance"].tap()
        XCTAssertTrue(app.buttons["question_settings_save"].waitForExistence(timeout: 10))
    }

    /// 出題の設定の画面の、出題への希望の入力欄を返す。
    @MainActor
    private func questionGuidanceField(app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "question_settings_guidance_field").firstMatch
    }

    /// 出題の設定の画面で、問いの種類が選ばれているかを、四択・要約の正誤・穴埋め・記述の順に返す。
    @MainActor
    private func selectedQuestionKinds(app: XCUIApplication) -> [Bool] {
        [
            "question_settings_kind_comprehension",
            "question_settings_kind_summaryTrueFalse",
            "question_settings_kind_fillInTheBlank",
            "question_settings_kind_written",
        ].map { app.buttons[$0].isSelected }
    }

    /// 本が 1 冊も無い状態で開くと、本が無いことの案内と、最初の本を登録する入口が出て、本の行は出ないことを確かめ、
    /// その画面を `book-list-empty` の名前で添付する。
    @MainActor
    func test本が1冊も無い状態で開くと最初の本を登録する導線が出る() {
        let app = launchAppWithInMemoryStore()

        XCTAssertTrue(app.staticTexts["book_list_empty_guide"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.buttons["book_registration_entrance"].label, "最初の本を登録する")
        XCTAssertFalse(app.buttons["book_list_row"].exists)
        attachScreenshot(app: app, name: "book-list-empty")
    }

    /// 名前を入れて登録すると、一覧にその本の行が出て、本が無いことの案内が消え、登録の入口の文言が「新しい本を登録する」に変わることを確かめる。
    /// 名前を入れた登録の画面を `book-registration`、登録した後の一覧を `book-list` の名前で添付する。
    @MainActor
    func test名前を入れて登録すると一覧にその本が出る() {
        let app = launchAppWithInMemoryStore()
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: 30))
        app.buttons["book_registration_entrance"].tap()
        XCTAssertTrue(app.textFields["book_registration_title_field"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["book_registration_submit"].isEnabled)

        app.textFields["book_registration_title_field"].tap()
        app.textFields["book_registration_title_field"].typeText("潮見町の灯台日誌")
        XCTAssertTrue(app.buttons["book_registration_submit"].isEnabled)
        attachScreenshot(app: app, name: "book-registration")
        app.buttons["book_registration_submit"].tap()

        XCTAssertTrue(bookRow(app: app, title: "潮見町の灯台日誌").waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "book_list_row").count, 1)
        XCTAssertFalse(app.staticTexts["book_list_empty_guide"].exists)
        XCTAssertEqual(app.buttons["book_registration_entrance"].label, "新しい本を登録する")
        attachScreenshot(app: app, name: "book-list")
    }

    /// 登録の画面でキャンセルすると、名前を入れていても本が登録されず、本が無いことの案内が出たままであることを確かめる。
    @MainActor
    func test登録をキャンセルすると本は登録されない() {
        let app = launchAppWithInMemoryStore()
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: 30))
        app.buttons["book_registration_entrance"].tap()
        XCTAssertTrue(app.textFields["book_registration_title_field"].waitForExistence(timeout: 10))
        app.textFields["book_registration_title_field"].tap()
        app.textFields["book_registration_title_field"].typeText("登録しない本")

        app.buttons["book_registration_cancel"].tap()

        assertDisappears(element: app.buttons["book_registration_cancel"])
        XCTAssertTrue(app.staticTexts["book_list_empty_guide"].exists)
        XCTAssertFalse(app.buttons["book_list_row"].exists)
    }

    /// 本を選ぶと本の画面にその本の名前が出て、出題の設定を開くと新しい本は 4 種類とも選ばれていることを確かめる。
    /// 問いの種類を 1 つ (記述) 外して希望の文を入れて保存すると、開き直しても同じ内容が出ることを確かめる。
    /// 本の画面を `book`、変えた後の出題の設定の画面を `question-settings` の名前で添付する。
    @MainActor
    func test出題の設定を変えて保存すると開き直しても同じ内容が出る() {
        let app = launchAppWithInMemoryStore()
        registerBook(app: app, title: "潮見町の灯台日誌")
        bookRow(app: app, title: "潮見町の灯台日誌").tap()
        XCTAssertTrue(app.buttons["question_settings_entrance"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["book_title"].label, "潮見町の灯台日誌")
        attachScreenshot(app: app, name: "book")
        openQuestionSettings(app: app)
        XCTAssertEqual(selectedQuestionKinds(app: app), [true, true, true, true])

        app.buttons["question_settings_kind_written"].tap()
        questionGuidanceField(app: app).tap()
        questionGuidanceField(app: app).typeText("人物の行動の理由を中心に")
        attachScreenshot(app: app, name: "question-settings")
        app.buttons["question_settings_save"].tap()
        assertDisappears(element: app.buttons["question_settings_save"])

        openQuestionSettings(app: app)
        XCTAssertEqual(selectedQuestionKinds(app: app), [true, true, true, false])
        XCTAssertEqual(questionGuidanceField(app: app).value as? String, "人物の行動の理由を中心に")
    }

    /// 出題の設定を変えてからキャンセルすると、開き直した時に変える前の内容 (4 種類とも選ばれている) が出ることを確かめる。
    @MainActor
    func test出題の設定をキャンセルすると変える前の内容のままになる() {
        let app = launchAppWithInMemoryStore()
        registerBookAndOpenQuestionSettings(app: app, title: "はじめての堆肥づくり")

        app.buttons["question_settings_kind_comprehension"].tap()
        XCTAssertEqual(selectedQuestionKinds(app: app), [false, true, true, true])
        app.buttons["question_settings_cancel"].tap()
        assertDisappears(element: app.buttons["question_settings_cancel"])

        openQuestionSettings(app: app)
        XCTAssertEqual(selectedQuestionKinds(app: app), [true, true, true, true])
    }

    /// 問いの種類を 4 種類とも外すと、保存のボタンが押せなくなって 1 つ以上選ぶ案内が出て、1 つ選び直すと保存のボタンが押せて案内が消えることを確かめる。
    @MainActor
    func test問いの種類を1つも選んでいないと保存できない() {
        let app = launchAppWithInMemoryStore()
        registerBookAndOpenQuestionSettings(app: app, title: "はじめての堆肥づくり")
        XCTAssertTrue(app.buttons["question_settings_save"].isEnabled)
        XCTAssertFalse(app.staticTexts["question_settings_no_kind_guide"].exists)

        app.buttons["question_settings_kind_comprehension"].tap()
        app.buttons["question_settings_kind_summaryTrueFalse"].tap()
        app.buttons["question_settings_kind_fillInTheBlank"].tap()
        XCTAssertTrue(app.buttons["question_settings_save"].isEnabled)
        app.buttons["question_settings_kind_written"].tap()

        XCTAssertEqual(selectedQuestionKinds(app: app), [false, false, false, false])
        XCTAssertFalse(app.buttons["question_settings_save"].isEnabled)
        XCTAssertTrue(app.staticTexts["question_settings_no_kind_guide"].exists)

        app.buttons["question_settings_kind_fillInTheBlank"].tap()
        XCTAssertEqual(selectedQuestionKinds(app: app), [false, false, true, false])
        XCTAssertTrue(app.buttons["question_settings_save"].isEnabled)
        XCTAssertFalse(app.staticTexts["question_settings_no_kind_guide"].exists)
    }

    /// 開発者メニューで見本のデータを入れて一覧に戻ると、見本の本 2 冊が登録の新しい順に並び、読書の記録がある本の行に読書の回数が出ることを確かめ、
    /// その一覧を `book-list-with-readings` の名前で添付する。
    @MainActor
    func test見本のデータを入れると一覧に読書の回数が出る() {
        let app = launchAppWithInMemoryStore()
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.buttons["developer_menu_replace_sample_data"].waitForExistence(timeout: 10))
        app.buttons["developer_menu_replace_sample_data"].tap()
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(bookRow(app: app, title: "潮見町の灯台日誌").waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "book_list_row").count, 2)
        XCTAssertTrue(app.buttons.matching(identifier: "book_list_row").element(boundBy: 0).label.contains("はじめての堆肥づくり"))
        XCTAssertTrue(bookRow(app: app, title: "潮見町の灯台日誌").label.contains("読書 2 回"))
        XCTAssertTrue(bookRow(app: app, title: "はじめての堆肥づくり").label.contains("読書 1 回"))
        attachScreenshot(app: app, name: "book-list-with-readings")
    }
}
