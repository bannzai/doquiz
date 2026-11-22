import XCTest

/// 開いている開発者メニューで、購入を偽の購入の「商品を返す」(購入もトライアルもしていない状態) に切り替える。購入の切り替えが「実物」の時に呼ぶ。
///
/// UI テストの起動は RevenueCat の SDK を初期化しないため、購入を実物のままにすると購入の状態を取得できず、「読書を始める」で読書が始まらない
/// (取得できない時は購入していない・購入済みのどちらにも写さない。https://github.com/bannzai/doquiz/pull/84#issuecomment-7071830203 )。
/// 読書を始める UI テストは、開発者メニューを開いた時にこれを呼んで、購入していない利用者として始める。
/// 上限の 6 回は、1 回に 1 つずつしか section を送れなくても上から 6 つ目の購入の section に届く 5 回に、1 回の余裕を足した回数。
@MainActor
func selectNotPurchasedFakePurchase(app: XCUIApplication) {
    let fakePurchaseBehaviorState = app.staticTexts["developer_menu_fake_purchase_behavior_state"]
    for _ in 0..<6 where !(fakePurchaseBehaviorState.exists && fakePurchaseBehaviorState.isHittable) {
        app.swipeUp()
    }
    XCTAssertTrue(fakePurchaseBehaviorState.waitForExistence(timeout: sameScreenChangeWaitTimeout))
    XCTAssertEqual(fakePurchaseBehaviorState.label, "実物")
    app.buttons["developer_menu_cycle_fake_purchase_behavior"].tap()
    XCTAssertEqual(
        XCTWaiter().wait(
            for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "商品を返す"), object: fakePurchaseBehaviorState)],
            timeout: sameScreenChangeWaitTimeout
        ),
        .completed,
        "購入の切り替えが「商品を返す」にならなかった"
    )
}
