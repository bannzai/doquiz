import CoreGraphics
import Testing

@testable import Doquiz

/// `isNonBodyLine` が、画像の端にある時刻・ページ番号・割合だけを本文でない行と判定することを確かめる。
struct NonBodyLineTests {
    /// 上端・下端の帯にある、時刻・数字だけ・「数字/数字」・割合の行は、本文でない行と判定される。
    @Test(arguments: [
        ("12:34", CGRect(x: 0.07, y: 0.96, width: 0.15, height: 0.02)),
        ("9:05", CGRect(x: 0.07, y: 0.96, width: 0.15, height: 0.02)),
        ("45%", CGRect(x: 0.07, y: 0.08, width: 0.12, height: 0.02)),
        ("45 %", CGRect(x: 0.07, y: 0.08, width: 0.12, height: 0.02)),
        ("128", CGRect(x: 0.45, y: 0.03, width: 0.1, height: 0.02)),
        ("12/345", CGRect(x: 0.45, y: 0.03, width: 0.1, height: 0.02)),
        ("12 / 345", CGRect(x: 0.45, y: 0.03, width: 0.1, height: 0.02)),
    ])
    func 端にある時刻とページ番号と割合は本文でない(transcript: String, boundingBox: CGRect) {
        #expect(isNonBodyLine(transcript: transcript, boundingBox: boundingBox))
    }

    /// 端の帯にあっても、時刻や数字に文が続く行・文だけの行は本文として残る。
    @Test(arguments: [
        "12:34に着いた",
        "第128章",
        "今日は図書館で本を読みました。",
        "",
    ])
    func 端にあっても文を含む行は本文として残る(transcript: String) {
        #expect(!isNonBodyLine(transcript: transcript, boundingBox: CGRect(x: 0.07, y: 0.96, width: 0.5, height: 0.02)))
        #expect(!isNonBodyLine(transcript: transcript, boundingBox: CGRect(x: 0.07, y: 0.03, width: 0.5, height: 0.02)))
    }

    /// 画像の中央にある数字だけの行・時刻の行は、本文として残る。
    @Test(arguments: ["45", "12:34", "45%"])
    func 中央にある数字の行は本文として残る(transcript: String) {
        #expect(!isNonBodyLine(transcript: transcript, boundingBox: CGRect(x: 0.4, y: 0.5, width: 0.1, height: 0.02)))
    }

    /// 枠の上の辺が下端の帯の境 (高さ 0.12) にちょうど載る行は本文でない行、境を少しでも越える行は本文と判定される。
    @Test func 下端の帯の境では枠の全体が帯に入る行だけが本文でない() {
        #expect(isNonBodyLine(transcript: "45", boundingBox: CGRect(x: 0.4, y: 0, width: 0.1, height: 0.12)))
        #expect(!isNonBodyLine(transcript: "45", boundingBox: CGRect(x: 0.4, y: 0, width: 0.1, height: 0.13)))
    }

    /// 枠の下の辺が上端の帯の境 (高さ 0.88) にちょうど載る行は本文でない行、境より下に出る行は本文と判定される。
    @Test func 上端の帯の境では枠の全体が帯に入る行だけが本文でない() {
        #expect(isNonBodyLine(transcript: "45", boundingBox: CGRect(x: 0.4, y: 0.88, width: 0.1, height: 0.12)))
        #expect(!isNonBodyLine(transcript: "45", boundingBox: CGRect(x: 0.4, y: 0.87, width: 0.1, height: 0.13)))
    }
}
