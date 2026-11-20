import XCTest

/// 読書を終えた後のクイズの画面を操作して確かめ、画面のスクリーンショットをテスト結果に添付する UI テスト。
///
/// 画面の取り込みと端末内のモデルは iOS Simulator で確かめられないため、開発者メニューで偽の取り込みと偽のクイズに切り替えて確かめる。
final class QuizTests: XCTestCase {
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
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: predicateFormat, argument), object: element)],
                timeout: sameScreenChangeWaitTimeout
            ),
            .completed,
            "\(element) が \(predicateFormat) (\(argument)) にならなかった (表示: \(element.exists ? element.label : "要素が無い"))"
        )
    }

    /// 起動直後の一覧から、読書を偽の取り込みに、クイズを偽のクイズに切り替え、
    /// 名前が「潮見町の灯台日誌」の本を登録して読書を始め、「読書を終える」を押す。
    ///
    /// クイズの切り替えは `fakeQuizBehaviorTapCount` 回押し、押した後の表示が `fakeQuizBehaviorLabel` であることを確かめる。
    @MainActor
    private func endReadingWithFakeQuiz(app: XCUIApplication, fakeQuizBehaviorTapCount: Int, fakeQuizBehaviorLabel: String) {
        // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、待ちの上限を長めに取る (ScreenshotTests と同じ値)。
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.buttons["developer_menu_toggle_fake_reading"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["developer_menu_toggle_fake_reading"].tap()
        assertEventually(element: app.staticTexts["developer_menu_uses_fake_reading_state"], predicateFormat: "label == %@", argument: "オン")
        // クイズの切り替えは一覧の下にあり、画面に入っていないことがあるため、上へ送ってから押す。
        app.swipeUp()
        XCTAssertTrue(app.buttons["developer_menu_cycle_fake_quiz_behavior"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["developer_menu_fake_quiz_behavior_state"].label, "実物")
        for _ in 0..<fakeQuizBehaviorTapCount {
            app.buttons["developer_menu_cycle_fake_quiz_behavior"].tap()
        }
        assertEventually(element: app.staticTexts["developer_menu_fake_quiz_behavior_state"], predicateFormat: "label == %@", argument: fakeQuizBehaviorLabel)
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["book_registration_entrance"].tap()
        XCTAssertTrue(app.textFields["book_registration_title_field"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.textFields["book_registration_title_field"].tap()
        typeAfterKeyboardFocus(element: app.textFields["book_registration_title_field"], text: "潮見町の灯台日誌")
        app.buttons["book_registration_submit"].tap()
        XCTAssertTrue(app.buttons["book_list_row"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["book_list_row"].tap()
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_start"].tap()
        XCTAssertTrue(app.buttons["screen_capture_consent_agree"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["screen_capture_consent_agree"].tap()
        XCTAssertTrue(app.buttons["reading_end"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["reading_end"].tap()
    }

    /// 押した後の入力欄 `element` にキーボードの入力先が移るまで待ってから、`text` を打つ。
    ///
    /// 押した直後は入力欄にまだキーボードの入力先が移っていないことがあり、そのまま打つと失敗するため。
    @MainActor
    private func typeAfterKeyboardFocus(element: XCUIElement, text: String) {
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element)],
                timeout: sameScreenChangeWaitTimeout
            ),
            .completed,
            "\(element) にキーボードの入力先が移らなかった"
        )
        element.typeText(text)
    }

    /// クイズの答えの入力欄を返す。行が増える入力欄は、行の数によって要素の種類が変わることがあるため、種類を問わずに識別子で探す。
    @MainActor
    private func answerField(app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "quiz_answer_field").firstMatch
    }

    /// クイズを終えて本の画面に戻った後、一覧に戻って開発者メニューを開き、保存されている問いと回答の件数が `expectedQuestionCount`・`expectedAnswerCount` になるまで待つ。
    @MainActor
    private func assertSavedCounts(app: XCUIApplication, expectedQuestionCount: String, expectedAnswerCount: String) {
        XCTAssertTrue(app.buttons["reading_start"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.staticTexts["developer_menu_question_count"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        assertEventually(element: app.staticTexts["developer_menu_question_count"], predicateFormat: "label == %@", argument: expectedQuestionCount)
        assertEventually(element: app.staticTexts["developer_menu_answer_count"], predicateFormat: "label == %@", argument: expectedAnswerCount)
    }

    /// 読書を終えると、問いを作っている間の表示が出た後、4 種類の問いが 1 問ずつ出る。答えるたびに判定・模範の答え・根拠にした本文の引用が出て、
    /// 「次の問いへ」で次の問いに進み、最後の問いの後は本の画面に戻り、問い 4 件と回答 4 件が保存されている。
    /// 四択は合っている選択肢、要約の正誤は合っていない選択肢、穴埋めは模範の答えと同じ答え、記述は模範の答えと違う答えで答える。
    /// 問いを作っている間を `quiz-preparing`、種類ごとの答える前を `quiz-<種類>`、答えた後を `quiz-<種類>-answered` の名前で添付する。
    @MainActor
    func test4種類の問いに1問ずつ答えると判定と模範の答えと根拠が出て本の画面に戻る() {
        let app = launchAppWithInMemoryStore()
        endReadingWithFakeQuiz(app: app, fakeQuizBehaviorTapCount: 1, fakeQuizBehaviorLabel: "問いを返す")

        XCTAssertTrue(app.staticTexts["quiz_preparing"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.staticTexts["quiz_position"].exists)
        attachScreenshot(app: app, name: "quiz-preparing")

        XCTAssertTrue(app.staticTexts["quiz_position"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["quiz_position"].label, "問い 1 / 4")
        XCTAssertEqual(app.staticTexts["quiz_kind"].label, "四択")
        XCTAssertEqual(app.staticTexts["quiz_question_text"].label, "灯台守が毎朝 日誌に書きとめたものは何か")
        XCTAssertEqual(app.buttons["quiz_choice_1"].label, "霧の濃さ")
        XCTAssertTrue(app.buttons["quiz_choice_3"].exists)
        XCTAssertFalse(app.staticTexts["quiz_judgement"].exists)
        XCTAssertFalse(app.buttons["quiz_next"].exists)
        attachScreenshot(app: app, name: "quiz-comprehension")
        app.buttons["quiz_choice_1"].tap()
        XCTAssertTrue(app.staticTexts["quiz_judgement"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["quiz_judgement"].label, "合っています")
        XCTAssertFalse(app.staticTexts["quiz_judgement_caution"].exists)
        XCTAssertEqual(app.staticTexts["quiz_model_answer"].label, "霧の濃さ")
        XCTAssertTrue(app.staticTexts["quiz_evidence_quote"].label.contains("灯台守"))
        XCTAssertEqual(app.buttons["quiz_next"].label, "次の問いへ")
        attachScreenshot(app: app, name: "quiz-comprehension-answered")

        app.buttons["quiz_next"].tap()
        assertEventually(element: app.staticTexts["quiz_position"], predicateFormat: "label == %@", argument: "問い 2 / 4")
        XCTAssertEqual(app.staticTexts["quiz_kind"].label, "要約の正誤")
        XCTAssertFalse(app.staticTexts["quiz_judgement"].exists)
        XCTAssertEqual(app.buttons["quiz_choice_0"].label, "正しい")
        XCTAssertEqual(app.buttons["quiz_choice_1"].label, "誤り")
        XCTAssertFalse(app.buttons["quiz_choice_2"].exists)
        attachScreenshot(app: app, name: "quiz-summary-true-false")
        app.buttons["quiz_choice_0"].tap()
        XCTAssertTrue(app.staticTexts["quiz_judgement"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["quiz_judgement"].label, "合っていません")
        XCTAssertEqual(app.staticTexts["quiz_model_answer"].label, "誤り")
        XCTAssertTrue(app.staticTexts["quiz_evidence_quote"].label.contains("灯台守"))
        attachScreenshot(app: app, name: "quiz-summary-true-false-answered")

        app.buttons["quiz_next"].tap()
        assertEventually(element: app.staticTexts["quiz_position"], predicateFormat: "label == %@", argument: "問い 3 / 4")
        XCTAssertEqual(app.staticTexts["quiz_kind"].label, "穴埋め")
        XCTAssertFalse(app.buttons["quiz_choice_0"].exists)
        XCTAssertFalse(app.buttons["quiz_answer_submit"].isEnabled)
        attachScreenshot(app: app, name: "quiz-fill-in-the-blank")
        answerField(app: app).tap()
        // 空白だけの答えでは「答える」を押せない。その後に打った答えは、前の空白を除いて判定される (偽のクイズは模範の答えと同じ文字列かで判定する)。
        typeAfterKeyboardFocus(element: answerField(app: app), text: " ")
        XCTAssertFalse(app.buttons["quiz_answer_submit"].isEnabled)
        answerField(app: app).typeText("霧")
        XCTAssertTrue(app.buttons["quiz_answer_submit"].isEnabled)
        app.buttons["quiz_answer_submit"].tap()
        XCTAssertTrue(app.staticTexts["quiz_judgement"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["quiz_judgement"].label, "合っていそうです")
        XCTAssertTrue(app.staticTexts["quiz_judgement_caution"].label.contains("間違うことがあります"))
        XCTAssertEqual(app.staticTexts["quiz_model_answer"].label, "霧")
        XCTAssertTrue(app.staticTexts["quiz_evidence_quote"].label.contains("灯台守"))
        attachScreenshot(app: app, name: "quiz-fill-in-the-blank-answered")

        app.buttons["quiz_next"].tap()
        assertEventually(element: app.staticTexts["quiz_position"], predicateFormat: "label == %@", argument: "問い 4 / 4")
        XCTAssertEqual(app.staticTexts["quiz_kind"].label, "記述")
        attachScreenshot(app: app, name: "quiz-written")
        answerField(app: app).tap()
        typeAfterKeyboardFocus(element: answerField(app: app), text: "海を見ていた")
        app.buttons["quiz_answer_submit"].tap()
        XCTAssertTrue(app.staticTexts["quiz_judgement"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["quiz_judgement"].label, "合っていないかもしれません")
        XCTAssertTrue(app.staticTexts["quiz_judgement_caution"].label.contains("間違うことがあります"))
        XCTAssertEqual(app.staticTexts["quiz_model_answer"].label, "霧の濃さを日誌に書きとめていた")
        XCTAssertTrue(app.staticTexts["quiz_evidence_quote"].label.contains("灯台守"))
        XCTAssertEqual(app.buttons["quiz_next"].label, "クイズを終える")
        attachScreenshot(app: app, name: "quiz-written-answered")

        app.buttons["quiz_next"].tap()
        assertSavedCounts(app: app, expectedQuestionCount: "4", expectedAnswerCount: "4")
    }

    /// 問いが 1 問も返らなかった時は、問いを出さずにクイズが無いことの案内が出て、「もう一度作る」は出ず、「本の画面に戻る」で本の画面に戻る。問いと回答は保存されない。
    /// 案内の出た画面を `quiz-no-questions` の名前で添付する。
    @MainActor
    func test問いが1問も無い時は案内が出て本の画面に戻れる() {
        let app = launchAppWithInMemoryStore()
        endReadingWithFakeQuiz(app: app, fakeQuizBehaviorTapCount: 2, fakeQuizBehaviorLabel: "問いを返さない")

        XCTAssertTrue(app.staticTexts["quiz_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["quiz_guide"].label.contains("今回の読書のクイズはありません"))
        XCTAssertFalse(app.staticTexts["quiz_position"].exists)
        XCTAssertFalse(app.buttons["quiz_retry"].exists)
        attachScreenshot(app: app, name: "quiz-no-questions")

        app.buttons["quiz_leave"].tap()
        assertSavedCounts(app: app, expectedQuestionCount: "0", expectedAnswerCount: "0")
    }

    /// 端末内のモデルが使えない時は、問いを出さずにクイズを出せないことの案内が出て、「本の画面に戻る」で本の画面に戻る。問いと回答は保存されない。
    /// 案内の出た画面を `quiz-model-unavailable` の名前で添付する。
    @MainActor
    func test端末内のモデルが使えない時は案内が出て本の画面に戻れる() {
        let app = launchAppWithInMemoryStore()
        endReadingWithFakeQuiz(app: app, fakeQuizBehaviorTapCount: 3, fakeQuizBehaviorLabel: "モデルが使えない")

        XCTAssertTrue(app.staticTexts["quiz_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["quiz_guide"].label.contains("端末内のモデルを使えないため"))
        XCTAssertFalse(app.staticTexts["quiz_position"].exists)
        XCTAssertFalse(app.buttons["quiz_retry"].exists)
        attachScreenshot(app: app, name: "quiz-model-unavailable")

        app.buttons["quiz_leave"].tap()
        assertSavedCounts(app: app, expectedQuestionCount: "0", expectedAnswerCount: "0")
    }

    /// 問いを作る処理が失敗した時は、作れなかったことの案内と「もう一度作る」が出る。「もう一度作る」を押してまた失敗した時も同じ案内が出て、
    /// 「本の画面に戻る」で本の画面に戻る。問いと回答は保存されない。
    /// 案内の出た画面を `quiz-preparation-failure` の名前で添付する。
    @MainActor
    func test問いを作れなかった時は案内が出てもう一度作るか本の画面に戻れる() {
        let app = launchAppWithInMemoryStore()
        endReadingWithFakeQuiz(app: app, fakeQuizBehaviorTapCount: 4, fakeQuizBehaviorLabel: "作るのに失敗する")

        XCTAssertTrue(app.staticTexts["quiz_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["quiz_guide"].label.hasPrefix("問いを作れませんでした"))
        attachScreenshot(app: app, name: "quiz-preparation-failure")

        app.buttons["quiz_retry"].tap()
        XCTAssertTrue(app.buttons["quiz_retry"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["quiz_guide"].label.hasPrefix("問いを作れませんでした"))

        app.buttons["quiz_leave"].tap()
        assertSavedCounts(app: app, expectedQuestionCount: "0", expectedAnswerCount: "0")
    }

    /// 答えの判定が失敗した時は、判定できなかったことの案内と「本の画面に戻る」が出て、判定・模範の答えは出ない。
    /// 「本の画面に戻る」で本の画面に戻り、問い 1 件が保存されていて、回答は保存されていない。
    /// 案内の出た画面を `quiz-answer-failure` の名前で添付する。
    @MainActor
    func test答えを判定できなかった時は案内が出て回答が保存されない() {
        let app = launchAppWithInMemoryStore()
        endReadingWithFakeQuiz(app: app, fakeQuizBehaviorTapCount: 5, fakeQuizBehaviorLabel: "判定に失敗する")

        XCTAssertTrue(app.staticTexts["quiz_position"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["quiz_position"].label, "問い 1 / 1")
        XCTAssertFalse(app.buttons["quiz_leave"].exists)
        answerField(app: app).tap()
        typeAfterKeyboardFocus(element: answerField(app: app), text: "霧")
        app.buttons["quiz_answer_submit"].tap()

        XCTAssertTrue(app.staticTexts["quiz_answer_failure_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["quiz_answer_failure_guide"].label.hasPrefix("答えを判定して保存できませんでした"))
        XCTAssertFalse(app.staticTexts["quiz_judgement"].exists)
        XCTAssertFalse(app.buttons["quiz_next"].exists)
        attachScreenshot(app: app, name: "quiz-answer-failure")

        // 失敗の後は、同じ問いにもう一度答えられる (「答える」を押せる状態に戻っていて、押すともう一度判定される)。
        XCTAssertEqual(app.staticTexts["quiz_position"].label, "問い 1 / 1")
        XCTAssertTrue(app.buttons["quiz_answer_submit"].isEnabled)
        app.buttons["quiz_answer_submit"].tap()
        XCTAssertTrue(app.staticTexts["quiz_answer_failure_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.staticTexts["quiz_judgement"].exists)

        app.buttons["quiz_leave"].tap()
        assertSavedCounts(app: app, expectedQuestionCount: "1", expectedAnswerCount: "0")
    }
}
