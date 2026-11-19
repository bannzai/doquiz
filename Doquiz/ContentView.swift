import SwiftUI

/// アプリを開いた直後に表示する画面。読む本を選ぶ画面を、画面を進める・戻るための `NavigationStack` に入れて出す。
///
/// アプリを開いた時と、ほかのアプリから戻ってきた時に、端末内のモデルが使えるかを確かめ、
/// 使えない時の案内の文を、中の画面 (本の一覧・本の画面) に environment で渡す。使えない間は、開いたままでも 5 秒ごとに確かめ直す。
/// 開発者メニューで偽の値に切り替えた時も、実機で設定を変えた時と同じく、これらの時点で確かめるまで画面は変わらない。
struct ContentView: View {
    /// アプリが前面にあるか。ほかのアプリから戻ってきた時を知るために読む。
    @Environment(\.scenePhase) private var scenePhase
    /// 最後に確かめた時の、端末内のモデルが使えない時の案内の文。使えた時は nil。
    @State private var lastCheckedQuizUnavailableGuide: String?
    #if DEBUG
        /// 開発者メニューで選んだ、端末内のモデルが使えるかの確かめ方。
        /// 既定を `.real` にしているのは、切り替えていない開発用のビルドでは実物で確かめるため。
        @AppStorage(developerMenuQuizAvailabilityKey) private var developerMenuQuizAvailability =
            DeveloperMenuQuizAvailability.real
    #endif

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
        .environment(\.quizUnavailableGuide, lastCheckedQuizUnavailableGuide)
        .onAppear {
            checkQuizAvailability()
        }
        .onChange(of: scenePhase) {
        }
        // 使えない間は、アプリを開いたままでも確かめ直す。モデルの準備は端末が自動で進め、アプリを前面に出している間に終わることがあるため
        // (案内は「しばらく待つと読書を始められます」と伝えている)。案内の文が変わるか消えると、この処理は始め直される。
        .task(id: lastCheckedQuizUnavailableGuide) {
            guard lastCheckedQuizUnavailableGuide != nil else {
                return
            }
            while !Task.isCancelled {
                // 5 秒にしているのは、案内を読んで待つ利用者が、使えるようになってから長く待たされないようにするため。
                // 確かめるのは使えない間だけなので、使える端末ではこの繰り返しは動かない。
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    checkQuizAvailability()
                }
            }
        }
    }

    /// 端末内のモデルが使えるかを確かめる `QuizEngine` を作る。開発者メニューで偽物に切り替えている時は、選んだ値を返す偽物を返す。
    private func makeQuizEngineForAvailability() -> any QuizEngine {
        #if DEBUG
            if let availability = developerMenuFakeQuizAvailability(developerMenuQuizAvailability: developerMenuQuizAvailability) {
                // 使えるかを確かめるだけで、問いを作る処理と判定は呼ばないため、問いは空、判定は false にしている。
                return FixedQuizEngine(availability: availability, questions: [], modelJudgement: false)
            }
        #endif
        return FoundationModelsQuizEngine()
    }

    /// 端末内のモデルが使えるかを確かめ、使えない時の案内の文を入れ直す。何度呼んでも、今の状態の案内になる。
    private func checkQuizAvailability() {
        lastCheckedQuizUnavailableGuide = quizUnavailableGuide(availability: makeQuizEngineForAvailability().availability)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Book.self, inMemory: true)
}
