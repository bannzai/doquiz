import CoreGraphics

/// 画像の上端・下端から、本文でない行 (ステータスバーの時刻、ページ番号、読んだ割合) が置かれる帯の高さ。画像の高さを 1 とした割合。
///
/// iPhone のステータスバーは画面の高さの約 7% (iPhone 17 で 2622 画素のうち約 186 画素) に収まり、
/// 読書アプリのページ番号はその少し内側に出るため、余裕を足して 12% にしている。
nonisolated let nonBodyBandHeight: CGFloat = 0.12

/// 文字認識で得た 1 行が、本文でない行 (ステータスバーの時刻、ページ番号、読んだ割合) かを返す。
///
/// `transcript` は行の文字列、`boundingBox` は行を囲む枠で、画像の左下を原点に幅と高さを 1 とした座標 (Vision の `NormalizedRect` と同じ)。
/// 枠の全体が上端か下端の帯 (`nonBodyBandHeight`) に入っていて、かつ文字列の全体が時刻・数字だけ・「数字/数字」・割合の形の時だけ true を返す。
/// 位置と形の両方を見るのは、本文の中に出る数字の行と、画面の端まで続く本文を除かないため。
nonisolated func isNonBodyLine(transcript: String, boundingBox: CGRect) -> Bool {
    guard boundingBox.maxY <= nonBodyBandHeight || boundingBox.minY >= 1 - nonBodyBandHeight else {
        return false
    }
    return transcript.wholeMatch(of: #/\s*(\d{1,2}:\d{2}|\d+\s*/\s*\d+|\d+(\.\d+)?\s*%|\d+)\s*/#) != nil
}
