import SwiftData
import SwiftUI

/// 履歴の画面。本ごとに、読書の記録を新しい順に並べ、読書の記録ごとの問いと、いちばん新しい回答の判定を出す。
///
/// 問いにもう一度答える操作、読書の記録の中身の画面への入口、本を消す操作を持つ。
/// 本の画面の上に、画面全体を覆って出す。読書の記録の中身の画面へ進むための `NavigationStack` を中に持つ。
struct HistoryView: View {
    /// 履歴を出す本。
    let book: Book
    /// 答え直しの回答を判定する `QuizEngine` を作る操作。答え直しを始める時に呼ぶ。
    let makeQuizEngine: () -> any QuizEngine
    /// 履歴を閉じて本の画面に戻る時に呼ぶ操作。
    let close: () -> Void
    /// 本を消した後に呼ぶ操作。呼び出し側は、履歴と本の画面を閉じて、消した本の値を読まないようにする。
    let leaveDeletedBook: () -> Void
    /// 回答と削除を保存する、アプリの保存先の context。
    @Environment(\.modelContext) private var modelContext
    /// この本の読書の記録。新しい順。
    @Query private var readingSessions: [ReadingSession]
    /// 答え直している問い。答え直していなければ nil。nil でない間、答える画面をこの画面の上に出す。
    @State private var reansweringQuestion: Question?
    /// 答え直しを始めようとして始められなかった問いの `id`。その問いの下に案内を出す。無ければ nil。
    @State private var reanswerUnavailableQuestionID: UUID?
    /// 本を消す前の確認を出しているか。
    @State private var isConfirmingBookDeletion = false
    /// 本を消せなかった時の案内。失敗していなければ nil。
    @State private var bookDeletionFailureGuide: String?
    /// この画面で本を消したか。消した後は、閉じ終わるまでの間に消した本の値を読まないよう、中身を出さない。
    @State private var isBookDeleted = false

    /// `book` の読書の記録を読む条件を決めるために手で書いている (`@Query` の条件は、渡された本で決まるため)。
    init(book: Book, makeQuizEngine: @escaping () -> any QuizEngine, close: @escaping () -> Void, leaveDeletedBook: @escaping () -> Void) {
        self.book = book
        self.makeQuizEngine = makeQuizEngine
        self.close = close
        self.leaveDeletedBook = leaveDeletedBook
        _readingSessions = Query(historyReadingSessionsDescriptor(bookID: book.id))
    }

    var body: some View {
        if isBookDeleted {
            doquizBackgroundColor.ignoresSafeArea()
        } else {
            NavigationStack {
                historyContent
                    .navigationDestination(for: ReadingSession.self) { readingSession in
                        ReadingSessionHistoryView(readingSession: readingSession)
                    }
            }
            .tint(doquizAccentColor)
        }
    }

