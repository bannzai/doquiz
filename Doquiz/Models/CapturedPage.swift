import Foundation
import SwiftData

/// ページ。読書中に取り込んだ画面 1 枚から抽出した本文。
@Model final class CapturedPage {
    /// ページを 1 件ずつ区別する値。
    @Attribute(.unique) var id: UUID
    /// 画面を取り込んだ日時。ページの並び順にも使う。
    var capturedDateTime: Date
    /// OCR で抽出した本文。
    var text: String
    /// このページを取り込んだ読書の記録。
    var readingSession: ReadingSession?

    /// 読書の記録に属するページを作る。
    init(id: UUID, capturedDateTime: Date, text: String, readingSession: ReadingSession?) {
        self.id = id
        self.capturedDateTime = capturedDateTime
        self.text = ""
        self.readingSession = readingSession
    }
}
