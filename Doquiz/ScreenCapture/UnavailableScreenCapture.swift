// 実機向けのビルドは実物 (`ScreenCaptureKitScreenCapture`) を使うため、ScreenCaptureKit が無いビルド (iOS Simulator 向け) だけに入れる。
#if !canImport(ScreenCaptureKit)
    import CoreGraphics

    /// 画面の取り込みを使えない環境の `ScreenCapture`。始めようとすると、いつも `ScreenCaptureStartError.unavailable` を投げる。
    ///
    /// iOS Simulator には ScreenCaptureKit が無く、実物をビルドに入れられないため、アプリはこれを使って「取り込みを使えない」ことを利用者に案内する。
    struct UnavailableScreenCapture: ScreenCapture {
        /// 取り込みを始めず、`ScreenCaptureStartError.unavailable` を投げる。
        func start() async throws -> AsyncThrowingStream<CGImage, any Error> {
            throw ScreenCaptureStartError.unavailable
        }

        /// 取り込みを始めることが無いため、何もしない。
        func stop() async {}
    }
#endif

/// アプリが読書で使う画面の取り込みを作る。実機向けのビルドでは実物、ScreenCaptureKit が無いビルドでは取り込みを使えないことを伝えるものを返す。
func makeScreenCapture() -> any ScreenCapture {
    #if canImport(ScreenCaptureKit)
        ScreenCaptureKitScreenCapture()
    #else
        UnavailableScreenCapture()
    #endif
}
