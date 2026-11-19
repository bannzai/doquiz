import SwiftData
import SwiftUI

/// doquiz のアプリ本体の入口。
@main
struct DoquizApp: App {
    /// アプリで 1 つだけ作る、端末内の保存先。
    private let modelContainer: ModelContainer
    /// アプリの設定 (同意済みか等) を読み書きする UserDefaults。画面の `@AppStorage` は全部これを使う。
    private let userDefaults: UserDefaults

    /// 端末内の保存先を開いてアプリを始める。
    ///
    /// 保存先を開けない時は、本も読書の記録も読み書きできず続けられないため、エラーの内容を残してアプリを止める。
    init() {
        let isStoredInMemoryOnly = isModelContainerStoredInMemoryOnly(launchArguments: ProcessInfo.processInfo.arguments)
        userDefaults = makeAppUserDefaults(isStoredInMemoryOnly: isStoredInMemoryOnly)
        do {
            modelContainer = try makeModelContainer(isStoredInMemoryOnly: isStoredInMemoryOnly)
        } catch {
            fatalError("端末内の保存先を開けませんでした: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .defaultAppStorage(userDefaults)
        }
        .modelContainer(modelContainer)
    }
}
