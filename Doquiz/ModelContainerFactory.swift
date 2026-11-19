import SwiftData

/// アプリの保存先を、端末に書き込まないメモリ内の保存先にするかを、起動の引数から決める。
///
/// 開発用のビルド (DEBUG) で、起動の引数に `-uiTestInMemoryStore` がある時だけ true を返す。UI テストが端末の保存データに触れないために使う。
/// 公開用のビルドでは、引数に関わらず false を返す (利用者の保存データを、引数 1 つで読み書きしない状態にしないため)。
/// 保存先はアプリの入口で 1 つだけ作り、画面が出る前に決まるため、開発者メニューではなく起動の引数で切り替える。
func isModelContainerStoredInMemoryOnly(launchArguments: [String]) -> Bool {
    #if DEBUG
        launchArguments.contains("-uiTestInMemoryStore")
    #else
        false
    #endif
}

/// 本・読書の記録・ページ・問い・回答を保存する保存先を作る。
///
/// `isStoredInMemoryOnly` が true の時は端末に書き込まない (テストと Preview 用)。
/// 本文を端末の外に出さないため、iCloud (CloudKit) との同期はしない (`.claude/rules/swiftdata.md`)。
/// 保存先を開けなかった時は、SwiftData のエラーを投げる。
func makeModelContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
    try ModelContainer(
        for: Book.self, ReadingSession.self, CapturedPage.self, Question.self, Answer.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly, cloudKitDatabase: .none)
    )
}
