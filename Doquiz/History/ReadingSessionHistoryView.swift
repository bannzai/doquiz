import SwiftData
import SwiftUI

/// 読書の記録の中身の画面。その読書の問いと、問いごとの回答 (答えた日時・答え・判定)・模範の答え・根拠にした本文の引用、取り込んだページの本文を出す。
///
/// 読書の記録を 1 件消す操作を持つ。履歴の画面から進む。
struct ReadingSessionHistoryView: View {
    /// 中身を出す読書の記録。
    let readingSession: ReadingSession
    /// 削除を保存する、アプリの保存先の context。
    @Environment(\.modelContext) private var modelContext
    /// この画面を閉じて履歴に戻る操作。
    @Environment(\.dismiss) private var dismiss
    /// 読書の記録を消す前の確認を出しているか。
    @State private var isConfirmingDeletion = false
    /// 読書の記録を消せなかった時の案内。失敗していなければ nil。
    @State private var deletionFailureGuide: String?
    /// この画面で読書の記録を消したか。消した後は、閉じ終わるまでの間に消した読書の記録の値を読まないよう、中身を出さない。
    @State private var isDeleted = false

    var body: some View {
        ScrollView {
            if !isDeleted {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: historyDateTimeText(dateTime: readingSession.startedDateTime, timeZone: .current) + " の読書")
                            .font(.title2.bold())
                            .foregroundStyle(doquizTextColor)
                            .accessibilityIdentifier("reading_session_history_title")
                        Text(verbatim: historyReadingSessionCountsText(readingSession: readingSession))
                            .font(.subheadline)
                            .foregroundStyle(doquizSecondaryTextColor)
                            .accessibilityIdentifier("reading_session_history_counts")
                    }
                    sectionTitle(title: "問いと回答")
                    if readingSession.questions.isEmpty {
                        Text(verbatim: "この読書の問いはありません")
                            .font(.subheadline)
                            .foregroundStyle(doquizSecondaryTextColor)
                    }
                    ForEach(historyQuestions(readingSession: readingSession)) { question in
                        questionCard(question: question)
                    }
                    sectionTitle(title: "取り込んだページの本文")
                    if readingSession.capturedPages.isEmpty {
                        Text(verbatim: "取り込んだページはありません")
                            .font(.subheadline)
                            .foregroundStyle(doquizSecondaryTextColor)
                    }
                    ForEach(Array(historyCapturedPages(readingSession: readingSession).enumerated()), id: \.element.id) { pageIndex, capturedPage in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "ページ \(pageIndex + 1)")
                                .font(.footnote)
                                .foregroundStyle(doquizSecondaryTextColor)
                            Text(verbatim: capturedPage.text)
                                .font(doquizBookTextFont)
                                .foregroundStyle(doquizTextColor)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("reading_session_history_page_text")
                        }
                    }
                    if let deletionFailureGuide {
                        Text(verbatim: deletionFailureGuide)
                            .font(.footnote)
                            .foregroundStyle(doquizIncorrectColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("reading_session_deletion_failure_guide")
                    }
                    Button {
                        isConfirmingDeletion = true
                    } label: {
                        Text(verbatim: "この読書の記録を消す")
                            .font(.subheadline.bold())
                            .foregroundStyle(doquizDestructiveColor)
                            .frame(maxWidth: .infinity, minHeight: doquizLargeButtonMinHeight)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizBorderColor, lineWidth: 1))
                    }
                    .accessibilityIdentifier("reading_session_delete")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .alert(
                    Text(verbatim: "この読書の記録を消しますか"),
                    isPresented: $isConfirmingDeletion,
                    actions: {
                        Button(role: .destructive) {
                            deleteReadingSessionAndLeave()
                        } label: {
                            Text(verbatim: "消す")
                        }
                        Button(role: .cancel) {
                        } label: {
                            Text(verbatim: "消さない")
                        }
                    },
                    message: {
                        Text(verbatim: historyReadingSessionDeletionWarning(readingSession: readingSession))
                    }
                )
            }
        }
        .background(doquizBackgroundColor)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 画面の中の区切りの見出し。
    private func sectionTitle(title: String) -> some View {
        Text(verbatim: title)
            .font(.headline)
            .foregroundStyle(doquizTextColor)
    }

    /// 問い 1 問分の表示。問いの種類と文、回答 (答えた日時の古い順。まだ答えていない問いはその旨)、模範の答え、根拠にした本文の引用。
    ///
    /// 根拠にした本文の引用だけ明朝にする (アプリの文と本の文を見分けるため。`documents/DIRECTION.md`「デザインの方向」)。
    private func questionCard(question: Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: questionKindLabel(questionKind: question.kind))
                .font(.footnote.weight(.medium))
                .foregroundStyle(doquizSecondaryTextColor)
            Text(verbatim: question.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(doquizTextColor)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("reading_session_history_question_text")
            if question.answers.isEmpty {
                Text(verbatim: "まだ答えていません")
                    .font(.footnote.bold())
                    .foregroundStyle(doquizSecondaryTextColor)
                    .accessibilityIdentifier("reading_session_history_no_answer")
            }
            ForEach(historyAnswers(question: question)) { answer in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: historyDateTimeText(dateTime: answer.answeredDateTime, timeZone: .current) + " の回答")
                        .font(.footnote)
                        .foregroundStyle(doquizSecondaryTextColor)
                    Text(verbatim: answer.text)
                        .font(.subheadline)
                        .foregroundStyle(doquizTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: historyJudgementText(questionKind: question.kind, isCorrect: answer.isCorrect))
                        .font(.footnote.bold())
                        .foregroundStyle(answer.isCorrect ? doquizCorrectColor : doquizIncorrectColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(doquizPanelBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
                // 回答 1 件を 1 つの要素として読み上げ、UI テストが回答の件数を数えられるようにする。
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("reading_session_history_answer")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "模範の答え")
                    .font(.footnote)
                    .foregroundStyle(doquizSecondaryTextColor)
                Text(verbatim: question.modelAnswer)
                    .font(.subheadline)
                    .foregroundStyle(doquizTextColor)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("reading_session_history_model_answer")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "根拠にした本文")
                    .font(.footnote)
                    .foregroundStyle(doquizSecondaryTextColor)
                Text(verbatim: question.evidenceQuote)
                    .font(doquizBookTextFont)
                    .foregroundStyle(doquizTextColor)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("reading_session_history_evidence_quote")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizBorderColor, lineWidth: 1))
    }

    /// 読書の記録を消して、履歴に戻る。消せなかった時は、戻らずに案内を出す。
    private func deleteReadingSessionAndLeave() {
        do {
            try deleteReadingSession(readingSession: readingSession, modelContext: modelContext, save: modelContext.save)
        } catch {
            deletionFailureGuide = "読書の記録を消せませんでした\n\(error)"
            return
        }
        isDeleted = true
        dismiss()
    }
}
