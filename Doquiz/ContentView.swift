import SwiftUI

/// アプリを開いた直後に表示する画面。読む本を選ぶ画面を、画面を進める・戻るための `NavigationStack` に入れて出す。
struct ContentView: View {
    var body: some View {
        NavigationStack {
            #if DEBUG
                BookListView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            DeveloperMenuEntrance()
                        }
                    }
            #else
                BookListView()
            #endif
        }
        .tint(doquizAccentColor)
        // 楽しい見た目が決まるまでは、主要画面のモックと同じ白の地だけで作るため、端末が暗い外観でも明るい外観で出す
        // (`documents/DIRECTION.md`「デザインの方向」)。
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Book.self, inMemory: true)
}
