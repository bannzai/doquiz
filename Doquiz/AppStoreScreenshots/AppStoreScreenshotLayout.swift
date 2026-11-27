#if DEBUG
    import SwiftUI

    /// App Store のスクリーンショット 1 枚の型。強調の色の地に、上にキャッチコピー、下に `content` を置き、画面全体に描く。
    ///
    /// 時刻・電池の表示とホームの線を隠して、画面に出ているものだけがそのまま画像になるようにする。
    struct AppStoreScreenshotCanvas<Content: View>: View {
        /// 大きく出すキャッチコピー。改行で区切る。
        let title: String
        /// キャッチコピーの下に小さく出す補足。
        let subtitle: String
        /// キャッチコピーの下に置く絵 (端末の枠に入れたアプリの画面など)。
        @ViewBuilder let content: Content

        var body: some View {
            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    Text(verbatim: title)
                        // 1 行が 9 字ほどで 2 行に収まり、App Store の一覧で縮んでも読める大きさにしている (CI で撮った画像を見て決めた)。
                        .font(.system(size: 34, weight: .heavy))
                        .lineSpacing(6)
                        .accessibilityIdentifier("app_store_screenshot_title")
                    Text(verbatim: subtitle)
                        .font(.system(size: 17, weight: .semibold))
                        .opacity(0.85)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                // 隠した時刻・電池の表示の場所とダイナミックアイランドを避ける高さ。
                .padding(.top, 76)
                .padding(.bottom, 36)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(doquizAccentColor)
            .ignoresSafeArea()
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
        }
    }

    /// 端末の枠に入れたアプリの画面。枠の下は画像の下の端で切れる。
    ///
    /// 枠の中の幅は、本物の画面より狭い。画面は縮めずにこの幅で並べ直すため、文字は本物と同じ大きさで出る。
    struct AppStoreScreenshotDevice<Screen: View>: View {
        /// 枠の中に出すアプリの画面。
        @ViewBuilder let screen: Screen

        var body: some View {
            VStack(spacing: 0) {
                // ダイナミックアイランドの場所。時刻・電池の表示は、撮った時の時刻が写らないよう描かない。
                Capsule()
                    .fill(doquizTextColor)
                    .frame(width: 96, height: 28)
                    .frame(maxWidth: .infinity, minHeight: 50)
                screen
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
            }
            .background(doquizBackgroundColor)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 46, topTrailingRadius: 46))
            .padding([.top, .horizontal], 10)
            .background(doquizTextColor, in: UnevenRoundedRectangle(topLeadingRadius: 56, topTrailingRadius: 56))
            // 枠の左右に地の色を残して端末に見えるようにしつつ、中の画面の幅をなるべく本物 (402pt) に近づける幅。
            .frame(width: 344)
        }
    }
#endif
