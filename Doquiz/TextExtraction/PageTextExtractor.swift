import CoreGraphics

/// 取り込んだ画面の画像 1 枚から、ページ (その画面の本文) を抽出する操作。
///
/// 呼び出し側はこの protocol だけを使い、Vision を使う実物 (`VisionPageTextExtractor`) と、
/// 決めた本文を返す偽物 (`FixedPageTextExtractor`) を差し替える。
nonisolated protocol PageTextExtractor: Sendable {
    /// `image` に写っている本文を返す。
    ///
    /// 文字の無い画像では空の文字列を返す。文字認識が失敗した時は、そのエラーを投げる。
    /// 画像は保存せず、端末の外にも送らない。
    func extractPageText(image: CGImage) async throws -> String
}
