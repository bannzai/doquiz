import SwiftData
import SwiftUI

/// 読む本を選ぶ画面。登録済みの本の一覧と、新しい本を登録する入口を出す。アプリを開いた直後に出る。
///
/// 本を選んだ時に本の画面へ進むため、`NavigationStack` の中に置く。
struct BookListView: View {
    /// 登録済みの本。登録が新しい順に並べる。
    @Query(sort: \Book.createdDateTime, order: .reverse) private var books: [Book]
    /// 本を登録する画面を出しているか。
    @State private var isRegisteringBook = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "何を読みますか")
                            .font(.largeTitle.bold())
                            .foregroundStyle(doquizTextColor)
                        Text(verbatim: "読む本を選ぶと読書を始められます")
                            .font(.subheadline)
                            .foregroundStyle(doquizSecondaryTextColor)
                    }
                    if books.isEmpty {
                        Text(verbatim: "まだ本がありません\n最初に読む本を登録しましょう")
                            .font(.body)
                            .foregroundStyle(doquizSecondaryTextColor)
                            .accessibilityIdentifier("book_list_empty_guide")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(books) { book in
                                NavigationLink(value: book) {
                                    bookRow(book: book)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("book_list_row")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            Button {
                isRegisteringBook = true
            } label: {
                Text(verbatim: books.isEmpty ? "最初の本を登録する" : "新しい本を登録する")
                    .font(.headline)
                    .foregroundStyle(doquizAccentColor)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizAccentColor, lineWidth: 1.5))
            }
            .accessibilityIdentifier("book_registration_entrance")
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(doquizBackgroundColor)
        .navigationDestination(for: Book.self) { book in
            BookView(book: book)
        }
        .sheet(isPresented: $isRegisteringBook) {
            BookRegistrationView()
        }
    }

    /// 一覧の本 1 冊分の行。本の名前と、読書の回数・最後に読んだ時期を出す。
    private func bookRow(book: Book) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: book.title)
                .font(.headline)
                .foregroundStyle(doquizTextColor)
                .multilineTextAlignment(.leading)
            Text(verbatim: bookReadingSummary(book: book, currentDateTime: Date()))
                .font(.subheadline)
                .foregroundStyle(doquizSecondaryTextColor)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizBorderColor, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        BookListView()
    }
    .modelContainer(for: Book.self, inMemory: true)
}
