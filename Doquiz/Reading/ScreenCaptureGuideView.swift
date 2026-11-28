import SwiftUI

/// 画面の取り込みの手順の案内。初めて読書を始める時に、同意の説明 (`ScreenCaptureConsentView`) の前に出す。
///
/// 取り込みを始めてから終えるまでの 3 つの手順を、順番に番号を付けて見せる。
/// iOS が出す画面共有の選択画面は、この Mac でも CI の Simulator でも開けず見た目を確かめられないため、絵にせず、今の画面の文と同じ「画面全体」の語で書く。
struct ScreenCaptureGuideView: View {
    /// 「次へ」を押した時に呼ぶ操作。
    let next: () -> Void
    /// 「やめる」を押した時に呼ぶ操作。
    let cancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(verbatim: "取り込みの手順")
                    .font(.title2.bold())
                    .foregroundStyle(doquizTextColor)
                    .accessibilityIdentifier("screen_capture_guide_title")
                step(
                    number: 1,
                    systemImageName: "iphone",
                    title: "画面全体を選ぶ",
                    text: "次の説明に同意して始めると、取り込むものを選ぶ画面が出ます。画面全体を選ぶと取り込みが始まります。"
                )
                step(
                    number: 2,
                    systemImageName: "book",
                    title: "読書アプリで読む",
                    text: "読書アプリに切り替えて、いつもどおりにページをめくります。ページが変わるたびに、本文をこの iPhone に残します。"
                )
                step(
                    number: 3,
                    systemImageName: "checkmark.circle",
                    title: "doquiz に戻って終える",
                    text: "読み終えたら doquiz に戻り、「読書を終える」を押します。読んだ範囲からクイズを作ります。"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    next()
                } label: {
                    Text(verbatim: "次へ")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(doquizAccentColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("screen_capture_guide_next")
                Button {
                    cancel()
                } label: {
                    Text(verbatim: "やめる")
                        .font(.headline)
                        .foregroundStyle(doquizAccentColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("screen_capture_guide_cancel")
            }
            .padding(20)
            .background(doquizBackgroundColor)
        }
        .background(doquizBackgroundColor)
    }

    /// 手順の 1 つ。番号と絵、手順の名前、説明の文を並べる。
    private func step(number: Int, systemImageName: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .topLeading) {
                Image(systemName: systemImageName)
                    .font(.title)
                    .foregroundStyle(doquizAccentColor)
                    .frame(width: 56, height: 56)
                    .background(doquizPanelBackgroundColor, in: RoundedRectangle(cornerRadius: 14))
                Text(verbatim: "\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(doquizAccentColor, in: Circle())
                    .offset(x: -6, y: -6)
            }
            // 番号は手順の並びと同じで、読み上げでは手順の名前の順に読まれるため、絵と一緒に読み上げから外す。
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: title)
                    .font(.headline)
                    .foregroundStyle(doquizTextColor)
                Text(verbatim: text)
                    .font(.body)
                    .foregroundStyle(doquizTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