    /// 履歴の中身。見出し、読書の記録ごとの問い、本を消すボタン。
    private var historyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "履歴")
                        .font(.title.bold())
                        .foregroundStyle(doquizTextColor)
                    Text(verbatim: book.title)
                        .font(.subheadline)
                        .foregroundStyle(doquizSecondaryTextColor)
                        .accessibilityIdentifier("history_book_title")
                }
                if readingSessions.isEmpty {
                    Text(verbatim: "まだ読書の記録がありません")
                        .font(.body)
                        .foregroundStyle(doquizSecondaryTextColor)
                        .accessibilityIdentifier("history_empty_guide")
                }
                ForEach(readingSessions) { readingSession in
                    readingSessionSection(readingSession: readingSession)
                }
                if let bookDeletionFailureGuide {
                    Text(verbatim: bookDeletionFailureGuide)
                        .font(.footnote)
                        .foregroundStyle(doquizIncorrectColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("history_book_deletion_failure_guide")
                }
                Button {
                    isConfirmingBookDeletion = true
                } label: {
                    Text(verbatim: "この本と読書の記録を消す")
                        .font(.subheadline.bold())
                        .foregroundStyle(doquizDestructiveColor)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizBorderColor, lineWidth: 1))
                }
                .accessibilityIdentifier("history_book_delete")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(doquizBackgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    close()
                } label: {
                    Text(verbatim: "本の画面に戻る")
                }
                .accessibilityIdentifier("history_close")
            }
        }
        .alert(
            Text(verbatim: "この本と読書の記録を消しますか"),
            isPresented: $isConfirmingBookDeletion,
            actions: {
                Button(role: .destructive) {
                    deleteBookAndLeave()
                } label: {
                    Text(verbatim: "消す")
                }
                Button(role: .cancel) {
                } label: {
                    Text(verbatim: "消さない")
                }
            },
            message: {
                Text(verbatim: historyBookDeletionWarning(book: book))
            }
        )
        .fullScreenCover(item: $reansweringQuestion) { question in
            QuizQuestionView(
                question: question,
                position: nil,
                quizEngine: makeQuizEngine(),
                nextButtonTitle: "履歴に戻る",
                goNext: {
                    reansweringQuestion = nil
                },
                leaveButtonTitle: "答えずに履歴に戻る",
                leave: {
                    reansweringQuestion = nil
                },
                // 履歴の答え直しは利用者が自分で始めるもので、始めた後にやめられるようにする。
                canLeaveBeforeAnswering: true
            )
            // 下へ引いて閉じる操作を置かず、閉じる操作を画面のボタンだけにする (`QuizView` と同じ)。
            .interactiveDismissDisabled()
        }
    }

    /// 読書の記録 1 件分の表示。読んだ日時とページの数・問いの数 (押すと読書の記録の中身の画面へ進む) と、その読書の問い。
    private func readingSessionSection(readingSession: ReadingSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: readingSession) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: historyDateTimeText(dateTime: readingSession.startedDateTime, timeZone: .current) + " の読書")
                        .font(.headline)
                        .foregroundStyle(doquizTextColor)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(verbatim: historyReadingSessionCountsText(readingSession: readingSession))
                        .font(.footnote)
                        .foregroundStyle(doquizSecondaryTextColor)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(doquizAccentColor)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("history_reading_session")
            ForEach(historyQuestions(readingSession: readingSession)) { question in
                questionCard(question: question)
            }
        }
    }

    /// 問い 1 問分の表示。問いの文、いちばん新しい回答の判定 (まだ答えていない問いはその旨)、答え直しを始めるボタン。
    private func questionCard(question: Question) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: question.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(doquizTextColor)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("history_question_text")
            HStack {
                Text(verbatim: historyLatestJudgement(question: question).text)
                    .font(.footnote.bold())
                    .foregroundStyle(judgementColor(isCorrect: historyLatestJudgement(question: question).isCorrect))
                    .accessibilityIdentifier("history_question_judgement")
                Spacer()
                Button {
                    beginReanswering(question: question)
                } label: {
                    Text(verbatim: historyReanswerButtonTitle(question: question))
                        .font(.footnote.bold())
                        .foregroundStyle(doquizAccentColor)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("history_reanswer")
            }
            if reanswerUnavailableQuestionID == question.id {
                Text(verbatim: historyReanswerUnavailableGuide)
                    .font(.footnote)
                    .foregroundStyle(doquizIncorrectColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("history_reanswer_unavailable_guide")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizBorderColor, lineWidth: 1))
    }

    /// 判定の文の色を返す。合っている時・合っていない時・まだ答えていない時 (nil) で分ける。
    private func judgementColor(isCorrect: Bool?) -> Color {
        switch isCorrect {
        case .some(true):
            doquizCorrectColor
        case .some(false):
            doquizIncorrectColor
        case .none:
            doquizSecondaryTextColor
        }
    }

    /// `question` の答え直しを始める。穴埋めと記述で端末内のモデルが使えない時は、始めずにその案内を出す。
    private func beginReanswering(question: Question) {
        guard historyCanReanswer(questionKind: question.kind, availability: makeQuizEngine().availability) else {
            reanswerUnavailableQuestionID = question.id
            return
        }
        reanswerUnavailableQuestionID = nil
        reansweringQuestion = question
    }

    /// 本を消して、履歴と本の画面を閉じる。消せなかった時は、閉じずに案内を出す。
    private func deleteBookAndLeave() {
        do {
            try deleteBook(book: book, modelContext: modelContext, save: modelContext.save)
        } catch {
            bookDeletionFailureGuide = "本を消せませんでした\n\(error)"
            return
        }
        isBookDeleted = true
        leaveDeletedBook()
    }
}
