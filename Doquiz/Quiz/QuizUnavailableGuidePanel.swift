import SwiftUI

extension EnvironmentValues {
    /// 端末内のモデルが使えない時の案内の文 (`quizUnavailableGuide(availability:)` の返り値)。使える時は nil。
    ///
    /// アプリの入口の画面 (`ContentView`) が、アプリを開いた時と、ほかのアプリから戻ってきた時に確かめて入れる。
    /// 既定を nil にしているのは、入口の画面を通らない Preview を、端末内のモデルが使える時の見た目で出すため。
    @Entry var quizUnavailableGuide: String?
}

/// 端末内のモデルが使えない時の案内を出す面。本の一覧と本の画面に置く。
struct QuizUnavailableGuidePanel: View {
    /// 出す案内の文 (`quizUnavailableGuide(availability:)` の返り値)。
    let guide: String

    var body: some View {
        Text(verbatim: guide)
            .font(.subheadline)
            .foregroundStyle(doquizTextColor)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(doquizPanelBackgroundColor, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("quiz_unavailable_guide")
    }
}

#Preview {
    QuizUnavailableGuidePanel(guide: "いまはクイズを出せません\nクイズを作る Apple Intelligence がオフになっています")
        .padding(20)
}
