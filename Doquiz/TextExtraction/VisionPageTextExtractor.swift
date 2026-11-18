import CoreGraphics
import Foundation
import Vision

/// Vision の文字認識で本文を抽出する、実物の `PageTextExtractor`。認識は端末の中で行う。
nonisolated struct VisionPageTextExtractor: PageTextExtractor {
    /// `image` の文字を日本語として認識し、本文でない行 (`isNonBodyLine`) を除いて、Vision が返した順に改行でつないで返す。
    ///
    /// 縦書きの画像は回さずにそのまま渡す。日本語を指定した Vision は縦書きの行を右から左の順 (読む順) で返すため
    /// (GitHub Actions の iOS Simulator で実測。https://github.com/bannzai/doquiz/pull/26 )。
    /// 認識する言語の既定は英語だけで、日本語を指定しないと日本語の行は 1 行も返らない (同じ実測)。
    func extractPageText(image: CGImage) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "ja-JP")]
        return try await request.perform(on: image, orientation: nil)
            .filter { !isNonBodyLine(transcript: $0.transcript, boundingBox: $0.boundingBox.cgRect) }
            .map(\.transcript)
            .joined(separator: "\n")
    }
}
