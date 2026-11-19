import SwiftData
import SwiftUI

/// 出題の設定の画面。本ごとに、出題する問いの種類と、出題への希望を変えて保存する。sheet で出す。
///
/// 画面で変えた内容は、保存を押すまで本に書かない (キャンセルすると本は変わらない)。
struct QuestionSettingsView: View {
    /// 出題の設定を変える本。
    let book: Book
    /// 出題の設定を保存する、アプリの保存先の context。
    @Environment(\.modelContext) private var modelContext
    /// 保存した時とやめた時に、この画面を閉じる操作。
    @Environment(\.dismiss) private var dismiss
    /// 画面で選んでいる問いの種類。保存するまで本には書かない。
    @State private var draftQuestionKinds: Set<QuestionKind>
    /// 画面で書いている出題への希望。保存するまで本には書かない。
    @State private var draftQuestionGuidance: String
    /// 保存に失敗した時のエラーの内容。失敗していなければ nil。
    @State private var failureDescription: String?

    /// 本の今の出題の設定を、画面で変える前の内容として始める。
    ///
    /// 自動で作られる initializer では、本の値を `@State` の最初の値にできないため手で書いている。
    init(book: Book) {
        self.book = book
        _draftQuestionKinds = State(initialValue: Set(book.questionKinds))
        // 希望を書いていない本 (nil) は、入力欄を空で始める。
        _draftQuestionGuidance = State(initialValue: book.questionGuidance ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verbatim: "出題する問いの種類")
                        .font(.subheadline)
                        .foregroundStyle(doquizSecondaryTextColor)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        ForEach(QuestionKind.allCases, id: \.self) { questionKind in
                            questionKindToggle(questionKind: questionKind)
                        }
                    }
                    if draftQuestionKinds.isEmpty {
                        Text(verbatim: "問いの種類を 1 つ以上選んでください")
                            .font(.footnote)
                            .foregroundStyle(doquizSecondaryTextColor)
                            .accessibilityIdentifier("question_settings_no_kind_guide")
                    }
                    Text(verbatim: "出題への希望")
                        .font(.subheadline)
                        .foregroundStyle(doquizSecondaryTextColor)
                        .padding(.top, 8)
                    TextField(text: $draftQuestionGuidance, axis: .vertical) {
                        Text(verbatim: "出題への希望")
                    }
                    .lineLimit(3...8)
                    .font(.body)
                    .foregroundStyle(doquizTextColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(doquizBorderColor, lineWidth: 1))
                    .accessibilityIdentifier("question_settings_guidance_field")
                    if let failureDescription {
                        Text(verbatim: "保存できませんでした\n\(failureDescription)")
                            .font(.footnote)
                            .foregroundStyle(doquizSecondaryTextColor)
                            .accessibilityIdentifier("question_settings_failure_description")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(doquizBackgroundColor)
            .navigationTitle(Text(verbatim: "出題の設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: "キャンセル")
                    }
                    .accessibilityIdentifier("question_settings_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        do {
                            if try saveQuestionSettings(
                                book: book,
                                questionKinds: draftQuestionKinds,
                                questionGuidance: draftQuestionGuidance,
                                modelContext: modelContext
                            ) {
                                dismiss()
                            }
                        } catch {
                            failureDescription = String(describing: error)
                        }
                    } label: {
                        Text(verbatim: "保存")
                    }
                    .disabled(draftQuestionKinds.isEmpty)
                    .accessibilityIdentifier("question_settings_save")
                }
            }
        }
        .tint(doquizAccentColor)
    }

    /// 問いの種類 1 つ分の、選ぶ・外すを切り替えるボタン。選んでいる時は強調の色の枠とチェックの印を出す。
    private func questionKindToggle(questionKind: QuestionKind) -> some View {
        Button {
            if draftQuestionKinds.contains(questionKind) {
                draftQuestionKinds.remove(questionKind)
            } else {
                draftQuestionKinds.insert(questionKind)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: draftQuestionKinds.contains(questionKind) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(draftQuestionKinds.contains(questionKind) ? doquizAccentColor : doquizBorderColor)
                Text(verbatim: questionKindLabel(questionKind: questionKind))
                    .font(.body.weight(.medium))
                    .foregroundStyle(doquizTextColor)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(
                    draftQuestionKinds.contains(questionKind) ? doquizAccentColor : doquizBorderColor,
                    lineWidth: draftQuestionKinds.contains(questionKind) ? 1.5 : 1
                )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(draftQuestionKinds.contains(questionKind) ? .isSelected : [])
        .accessibilityIdentifier("question_settings_kind_\(questionKind.rawValue)")
    }
}
