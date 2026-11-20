import XCTest

/// 本の一覧から購入の画面を開き、商品が出ている画面と、商品を取得できない時の画面を操作して確かめ、
/// それぞれのスクリーンショットをテスト結果に添付する UI テスト。
///
/// iOS Simulator では App Store の商品を取得できないため、開発者メニューで偽の購入に切り替えて確かめる
/// (UI テストの起動では RevenueCat の SDK を初期化しない)。
final class PurchaseTests: XCTestCase {
    /// 今の画面を `name` の名前でテスト結果に添付する。
    @MainActor
    private func attachScreenshot(app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// `element` の label が `expectedLabel` になるまで待つ。待ちの上限を過ぎてもならない時はテストを失敗にする。
    @MainActor
    private func assertEventuallyLabel(element: XCUIElement, expectedLabel: String) {
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expectedLabel), object: element)],
                timeout: sameScreenChangeWaitTimeout
            ),
            .completed,
            "\(element) の label が \(expectedLabel) にならなかった (表示: \(element.exists ? element.label : "要素が無い"))"
        )
    }

    /// 本の一覧から開発者メニューを開き、見本のデータ (読書の記録がある本) を入れ、購入の動きの切り替えを `tapCount` 回押して
    /// `initialFakePurchaseBehaviorLabel` の動きから `fakePurchaseBehaviorLabel` の動きにし、一覧に戻って購入の画面を開く。
    ///
    /// 見本のデータを入れるのは、購入の画面への入口が、読書の記録が 1 件でもある時だけ本の一覧に出るため。
    @MainActor
    private func openPurchaseWithFakePurchase(
        app: XCUIApplication,
        initialFakePurchaseBehaviorLabel: String,
        tapCount: Int,
        fakePurchaseBehaviorLabel: String
    ) {
        XCTAssertTrue(app.buttons["developer_menu_entrance"].waitForExistence(timeout: 30))
        app.buttons["developer_menu_entrance"].tap()
        XCTAssertTrue(app.buttons["developer_menu_replace_sample_data"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["developer_menu_replace_sample_data"].tap()
        assertEventuallyLabel(element: app.staticTexts["developer_menu_answer_count"], expectedLabel: "7")
        let cycleButton = app.buttons["developer_menu_cycle_fake_purchase_behavior"]
        let behaviorState = app.staticTexts["developer_menu_fake_purchase_behavior_state"]
        // 切り替えのボタンと今の動きの行はメニューのいちばん下に並んでいて、画面に入っていない間は要素が無い。
        // ボタンのすぐ下の「今の動き」の行が画面に入るまで上へ送る (ボタンだけが画面に入った位置で止めると、押した後の動きを読めない)。
        // 上限の 6 回は、メニューの 6 つの section を 1 回に 1 つずつしか送れなくても、いちばん下まで届く回数。
        for _ in 0..<6 where !(behaviorState.exists && behaviorState.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(behaviorState.waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(cycleButton.waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(behaviorState.label, initialFakePurchaseBehaviorLabel)
        for _ in 0..<tapCount {
            cycleButton.tap()
        }
        assertEventuallyLabel(element: behaviorState, expectedLabel: fakePurchaseBehaviorLabel)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["purchase_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["purchase_entrance"].tap()
    }

    /// 購入の画面の商品の行のうち、label に `text` を含む行を返す。
    @MainActor
    private func packageRow(app: XCUIApplication, text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "purchase_package_row", text)).firstMatch
    }

    /// 商品を取得できた時は、年額・月額・買い切りの 3 つの行に、取得した値段と更新の間隔とトライアルの長さが出る。
    /// 初めは並びの最初の年額を選んでいて、購入のボタンと更新の説明が年額のトライアルと値段になっている。
    /// 買い切りを選ぶと、ボタンが「購入する」に変わり、自動で更新される説明が消える。購入すると、商品が消えて購入済みの表示になる。
    /// 3 つの商品が出ている画面を `purchase-packages`、購入済みの画面を `purchase-purchased` の名前で添付する。
    /// 読書の記録が無い間 (起動した直後の、保存データが空の一覧) は、購入の画面への入口が本の一覧に出ない。
    /// 読書の記録がある本ができると、入口が出る。入口が出ている一覧を `book-list-purchase-entrance` の名前で添付する。
    @MainActor
    func test商品を取得できた時は3つの商品が出て購入すると購入済みになる() {
        let app = launchAppWithInMemoryStore()
        XCTAssertTrue(app.buttons["book_registration_entrance"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["purchase_entrance"].exists)
        openPurchaseWithFakePurchase(app: app, initialFakePurchaseBehaviorLabel: "実物", tapCount: 1, fakePurchaseBehaviorLabel: "商品を返す")

        XCTAssertTrue(app.buttons["purchase_button"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.buttons.matching(identifier: "purchase_package_row").count, 3)
        let annualRow = packageRow(app: app, text: "年額")
        XCTAssertTrue(annualRow.label.contains("¥5,000"))
        XCTAssertTrue(annualRow.label.contains("1 週間無料 その後 1 年ごとに更新"))
        XCTAssertTrue(annualRow.isSelected)
        let monthlyRow = packageRow(app: app, text: "月額")
        XCTAssertTrue(monthlyRow.label.contains("¥500"))
        XCTAssertTrue(monthlyRow.label.contains("1 週間無料 その後 1 か月ごとに更新"))
        XCTAssertFalse(monthlyRow.isSelected)
        let lifetimeRow = packageRow(app: app, text: "買い切り")
        XCTAssertTrue(lifetimeRow.label.contains("¥20,000"))
        XCTAssertTrue(lifetimeRow.label.contains("1 回の支払いでずっと使えます"))
        XCTAssertEqual(app.buttons["purchase_button"].label, "1 週間無料で始める")
        XCTAssertEqual(app.staticTexts["purchase_renewal_note"].label, "無料の期間が終わると年額 ¥5,000 で自動で更新されます")
        XCTAssertTrue(app.buttons["purchase_restore_button"].exists)
        XCTAssertFalse(app.staticTexts["purchase_unavailable_guide"].exists)
        attachScreenshot(app: app, name: "purchase-packages")

        lifetimeRow.tap()
        assertEventuallyLabel(element: app.buttons["purchase_button"], expectedLabel: "購入する")
        XCTAssertTrue(lifetimeRow.isSelected)
        XCTAssertFalse(app.staticTexts["purchase_renewal_note"].exists)

        app.buttons["purchase_button"].tap()
        XCTAssertTrue(app.staticTexts["purchase_state_title"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["purchase_state_title"].label, "購入済みです")
        XCTAssertEqual(app.buttons.matching(identifier: "purchase_package_row").count, 0)
        XCTAssertFalse(app.buttons["purchase_button"].exists)
        attachScreenshot(app: app, name: "purchase-purchased")

        app.buttons["purchase_close_button"].tap()
        XCTAssertTrue(app.buttons["purchase_entrance"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.buttons["purchase_entrance"].label, "購入のプランを見る")
        attachScreenshot(app: app, name: "book-list-purchase-entrance")
    }

    /// 利用者が購入を取り消した時は、失敗の文を出さず、3 つの商品が出たままである。
    /// 購入に失敗した時と復元に失敗した時は、画面を閉じずに、購入のボタンの上にそれぞれの文を出す。
    /// 購入に失敗した時の画面を `purchase-failed` の名前で添付する。
    @MainActor
    func test購入を取り消した時は何も出さず失敗した時は失敗の文を出す() {
        let app = launchAppWithInMemoryStore()
        openPurchaseWithFakePurchase(app: app, initialFakePurchaseBehaviorLabel: "実物", tapCount: 5, fakePurchaseBehaviorLabel: "購入を取り消す")

        XCTAssertTrue(app.buttons["purchase_button"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["purchase_button"].tap()
        // 取り消した後は画面が変わらないため、変わるのを待てない。偽の購入はすぐ返るので、押した後にボタンが押せる状態へ戻るのを待ってから確かめる。
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: app.buttons["purchase_button"])],
                timeout: sameScreenChangeWaitTimeout
            ),
            .completed
        )
        XCTAssertFalse(app.staticTexts["purchase_failure_message"].exists)
        XCTAssertFalse(app.staticTexts["purchase_state_title"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "purchase_package_row").count, 3)
        app.buttons["purchase_close_button"].tap()

        openPurchaseWithFakePurchase(app: app, initialFakePurchaseBehaviorLabel: "購入を取り消す", tapCount: 1, fakePurchaseBehaviorLabel: "購入と復元に失敗する")
        XCTAssertTrue(app.buttons["purchase_button"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        app.buttons["purchase_button"].tap()
        XCTAssertTrue(app.staticTexts["purchase_failure_message"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["purchase_failure_message"].label.hasPrefix("購入できませんでした"))
        XCTAssertEqual(app.buttons.matching(identifier: "purchase_package_row").count, 3)
        attachScreenshot(app: app, name: "purchase-failed")

        app.buttons["purchase_restore_button"].tap()
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "復元できませんでした"), object: app.staticTexts["purchase_failure_message"])],
                timeout: sameScreenChangeWaitTimeout
            ),
            .completed
        )
        XCTAssertFalse(app.staticTexts["purchase_state_title"].exists)
    }

    /// 商品を取得できなかった後に「もう一度取得する」を押すと、取得し直す。取得し直している間に購入済みだと知らされた時
    /// (端末に持っていた古い状態の後に新しい状態が届く場面) は、取得し終えた商品で上書きされず、開き直さなくても購入済みの表示になる。
    @MainActor
    func test取得し直している間に購入済みと知らされると購入済みの表示になる() {
        let app = launchAppWithInMemoryStore()
        openPurchaseWithFakePurchase(app: app, initialFakePurchaseBehaviorLabel: "実物", tapCount: 8, fakePurchaseBehaviorLabel: "取得し直すと購入済みに変わる")

        XCTAssertTrue(app.staticTexts["purchase_unavailable_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertFalse(app.staticTexts["purchase_state_title"].exists)
        app.buttons["purchase_retry_button"].tap()

        XCTAssertTrue(app.staticTexts["purchase_state_title"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["purchase_state_title"].label, "購入済みです")
        XCTAssertFalse(app.staticTexts["purchase_unavailable_guide"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "purchase_package_row").count, 0)
    }

    /// 商品を取得できない時は、商品の行も値段も購入のボタンも出さず、取得できなかった案内と、取得し直す入口が出る。
    /// 取得し直しても取得できない間は、同じ案内のままである。復元できる購入が無い時に復元すると、見つからなかった旨が出る。
    /// 商品を取得できない時の画面を `purchase-unavailable` の名前で添付する。
    @MainActor
    func test商品を取得できない時は値段を出さず取得し直す入口が出る() {
        let app = launchAppWithInMemoryStore()
        openPurchaseWithFakePurchase(app: app, initialFakePurchaseBehaviorLabel: "実物", tapCount: 2, fakePurchaseBehaviorLabel: "商品を取得できない")

        XCTAssertTrue(app.staticTexts["purchase_unavailable_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertTrue(app.staticTexts["purchase_unavailable_guide"].label.contains("商品の情報を取得できませんでした"))
        XCTAssertTrue(app.buttons["purchase_retry_button"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "purchase_package_row").count, 0)
        XCTAssertFalse(app.buttons["purchase_button"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "¥")).count, 0)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "無料")).count, 0)
        attachScreenshot(app: app, name: "purchase-unavailable")

        app.buttons["purchase_retry_button"].tap()
        XCTAssertTrue(app.staticTexts["purchase_unavailable_guide"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.buttons.matching(identifier: "purchase_package_row").count, 0)

        app.buttons["purchase_restore_button"].tap()
        XCTAssertTrue(app.staticTexts["purchase_failure_message"].waitForExistence(timeout: sameScreenChangeWaitTimeout))
        XCTAssertEqual(app.staticTexts["purchase_failure_message"].label, "復元できる購入が見つかりませんでした")
    }
}
