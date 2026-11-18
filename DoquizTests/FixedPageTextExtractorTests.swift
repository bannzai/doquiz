import CoreGraphics
import Testing

@testable import Doquiz

/// 偽の `FixedPageTextExtractor` が、画像の中身に関係なく、決めた本文を返すことを確かめる。
struct FixedPageTextExtractorTests {
    /// 別の文を描いた画像を渡しても、決めた本文がそのまま返ることを確かめる。
    @Test func 画像の中身に関係なく決めた本文が返る() async throws {
        #expect(
            try await FixedPageTextExtractor(pageText: "決めた本文").extractPageText(
                image: renderTextImage(
                    text: "画像に描いた別の文",
                    isVertical: false,
                    fontSize: 40,
                    originInImage: CGPoint(x: 60, y: 200),
                    frameSize: CGSize(width: 666, height: 1300)
                )
            ) == "決めた本文"
        )
    }
}
