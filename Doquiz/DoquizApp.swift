import SwiftData
import SwiftUI

/// doquiz のアプリ本体の入口。
@main
struct DoquizApp: App {
    /// アプリで 1 つだけ作る、端末内の保存先。
    private let modelContainer: ModelContainer

    /// 端末内の保存先を開いてアプリを始める。
    ///
    /// 保存先を開けない時は、本も読書の記録も読み書きできず続けられないため、エラーの内容を残してアプリを止める。
    init() {
        do {
            modelContainer = try makeModelContainer(
                isStoredInMemoryOnly: isModelContainerStoredInMemoryOnly(launchArguments: ProcessInfo.processInfo.arguments)
            )
        } catch {
            fatalError("端末内の保存先を開けませんでした: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
