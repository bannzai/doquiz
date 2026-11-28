import SwiftUI

/// 読書中の画面。取り込み中であること、読んでいる本の名前、読んだ時間、本文の扱いの説明、「読書を終える」を出す。
///
/// 本の画面の上に、画面全体を覆って出す。閉じる操作は「読書を終える」だけにする。
struct ReadingView: View {
    /// 読んでいる本。
    let book: Book
    /// 続いている読書の記録。
    let readingSession: ReadingSession
    /// 「読書を終える」を押した時に呼ぶ操作。
    let endReading: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                Circle()
                    .fill(doquizCapturingColor)
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text(verbatim: "取り込み中")
                    .font(.subheadline.bold())
                    .foregroundStyle(doquizCapturingColor)
                    .accessibilityIdentifier("reading_capturing_indicator")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "読んでいる本")
                    .font(.subheadline)
                    .foregroundStyle(doquizSecondaryTextColor)
                Text(verbatim: book.title)
                    .font(.title.bold())
                    .foregroundStyle(doquizTextColor)
                    .accessibilityIdentifier("reading_book_title")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "読んだ時間")
                    .font(.footnote)
                    .foregroundStyle(doquizSecondaryTextColor)
                // 表示が分の単位のため、読書を始めた時刻から 60 秒ごとに書き直す。
                TimelineView(.periodic(from: readingSession.startedDateTime, by: 60)) { timeline in
                    Text(verbatim: readingElapsedTimeText(startedDateTime: readingSession.startedDateTime, currentDateTime: timeline.date))
                        .font(.largeTitle.bold())
                        .foregroundStyle(doquizTextColor)
                        .accessibilityIdentifier("reading_elapsed_time")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizBorderColor, lineWidth: 1))
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: "読書アプリに切り替えて読んでください")
                    .font(.subheadline.bold())
                    .foregroundStyle(doquizTextColor)
                Text(verbatim: "ページが変わるたびに本文だけを残します")
                Text(verbatim: "画面の画像は保存しません")
                Text(verbatim: "本文をサーバーに送りません")
            }
            .font(.subheadline)
            .foregroundStyle(doquizSecondaryTextColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(doquizPanelBackgroundColor, in: RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: "読み終えたらここに戻ってください")
                    .font(.footnote)
                    .foregroundStyle(doquizSecondaryTextColor)
                Button {
                    endReading()
                } label: {
                    Text(verbatim: "読書を終える")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: doquizLargeButtonMinHeight)
                        .background(doquizAccentColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("reading_end")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .background(doquizBackgroundColor)
        // 「読書を終える」を押さずに閉じると、取り込みが続いたまま画面だけが消えるため、下へ引いて閉じる操作を止める。
        .interactiveDismissDisabled()
    }
}
