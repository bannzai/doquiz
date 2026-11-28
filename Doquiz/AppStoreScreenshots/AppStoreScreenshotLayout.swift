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

    /// 撮影に使う iPhone 17 の画面の幅 (pt)。枠の中の画面は、この幅で並べてから縮める。
    ///
    /// 1206 px の画像を 3 倍で描く iPhone 17 の画面の幅 (1206 / 3)。
    private let appStoreScreenshotScreenWidth: CGFloat = 402

    /// 端末の枠に入れたアプリの画面。枠の下は画像の下の端で切れる。
    ///
    /// 枠の中の幅は本物の画面より狭いため、画面は本物の幅で並べてから縮めて出す。
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
                // 画面は本物の画面の幅で並べてから、枠の中の幅に縮める。枠の中の幅で並べ直すと、本物では 1 行に収まる文が途中で切れる
                // (run 46084666530 の読書中の画面で、案内の文が「…」で切れた)。
                GeometryReader { proxy in
                    screen
                        .frame(
                            width: appStoreScreenshotScreenWidth,
                            height: proxy.size.height * appStoreScreenshotScreenWidth / proxy.size.width,
                            alignment: .top
                        )
                        .scaleEffect(proxy.size.width / appStoreScreenshotScreenWidth, anchor: .topLeading)
                }
                .clipped()
            }
            .background(doquizBackgroundColor)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 46, topTrailingRadius: 46))
            .padding([.top, .horizontal], 10)
            .background(doquizTextColor, in: UnevenRoundedRectangle(topLeadingRadius: 56, topTrailingRadius: 56))
            // 枠の左右に地の色を残して端末に見えるようにしつつ、中の画面を縮める割合をなるべく小さくする幅。
            .frame(width: 344)
        }
    }
#endif
