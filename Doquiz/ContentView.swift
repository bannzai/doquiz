import SwiftUI

/// アプリを開いた直後に表示する画面。
struct ContentView: View {
    var body: some View {
        #if DEBUG
            NavigationStack {
                appName
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            DeveloperMenuEntrance()
                        }
                    }
            }
        #else
            appName
        #endif
    }

    /// アプリの名前の表示。
    private var appName: some View {
        Text(verbatim: "doquiz")
            .font(.largeTitle)
    }
}

#Preview {
    ContentView()
}
