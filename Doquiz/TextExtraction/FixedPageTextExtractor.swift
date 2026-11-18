import CoreGraphics

/// 画像の中身を読まずに、あらかじめ決めた本文を返す偽の `PageTextExtractor`。
///
/// 文字認識を動かさずに、本文を受け取る側 (保存・クイズ) を確かめるテストと Preview で使う。
nonisolated struct FixedPageTextExtractor: PageTextExtractor {
    /// どの画像を渡されても返す本文。
    let pageText: String

    /// `image` を読まずに `pageText` を返す。エラーは投げない。
    func extractPageText(image: CGImage) async throws -> String {
        ""
    }
}
