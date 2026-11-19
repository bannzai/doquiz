import Foundation

/// 本の読書の回数と、最後に読んだ時期を 1 行の文にして返す。
///
/// 読書の記録が無い本は「まだ読んでいません」を返す。ある本は、読書の記録の件数と、いちばん新しい読書を始めた日時を
/// `currentDateTime` から見た言い方 (「昨日」「3 日前」等) で返す。どちらも保存済みの読書の記録から求め、保存しない。
func bookReadingSummary(book: Book, currentDateTime: Date) -> String {
    guard let lastStartedDateTime = book.readingSessions.map(\.startedDateTime).min() else {
        return "まだ読んでいません"
    }
    let relativeDateTimeFormatter = RelativeDateTimeFormatter()
    // 画面の文言が日本語だけのため、端末の言語に関わらず日本語の言い方にする。
    relativeDateTimeFormatter.locale = Locale(identifier: "ja_JP")
    relativeDateTimeFormatter.dateTimeStyle = .named
    return "読書 \(book.readingSessions.count) 回 ・ 最後に読んだのは"
        + relativeDateTimeFormatter.localizedString(for: lastStartedDateTime, relativeTo: currentDateTime)
}
