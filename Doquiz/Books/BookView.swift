import SwiftData
import SwiftUI

/// 本の画面。一覧で選んだ本の名前、読書の回数と最後に読んだ時期、その本の出題の設定への入口を出す。
struct BookView: View {
    /// 一覧で選んだ本。
    let book: Book
    /// 出題の設定の画面を出しているか。
    @State private var isEditingQuestionSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: book.title)
                        .font(.title.bold())
                        .foregroundStyle(doquizTextColor)
                        .accessibilityIdentifier("book_title")
                    Text(verbatim: bookReadingSummary(book: book, currentDateTime: Date()))
                        .font(.subheadline)
                        .foregroundStyle(doquizSecondaryTextColor)
                        .accessibilityIdentifier("book_reading_summary")
                }
                Button {
                    isEditingQuestionSettings = true
                } label: {
                    Text(verbatim: "出題の設定を変える")
                        .font(.headline)
                        .foregroundStyle(doquizAccentColor)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizAccentColor, lineWidth: 1.5))
                }
                .accessibilityIdentifier("question_settings_entrance")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(doquizBackgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingQuestionSettings) {
            QuestionSettingsView(book: book)
        }
    }
}
