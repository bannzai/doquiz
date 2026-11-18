import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// テストに使う画像の大きさ。iPhone の縦の画面に近い比率にしている (幅 1179 × 高さ 2556 の約 2/3)。
nonisolated let textImageSize = CGSize(width: 786, height: 1704)

/// 白い背景に黒い文字で `text` を描いた画像を返す。
///
/// テストに渡す画像を、実際の本の画面を使わずに用意するためのもの。
/// `isVertical` が true の時は、縦書き (行が右から左へ進み、句読点が縦書きの形になる) で描く。
/// `originInImage` は文字を描く枠の左下の位置、`frameSize` は枠の大きさで、どちらも画像の左下を原点にした画素の単位。
nonisolated func renderTextImage(
    text: String,
    isVertical: Bool,
    fontSize: CGFloat,
    originInImage: CGPoint,
    frameSize: CGSize
) -> CGImage {
    let context = CGContext(
        data: nil,
        width: Int(textImageSize.width),
        height: Int(textImageSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(origin: .zero, size: textImageSize))
    CTFrameDraw(
        CTFramesetterCreateFrame(
            CTFramesetterCreateWithAttributedString(
                NSAttributedString(
                    string: text,
                    attributes: [
                        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("HiraginoSans-W3" as CFString, fontSize, nil),
                        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1),
                        NSAttributedString.Key(kCTVerticalFormsAttributeName as String): isVertical,
                    ]
                )
            ),
            CFRange(location: 0, length: 0),
            CGPath(rect: CGRect(origin: originInImage, size: frameSize), transform: nil),
            [
                kCTFrameProgressionAttributeName as String: NSNumber(
                    value: (isVertical ? CTFrameProgression.rightToLeft : CTFrameProgression.topToBottom).rawValue
                )
            ] as CFDictionary
        ),
        context
    )
    return context.makeImage()!
}

/// `image` を PNG のデータにして返す。テスト結果に画像を添付して、描いた画像を目で確かめるためのもの。
nonisolated func pngData(image: CGImage) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
}
