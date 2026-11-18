import SwiftData

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
