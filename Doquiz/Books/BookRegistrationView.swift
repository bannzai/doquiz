import SwiftData
import SwiftUI

/// 新しい本を登録する画面。本の名前を入れて登録する。sheet で出す。
struct BookRegistrationView: View {
    /// 本を保存する、アプリの保存先の context。
    @Environment(\.modelContext) private var modelContext
    /// 登録した時とやめた時に、この画面を閉じる操作。
    @Environment(\.dismiss) private var dismiss
    /// 入力中の本の名前。
    @State private var title = ""
    /// 登録に失敗した時のエラーの内容。失敗していなければ nil。
    @State private var failureDescription: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: "本の名前")
                    .font(.subheadline)
                    .foregroundStyle(doquizSecondaryTextColor)
                TextField(text: $title) {
                    Text(verbatim: "本の名前")
                }
                .font(.body)
                .foregroundStyle(doquizTextColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(doquizBorderColor, lineWidth: 1))
                .accessibilityIdentifier("book_registration_title_field")
                if let failureDescription {
                    Text(verbatim: "登録できませんでした\n\(failureDescription)")
                        .font(.footnote)
                        .foregroundStyle(doquizSecondaryTextColor)
                        .accessibilityIdentifier("book_registration_failure_description")
                }
                Spacer()
            }
            .padding(20)
            .background(doquizBackgroundColor)
            .navigationTitle(Text(verbatim: "本の登録"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: "キャンセル")
                    }
                    .accessibilityIdentifier("book_registration_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        do {
                            if try registerBook(title: title, modelContext: modelContext, save: modelContext.save) != nil {
                                dismiss()
                            }
                        } catch {
                            failureDescription = String(describing: error)
                        }
                    } label: {
                        Text(verbatim: "登録する")
                    }
                    .disabled(registrableBookTitle(title: title) == nil)
                    .accessibilityIdentifier("book_registration_submit")
                }
            }
        }
        .tint(doquizAccentColor)
    }
}

#Preview {
    BookRegistrationView()
        .modelContainer(for: Book.self, inMemory: true)
}
