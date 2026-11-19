import XCTest

/// アプリを、端末に書き込まないメモリ内の保存先で起動して返す。
///
/// UI テストが端末の保存データに触れないよう、起動の引数 `-uiTestInMemoryStore` を渡す (`.claude/rules/swiftdata.md`)。
/// 保存先は起動のたびに空で始まるため、テストは前のテストの保存データに依らない。
@MainActor
func launchAppWithInMemoryStore() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments.append("-uiTestInMemoryStore")
    app.launch()
    return app
}
