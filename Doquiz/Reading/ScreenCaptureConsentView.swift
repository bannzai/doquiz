import SwiftUI

/// 画面の取り込みの同意の説明。初めて読書を始める時に 1 回だけ、sheet で出す。
/// 同意の説明の前に、同じ sheet の中で取り込みの手順の案内 (`ScreenCaptureGuideView`) を出し、「次へ」で同意の説明に進む。
///
/// 何を取り込み、何を保存し、どこへ送らないかを伝える。内容は `documents/adr/0002-on-device-only-infrastructure.md` の決定に合わせる
/// (画像は保存しない・本文をサーバーへ送らない・本文が利用者自身の端末のバックアップに入ることは妨げない)。
struct ScreenCaptureConsentView: View {
    /// 「同意して始める」を押した時に呼ぶ操作。
    let agree: () -> Void
    /// 「やめる」を押した時に呼ぶ操作。
    let cancel: () -> Void
    /// 取り込みの手順の案内を出しているか。sheet を出すたびに案内から始まる。
    @State private var isShowingGuide = false

    var body: some View {
        if isShowingGuide {
            ScreenCaptureGuideView(
                next: {
                    isShowingGuide = false
                },
                cancel: cancel
            )
        } else {
            consent
        }
    }

    /// 同意の説明の画面。
    private var consent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(verbatim: "読書を始める前に")
                    .font(.title2.bold())
                    .foregroundStyle(doquizTextColor)
                    .accessibilityIdentifier("screen_capture_consent_title")
                VStack(alignment: .leading, spacing: 14) {
                    explanation(text: "読書アプリを表示している間の画面全体を取り込みます。")
                    explanation(text: "読書中に出た通知や、途中で開いた別のアプリの画面も取り込みに入ります。")
                    explanation(text: "取り込んだ画像は保存しません。画像から抽出した本文だけを、この iPhone に保存します。")
                    explanation(text: "本文をサーバーに送りません。iPhone のバックアップを使っている場合は、保存した本文がバックアップに入ることがあります。")
                }
                Text(verbatim: "次の画面で画面全体を選ぶと取り込みが始まります")
                    .font(.footnote)
                    .foregroundStyle(doquizSecondaryTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    agree()
                } label: {
                    Text(verbatim: "同意して始める")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(doquizAccentColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("screen_capture_consent_agree")
                Button {
                    cancel()
                } label: {
                    Text(verbatim: "やめる")
                        .font(.headline)
                        .foregroundStyle(doquizAccentColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("screen_capture_consent_cancel")
            }
            .padding(20)
            .background(doquizBackgroundColor)
        }
        .background(doquizBackgroundColor)
    }

    /// 同意の説明の 1 項目。
    private func explanation(text: String) -> some View {
        Text(verbatim: text)
            .font(.body)
            .foregroundStyle(doquizTextColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}
