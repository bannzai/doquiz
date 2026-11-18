import CoreGraphics
import Testing

@testable import Doquiz

/// Vision を使う `VisionPageTextExtractor` が、文を描いた画像から、描いた文を本文として返すことを確かめる。
struct VisionPageTextExtractorTests {
    /// 横書きの日本語 2 行を描いた画像から、描いた 2 行が上から順に返ることを確かめる。
    @Test func 横書きの日本語の画像から描いた文が返る() async throws {
        #expect(
            try await VisionPageTextExtractor().extractPageText(
                image: renderTextImage(
                    text: "今日は図書館で本を読みました。\n明日は公園を散歩します。",
                    isVertical: false,
                    fontSize: 40,
                    originInImage: CGPoint(x: 60, y: 200),
                    frameSize: CGSize(width: 666, height: 1300)
                )
            ) == "今日は図書館で本を読みました。\n明日は公園を散歩します。"
        )
    }

    /// 縦書きの日本語 2 行を描いた画像から、描いた 2 行が右の行から順 (読む順) に返ることを確かめる。
    @Test func 縦書きの日本語の画像から描いた文が読む順に返る() async throws {
        #expect(
            try await VisionPageTextExtractor().extractPageText(
                image: renderTextImage(
                    text: "今日は図書館で本を読みました。\n明日は公園を散歩します。",
                    isVertical: true,
                    fontSize: 40,
                    originInImage: CGPoint(x: 60, y: 200),
                    frameSize: CGSize(width: 666, height: 1300)
                )
            ) == "今日は図書館で本を読みました。\n明日は公園を散歩します。"
        )
    }

    /// 文字の無い画像からは、空の本文が返ることを確かめる。
    @Test func 文字の無い画像からは空の本文が返る() async throws {
        #expect(
            try await VisionPageTextExtractor().extractPageText(
                image: renderTextImage(
                    text: "",
                    isVertical: false,
                    fontSize: 40,
                    originInImage: CGPoint(x: 60, y: 200),
                    frameSize: CGSize(width: 666, height: 1300)
                )
            ) == ""
        )
    }

    /// 上端に時刻、下端に読んだ割合を描いた画像から、その 2 行を除いた本文だけが返ることを確かめる。
    @Test func 上端の時刻と下端の割合は本文に入らない() async throws {
        #expect(
            try await VisionPageTextExtractor().extractPageText(
                image: renderTextImage(
                    text: "12:34\n\n今日は図書館で本を読みました。\n明日は公園を散歩します。\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n45%",
                    isVertical: false,
                    fontSize: 40,
                    originInImage: CGPoint(x: 60, y: 20),
                    frameSize: CGSize(width: 666, height: 1664)
                )
            ) == "今日は図書館で本を読みました。\n明日は公園を散歩します。"
        )
    }
}
