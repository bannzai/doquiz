import CoreGraphics
import Foundation
import ImageIO
import Testing
import Vision

/// GitHub Actions の iOS Simulator で Vision の文字認識がどう動くかを実測する、一時的なテスト。
/// 結果を読んだら消す。
struct VisionExperimentTests {
    /// 画像と設定の組ごとに Vision の結果を集めて、添付・標準出力・失敗の文の 3 つの経路で出す。
    @Test func visionの文字認識の実測() async {
        let horizontalImage = renderTextImage(
            text: "今日は図書館で本を読みました。\n明日は公園を散歩します。",
            isVertical: false,
            fontSize: 40,
            originInImage: CGPoint(x: 60, y: 200),
            frameSize: CGSize(width: 666, height: 1300)
        )
        let verticalImage = renderTextImage(
            text: "今日は図書館で本を読みました。\n明日は公園を散歩します。",
            isVertical: true,
            fontSize: 40,
            originInImage: CGPoint(x: 60, y: 200),
            frameSize: CGSize(width: 666, height: 1300)
        )
        let pageLikeImage = renderTextImage(
            text: "12:34\n\n今日は図書館で本を読みました。\n明日は公園を散歩します。\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n45%",
            isVertical: false,
            fontSize: 40,
            originInImage: CGPoint(x: 60, y: 20),
            frameSize: CGSize(width: 666, height: 1664)
        )
        Attachment.record(pngData(image: horizontalImage), named: "experiment-horizontal.png")
        Attachment.record(pngData(image: verticalImage), named: "experiment-vertical.png")
        Attachment.record(pngData(image: pageLikeImage), named: "experiment-page-like.png")

        var report = "supportedRecognitionLanguages(default): \(RecognizeTextRequest().supportedRecognitionLanguages.map(\.maximalIdentifier))\n"
        report += "default recognitionLanguages: \(RecognizeTextRequest().recognitionLanguages.map(\.maximalIdentifier))\n"

        let japanese = Locale.Language(identifier: "ja-JP")
        for (imageName, image) in [
            ("horizontal", horizontalImage),
            ("vertical", verticalImage),
            ("pageLike", pageLikeImage),
            (
                "blank",
                renderTextImage(
                    text: "",
                    isVertical: false,
                    fontSize: 40,
                    originInImage: CGPoint(x: 60, y: 200),
                    frameSize: CGSize(width: 666, height: 1300)
                )
            ),
        ] as [(String, CGImage)] {
            for (settingName, languages, detectsLanguage, orientation) in [
            ("default", nil, false, nil),
            ("ja", [japanese], false, nil),
            ("ja+en", [japanese, Locale.Language(identifier: "en-US")], false, nil),
            ("ja+autodetect", [japanese], true, nil),
            ("ja+orientation.right", [japanese], false, .right),
            ("ja+orientation.left", [japanese], false, .left),
            ] as [(String, [Locale.Language]?, Bool, CGImagePropertyOrientation?)] {
                var request = RecognizeTextRequest()
                request.recognitionLevel = .accurate
                if let languages {
                    request.recognitionLanguages = languages
                }
                request.automaticallyDetectsLanguage = detectsLanguage
                report += "== \(imageName) / \(settingName)\n"
                do {
                    let observations = try await request.perform(on: image, orientation: orientation)
                    report += "count: \(observations.count)\n"
                    for observation in observations {
                        report += "- transcript: \(observation.transcript) | direction: \(String(describing: observation.textDirection)) | box: \(observation.boundingBox.cgRect) | confidence: \(String(describing: observation.topCandidates(1).first?.confidence))\n"
                    }
                } catch {
                    report += "error: \(error)\n"
                }
            }
        }
        print("VISION_EXPERIMENT_BEGIN\n\(report)VISION_EXPERIMENT_END")
        Attachment.record(report, named: "experiment-report.txt")
        Issue.record("VISION_EXPERIMENT_REPORT\n\(report)")
    }
}
