import SwiftData
import SwiftUI

/// doquiz のアプリ本体の入口。
@main
struct DoquizApp: App {
    /// アプリで 1 つだけ作る、端末内の保存先。
    private let modelContainer: ModelContainer
    /// アプリの設定 (同意済みか等) を読み書きする UserDefaults。画面の `@AppStorage` は全部これを使う。
    private let userDefaults: UserDefaults
    /// これまでに無料で始めた読書の回数。画面には environment で渡す。
    private let freeReadingStartCount: FreeReadingStartCount

    /// 端末内の保存先を開いてアプリを始める。
    ///
    /// 保存先を開けない時は、本も読書の記録も読み書きできず続けられないため、エラーの内容を残してアプリを止める。
    init() {
        let isStoredInMemoryOnly = isModelContainerStoredInMemoryOnly(launchArguments: ProcessInfo.processInfo.arguments)
        userDefaults = makeAppUserDefaults(isStoredInMemoryOnly: isStoredInMemoryOnly)
        #if DEBUG
            // UI テストの起動では、端末内のモデルが使えるかを実物で確かめず、偽物の「使える」から始める。
            // GitHub Actions の iOS Simulator で実物が何を返すかを確かめておらず、使えないと返ると「読書を始める」を押す UI テストが全部落ちるため。
            // 使えない状態は、UI テストが開発者メニューで切り替えて作る。
            if isStoredInMemoryOnly {
                userDefaults.set(DeveloperMenuQuizAvailability.available.rawValue, forKey: developerMenuQuizAvailabilityKey)
            }
        #endif
        // UI テストの起動 (メモリ内の保存先の起動) と単体テストの起動では、RevenueCat の SDK を初期化しない。
        // テストが RevenueCat と通信せず、購入の画面を偽の購入だけで確かめるため。
        if !isStoredInMemoryOnly, !isLaunchedAsUnitTestHost(environment: ProcessInfo.processInfo.environment) {
            configureRevenueCat(
                publicAPIKey: revenueCatPublicAPIKey(
                    infoDictionaryValue: Bundle.main.object(forInfoDictionaryKey: revenueCatPublicAPIKeyInfoDictionaryKey)
                )
            )
        }
        // UI テストの起動と単体テストの起動では、端末の Keychain に触れず、0 回から始まるメモリ内の保存先を使う
        // (UI テストが起動のたびに同じ回数から始まり、端末に回数を残さないため。保存データと UserDefaults と同じ扱い)。
        freeReadingStartCount = FreeReadingStartCount(
            store: isStoredInMemoryOnly || isLaunchedAsUnitTestHost(environment: ProcessInfo.processInfo.environment)
                ? makeInMemoryFreeReadingStartCountStore()
                : makeKeychainFreeReadingStartCountStore(service: "app.bannzai.doquiz.freeReadingStartCount")
        )
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
                .environment(freeReadingStartCount)
        }
        .modelContainer(modelContainer)
    }
}
