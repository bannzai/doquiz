import CoreGraphics

/// 読書アプリを表示している間の画面の取り込み。
///
/// 呼び出し側はこの protocol だけを使い、実物 (`ScreenCaptureKitScreenCapture`) と
/// 自動テスト用の偽物 (`FakeScreenCapture`) を差し替える。
/// 取り込んだ画像はメモリの上で呼び出し側に渡すだけで、どの実装もファイルや保存データに書かない。
protocol ScreenCapture {
    /// 取り込みを始め、取り込んだ画面の画像が順に届く流れを返す。
    ///
    /// - 始められなかった時は error を投げる (利用者が選択画面を閉じた時と、端末が取り込みを使えない時は `ScreenCaptureStartError`)
    /// - 途中で止まった時は、流れが error を投げて終わる
    /// - `stop()` で止めた時は、流れが error を投げずに終わる
    ///
    /// 実物は、受け取りが遅い間に届いた画像を最新の 1 枚だけ残して捨てる
    /// (画面全体の画像がメモリに溜まり続けないようにするため)。
    /// そのため実物では、`stop()` の直前に取り込んだ 1 枚が届いてから流れが終わることがある。
    /// 取り込み中にもう一度呼ぶと、前の取り込みを止めてから始め直す。
    func start() async throws -> AsyncThrowingStream<CGImage, any Error>

    /// 取り込みを止め、`start()` が返した流れを終わらせる。始める前と止めた後に呼んでも何も起きない。
    func stop() async
}

/// 取り込みを始められなかった理由のうち、呼び出し側が利用者への案内を分けるもの。
enum ScreenCaptureStartError: Error {
    /// 端末か設定が画面の取り込みを許していない。
    case unavailable
    /// 利用者が画面共有の選択画面を、何も選ばずに閉じた。
    case selectionCancelled
}
