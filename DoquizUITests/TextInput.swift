import XCTest

/// 入力欄 `element` を押し、キーボードの入力先が `element` に移ってから `text` を打つ。
///
/// 押した直後は入力欄にまだキーボードの入力先が移っていないことがあり、そのまま打つと
/// 「Neither element nor any descendant has keyboard focus」で失敗する
/// (実例: https://github.com/bannzai/doquiz/actions/runs/44496480547 )。
/// 待ちの上限を過ぎても入力先が移らない時はテストを失敗にして、文字は打たない。
@MainActor
func typeTextAfterKeyboardFocus(element: XCUIElement, text: String, file: StaticString = #filePath, line: UInt = #line) {
    element.tap()
    // 上限の 10 秒は、起動の待ち (30 秒) と違い、同じ画面の中の表示の更新だけを待つため短くしている (DeveloperMenuTests と同じ値)。
    guard
        XCTWaiter().wait(
            for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element)],
            timeout: 10
        ) == .completed
    else {
        XCTFail("\(element) にキーボードの入力先が移らなかった", file: file, line: line)
        return
    }
    element.typeText(text)
}
