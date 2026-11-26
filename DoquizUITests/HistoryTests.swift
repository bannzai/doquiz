import XCTest

/// 履歴の画面 (読書の記録の一覧・読書の記録の中身・答え直し・読書の記録と本の削除) を操作して確かめ、画面のスクリーンショットをテスト結果に添付する UI テスト。
///
/// 読書の記録と回答がある状態は、開発者メニューの見本のデータで作る。見本の本「潮見町の灯台日誌」は読書の記録を 2 件持ち、
/// 新しい方がページ 1 件・問い 1 問・回答 1 件、古い方がページ 2 件・問い 4 問・回答 5 件 (`Doquiz/DeveloperMenu/DeveloperMenuSampleData.swift`)。
final class HistoryTests: XCTestCase {
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
        // 上限の 30 秒は、GitHub の runner が遅い時に、画面の要素を 1 回探すだけで約 9 秒かかった実測に合わせた (QuizTests と同じ値。https://github.com/bannzai/doquiz/issues/58 )。
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: predicateFormat, argument), object: object)],
                timeout: 30
            ),
            .completed,
            "\(object) が \(predicateFormat) (\(argument)) にならなかった"
        )
    }

    /// 起動直後の一覧から開発者メニューで見本のデータを入れ、クイズの切り替えを `fakeQuizBehaviorTapCount` 回押して (押した後の表示が `fakeQuizBehaviorLabel` であることを確かめる)、
    /// 一覧に戻って名前が `bookTitle` の見本の本の画面から履歴を開く。
    @MainActor
    private func openSampleBookHistory(app: XCUIApplication, bookTitle: String, fakeQuizBehaviorTapCount: Int, fakeQuizBehaviorLabel: String) {
        // GitHub の runner の Simulator は起動直後の描画が遅いことがあるため、待ちの上限を長めに取る (ScreenshotTests と同じ値)。
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.buttons["developer_menu_replace_sample_data"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_replace_sample_data"].tap()
        assertEventually(object: app.staticTexts["developer_menu_answer_count"], predicateFormat: "label == %@", argument: "7")
        // クイズの切り替えは一覧の下にあり、画面に入っていないことがあるため、上へ送ってから押す。
        app.swipeUp()
        XCTAssertTrue(app.buttons["developer_menu_cycle_fake_quiz_behavior"].waitForExistence(timeout: 30))
        for _ in 0..<fakeQuizBehaviorTapCount {
            app.buttons["developer_menu_cycle_fake_quiz_behavior"].tap()
        }
        assertEventually(object: app.staticTexts["developer_menu_fake_quiz_behavior_state"], predicateFormat: "label == %@", argument: fakeQuizBehaviorLabel)
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(bookListRow(app: app, bookTitle: bookTitle).waitForExistence(timeout: 30))
        bookListRow(app: app, bookTitle: bookTitle).tap()
        XCTAssertTrue(app.buttons["history_entrance"].waitForExistence(timeout: 30))
        app.buttons["history_entrance"].tap()
        XCTAssertTrue(app.staticTexts["history_book_title"].waitForExistence(timeout: 30))
    }

    /// 本の一覧の、名前が `bookTitle` の本の行を返す。
    @MainActor
    private func bookListRow(app: XCUIApplication, bookTitle: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "book_list_row", bookTitle)).firstMatch
    }

    /// 読書の記録の中身の画面に出ている回答を探す条件を返す。回答 1 件は、答えた日時・答え・判定をまとめた 1 つの要素。
    @MainActor
    private func readingSessionHistoryAnswers(app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "reading_session_history_answer")
    }

    /// 本の画面から履歴を開くと、その本の読書の記録が新しい順に並び、読書の記録ごとのページの数・問いの数と、問いごとのいちばん新しい回答の判定が出る。
    /// 読書の記録を開くと、問い・自分の回答・判定・模範の答え・根拠の引用・ページの本文が出る。
    /// 履歴の一覧を `history`、読書の記録の中身を `history-reading-session` の名前で添付する。
    @MainActor
    func test本の画面から履歴を開いて読書の記録を開くと問いと回答と判定が出る() {
        let app = launchAppWithInMemoryStore()
        openSampleBookHistory(app: app, bookTitle: "潮見町の灯台日誌", fakeQuizBehaviorTapCount: 1, fakeQuizBehaviorLabel: "問いを返す")

        XCTAssertEqual(app.staticTexts["history_book_title"].label, "潮見町の灯台日誌")
        XCTAssertEqual(app.buttons.matching(identifier: "history_reading_session").count, 2)
        XCTAssertTrue(app.buttons.matching(identifier: "history_reading_session").element(boundBy: 0).label.contains("1 ページ ・ 1 問"))
        XCTAssertTrue(app.buttons.matching(identifier: "history_reading_session").element(boundBy: 1).label.contains("2 ページ ・ 4 問"))
        XCTAssertEqual(app.staticTexts.matching(identifier: "history_question_text").count, 5)
        XCTAssertEqual(app.staticTexts.matching(identifier: "history_question_text").element(boundBy: 0).label, "灯台の電源が落ちた夜、三枝は何を回したか")
        // 穴埋めの問い (4 つ目) は、合っていない回答の後に合っている回答があるため、いちばん新しい回答の判定が出る。
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "history_question_judgement").allElementsBoundByIndex.map(\.label),
            ["合っていませんでした", "合っていました", "合っていませんでした", "合っていると判定しました", "合っていると判定しました"]
        )
        XCTAssertFalse(app.staticTexts["history_empty_guide"].exists)
        attachScreenshot(app: app, name: "history")

        app.buttons.matching(identifier: "history_reading_session").element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["reading_session_history_counts"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["reading_session_history_counts"].label, "2 ページ ・ 4 問")
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "reading_session_history_question_text").allElementsBoundByIndex.map(\.label),
            [
                "灯台守の三枝が毎朝五時にすることは何か",
                "要約「霧の濃い日は、灯りだけで船に岬の位置が伝わる」は本文と合っているか",
                "三枝は霧笛を＿＿おきに鳴らした",
                "三枝が霧の濃い日に霧笛を鳴らすのはなぜか",
            ]
        )
        XCTAssertEqual(readingSessionHistoryAnswers(app: app).count, 5)
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 0).label.contains("レンズを布で拭く"))
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 0).label.contains("合っていました"))
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 1).label.contains("合っていませんでした"))
        // 穴埋めの問いの 2 件の回答は、答えた日時の古い順に出る。
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 2).label.contains("三分"))
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 2).label.contains("合っていないと判定しました"))
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 3).label.contains("三十秒"))
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 3).label.contains("合っていると判定しました"))
        XCTAssertFalse(app.staticTexts["reading_session_history_no_answer"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "reading_session_history_model_answer").element(boundBy: 2).label, "三十秒")
        XCTAssertEqual(
            app.staticTexts.matching(identifier: "reading_session_history_evidence_quote").element(boundBy: 0).label,
            "灯台守の三枝は、毎朝五時に階段を百二十段のぼり、レンズを布で拭く。"
        )
        XCTAssertEqual(app.staticTexts.matching(identifier: "reading_session_history_page_text").count, 2)
        XCTAssertTrue(app.staticTexts.matching(identifier: "reading_session_history_page_text").element(boundBy: 0).label.hasPrefix("潮見町の灯台は"))
        XCTAssertTrue(app.staticTexts.matching(identifier: "reading_session_history_page_text").element(boundBy: 1).label.hasPrefix("霧の濃い日は"))
        attachScreenshot(app: app, name: "history-reading-session")
    }

    /// 履歴の問いに答え直すと、判定・模範の答え・根拠の引用が出て、履歴に戻るとその問いの判定が新しい回答のものに変わり、読書の記録の中身の回答が 1 件から 2 件に増える (前の回答は残る)。
    /// 答え直した後の表示を `history-reanswered` の名前で添付する。
    @MainActor
    func test履歴の問いに答え直すと判定と模範の答えと根拠が出て回答が1件増える() {
        let app = launchAppWithInMemoryStore()
        openSampleBookHistory(app: app, bookTitle: "潮見町の灯台日誌", fakeQuizBehaviorTapCount: 1, fakeQuizBehaviorLabel: "問いを返す")

        app.buttons.matching(identifier: "history_reading_session").element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["reading_session_history_counts"].waitForExistence(timeout: 30))
        XCTAssertEqual(readingSessionHistoryAnswers(app: app).count, 1)
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 0).label.contains("風車"))
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.buttons["history_book_delete"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts.matching(identifier: "history_question_judgement").element(boundBy: 0).label, "合っていませんでした")
        XCTAssertEqual(app.buttons.matching(identifier: "history_reanswer").element(boundBy: 0).label, "もう一度答える")
        app.buttons.matching(identifier: "history_reanswer").element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["quiz_question_text"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["quiz_question_text"].label, "灯台の電源が落ちた夜、三枝は何を回したか")
        XCTAssertEqual(app.staticTexts["quiz_kind"].label, "四択")
        XCTAssertFalse(app.staticTexts["quiz_position"].exists)
        XCTAssertFalse(app.staticTexts["quiz_judgement"].exists)
        XCTAssertEqual(app.buttons["quiz_leave"].label, "答えずに履歴に戻る")
        XCTAssertEqual(app.buttons["quiz_choice_0"].label, "予備の発電機")
        app.buttons["quiz_choice_0"].tap()
        XCTAssertTrue(app.staticTexts["quiz_judgement"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["quiz_judgement"].label, "合っています")
        XCTAssertEqual(app.staticTexts["quiz_judgement_sign"].label, "○")
        XCTAssertEqual(app.staticTexts["quiz_model_answer"].label, "予備の発電機")
        XCTAssertEqual(app.staticTexts["quiz_evidence_quote"].label, "三枝は予備の発電機を回し、朝まで灯りを絶やさなかった。")
        XCTAssertEqual(app.buttons["quiz_next"].label, "履歴に戻る")
        XCTAssertFalse(app.buttons["quiz_leave"].exists)
        attachScreenshot(app: app, name: "history-reanswered")

        app.buttons["quiz_next"].tap()
        XCTAssertTrue(app.buttons["history_book_delete"].waitForExistence(timeout: 30))
        assertEventually(
            object: app.staticTexts.matching(identifier: "history_question_judgement").element(boundBy: 0),
            predicateFormat: "label == %@",
            argument: "合っていました"
        )
        app.buttons.matching(identifier: "history_reading_session").element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["reading_session_history_counts"].waitForExistence(timeout: 30))
        assertEventually(object: readingSessionHistoryAnswers(app: app), predicateFormat: "count == %d", argument: 2)
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 0).label.contains("風車"))
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 0).label.contains("合っていませんでした"))
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 1).label.contains("予備の発電機"))
        XCTAssertTrue(readingSessionHistoryAnswers(app: app).element(boundBy: 1).label.contains("合っていました"))
    }

    /// 端末内のモデルが使えない時は、穴埋めの問いの答え直しは始まらずに、始められないことの案内がその問いの下に出る。
    /// 四択の問いの答え直しは始められ、答えずに履歴に戻ると判定は前のまま変わらない。
    @MainActor
    func test端末内のモデルが使えない時は穴埋めの答え直しを始められず四択は始められる() {
        let app = launchAppWithInMemoryStore()
        openSampleBookHistory(app: app, bookTitle: "潮見町の灯台日誌", fakeQuizBehaviorTapCount: 3, fakeQuizBehaviorLabel: "モデルが使えない")

        XCTAssertFalse(app.staticTexts["history_reanswer_unavailable_guide"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "history_question_text").element(boundBy: 3).label, "三枝は霧笛を＿＿おきに鳴らした")
        app.buttons.matching(identifier: "history_reanswer").element(boundBy: 3).tap()
        XCTAssertTrue(app.staticTexts["history_reanswer_unavailable_guide"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["history_reanswer_unavailable_guide"].label.contains("この問いには答え直せません"))
        XCTAssertFalse(app.staticTexts["quiz_question_text"].exists)

        app.buttons.matching(identifier: "history_reanswer").element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["quiz_question_text"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["quiz_question_text"].label, "灯台守の三枝が毎朝五時にすることは何か")
        app.buttons["quiz_leave"].tap()
        XCTAssertTrue(app.buttons["history_book_delete"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["history_reanswer_unavailable_guide"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "history_question_judgement").element(boundBy: 1).label, "合っていました")
    }

    /// 読書の記録を消す前に、一緒に消えるものの数が出る。「消さない」では消えず、「消す」で履歴からその読書の記録が消える。
    /// 本を消す前にも一緒に消えるものの数が出て、「消す」で本の一覧に戻り、その本が一覧から消える。もう 1 冊の本とそのデータは残る。
    /// 読書の記録を消す前の確認を `history-delete-confirmation` の名前で添付する。
    @MainActor
    func test読書の記録を消すと履歴から消えて本を消すと本の一覧から消える() {
        let app = launchAppWithInMemoryStore()
        openSampleBookHistory(app: app, bookTitle: "潮見町の灯台日誌", fakeQuizBehaviorTapCount: 1, fakeQuizBehaviorLabel: "問いを返す")

        app.buttons.matching(identifier: "history_reading_session").element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["reading_session_delete"].waitForExistence(timeout: 30))
        app.buttons["reading_session_delete"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 30))
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "ページ 1 件 問い 1 問 回答 1 件も消えます")).firstMatch.exists)
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "元に戻せません")).firstMatch.exists)
        attachScreenshot(app: app, name: "history-delete-confirmation")
        app.alerts.buttons["消さない"].tap()
        assertEventually(object: app.alerts, predicateFormat: "count == %d", argument: 0)
        XCTAssertEqual(app.staticTexts["reading_session_history_counts"].label, "1 ページ ・ 1 問")

        app.buttons["reading_session_delete"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 30))
        app.alerts.buttons["消す"].tap()
        XCTAssertTrue(app.buttons["history_book_delete"].waitForExistence(timeout: 30))
        assertEventually(object: app.buttons.matching(identifier: "history_reading_session"), predicateFormat: "count == %d", argument: 1)
        XCTAssertTrue(app.buttons.matching(identifier: "history_reading_session").element(boundBy: 0).label.contains("2 ページ ・ 4 問"))
        XCTAssertEqual(app.staticTexts.matching(identifier: "history_question_text").count, 4)

        app.buttons["history_book_delete"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 30))
        XCTAssertTrue(
            app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "読書の記録 1 件 ページ 2 件 問い 4 問 回答 5 件も消えます")).firstMatch.exists
        )
        app.alerts.buttons["消す"].tap()

        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: 30))
        assertEventually(object: app.buttons.matching(identifier: "book_list_row"), predicateFormat: "count == %d", argument: 1)
        XCTAssertTrue(bookListRow(app: app, bookTitle: "はじめての堆肥づくり").exists)
        XCTAssertFalse(bookListRow(app: app, bookTitle: "潮見町の灯台日誌").exists)
        XCTAssertFalse(app.buttons["history_entrance"].exists)

        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.staticTexts["developer_menu_book_count"].waitForExistence(timeout: 30))
        for countIdentifier in [
            "developer_menu_book_count",
            "developer_menu_reading_session_count",
            "developer_menu_captured_page_count",
            "developer_menu_question_count",
            "developer_menu_answer_count",
        ] {
            assertEventually(object: app.staticTexts[countIdentifier], predicateFormat: "label == %@", argument: "1")
        }
    }

    /// 読書の記録が 1 件だけの本でその記録を消すと、履歴に「まだ読書の記録がありません」が出て、本は一覧に残る。
    @MainActor
    func test読書の記録が1件だけの本でその記録を消すと記録が無いことの案内が出る() {
        let app = launchAppWithInMemoryStore()
        openSampleBookHistory(app: app, bookTitle: "はじめての堆肥づくり", fakeQuizBehaviorTapCount: 1, fakeQuizBehaviorLabel: "問いを返す")

        XCTAssertEqual(app.staticTexts["history_book_title"].label, "はじめての堆肥づくり")
        XCTAssertEqual(app.buttons.matching(identifier: "history_reading_session").count, 1)
        XCTAssertFalse(app.staticTexts["history_empty_guide"].exists)
        app.buttons.matching(identifier: "history_reading_session").element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["reading_session_delete"].waitForExistence(timeout: 30))
        app.buttons["reading_session_delete"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 30))
        app.alerts.buttons["消す"].tap()

        XCTAssertTrue(app.staticTexts["history_empty_guide"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["history_empty_guide"].label, "まだ読書の記録がありません")
        XCTAssertEqual(app.buttons.matching(identifier: "history_reading_session").count, 0)
        XCTAssertEqual(app.staticTexts.matching(identifier: "history_question_text").count, 0)
        app.buttons["history_close"].tap()
        XCTAssertTrue(app.staticTexts["book_title"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["book_reading_summary"].label, "まだ読んでいません")
    }
}
