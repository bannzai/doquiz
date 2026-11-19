import Foundation

/// 画面の取り込みの同意の説明に同意済みかを保存する、UserDefaults のキー。
let hasAgreedToScreenCaptureKey = "hasAgreedToScreenCapture"

/// UI テストの起動 (メモリ内の保存先の起動) だけが使う UserDefaults の suite の名前。
let uiTestUserDefaultsSuiteName = "app.bannzai.doquiz.uiTest"

/// アプリの設定 (同意済みか等) を読み書きする UserDefaults を返す。アプリの入口で 1 回呼び、画面には `defaultAppStorage` で渡す。
///
/// `isStoredInMemoryOnly` が false の時は、端末の標準の UserDefaults を返す。
/// true の時 (UI テストの起動) は、UI テスト専用の suite を空にしてから返す。保存データと同じく、UI テストが端末の設定に触れず、
/// 起動のたびに同意していない状態から始まるようにするため。何度呼んでも、空の suite が返る。
func makeAppUserDefaults(isStoredInMemoryOnly: Bool) -> UserDefaults {
    guard isStoredInMemoryOnly else {
        return .standard
    }
    UserDefaults.standard.removePersistentDomain(forName: uiTestUserDefaultsSuiteName)
    guard let uiTestUserDefaults = UserDefaults(suiteName: uiTestUserDefaultsSuiteName) else {
        // UserDefaults(suiteName:) が nil を返すのは、名前がアプリの bundle ID か NSGlobalDomain の時だけで
        // (https://developer.apple.com/documentation/foundation/userdefaults/init(suitename:) )、上の名前はどちらでもない。
        fatalError("UI テスト用の UserDefaults を作れませんでした: \(uiTestUserDefaultsSuiteName)")
    }
    return uiTestUserDefaults
}
