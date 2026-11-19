import SwiftData
import SwiftUI

/// クイズの画面。読書を終えた後に、読んだ範囲から問いを作って 1 問ずつ出し、答えるたびに判定・模範の答え・根拠にした本文の引用を出す。
///
/// 本の画面の上に、画面全体を覆って出す。問いを作っている間は待っていることを出し、問いが 1 問も無い時・端末内のモデルが使えない時・
/// 問いを作れなかった時は、その案内と本の画面に戻る操作を出す。
struct QuizView: View {
    /// 読んだ本。出題の設定と、前の読書のページの本文を読む。
    let book: Book
    /// 終えた読書の記録。作った問いを付ける。
    let readingSession: ReadingSession
    /// 問いを作り、回答を判定する操作。
    let quizEngine: any QuizEngine
    /// クイズを終えて本の画面に戻る時に呼ぶ操作。
    let endQuiz: () -> Void
    /// 問いと回答を保存する、アプリの保存先の context。
    @Environment(\.modelContext) private var modelContext
    /// 作って保存した問い。出す順。作っている途中と、問いを出さない時 (1 問も無い・作れなかった) は nil。nil でない時は 1 問以上ある。
    @State private var questions: [Question]?
    /// クイズを出さない時 (問いが 1 問も無い・端末内のモデルが使えない) の案内。出す時と作っている途中は nil。
    @State private var noQuizGuide: String?
    /// 問いを作れなかった時の案内。失敗していなければ nil。
    @State private var preparationFailureGuide: String?
    /// 問いを作り始めた回数。「もう一度作る」で増やし、作る処理を動かし直す。
    @State private var preparationCount = 0
    /// 今出している問いの、`questions` の中の位置。
    @State private var questionIndex = 0

    var body: some View {
        Group {
            if let questions, questions.indices.contains(questionIndex) {
                QuizQuestionView(
                    question: questions[questionIndex],
                    position: (index: questionIndex, count: questions.count),
                    quizEngine: quizEngine,
                    nextButtonTitle: questionIndex + 1 < questions.count ? "次の問いへ" : "クイズを終える",
                    goNext: {
                        advance(questions: questions)
                    },
                    leaveButtonTitle: "本の画面に戻る",
                    leave: endQuiz,
                    // クイズは最後の問いに答えるまで続け、途中でやめる操作を置かない (`documents/DIRECTION.md`「決めたこと」の 2026-11-19 の行)。
                    canLeaveBeforeAnswering: false
                )
                // 次の問いに進んだ時に、前の問いの答えの入力・保存した回答・送った位置を残さず作り直す。
                .id(questions[questionIndex].id)
            } else if let noQuizGuide {
                guideContent(guide: noQuizGuide, canRetry: false)
            } else if let preparationFailureGuide {
                guideContent(guide: preparationFailureGuide, canRetry: true)
            } else {
                preparingContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(doquizBackgroundColor)
        // 下へ引いて閉じると、どこまで答えたかに関わらず本の画面に戻ってしまうため、閉じる操作を画面のボタンだけにする。
        .interactiveDismissDisabled()
        .task(id: preparationCount) {
            await prepareQuiz()
        }
    }

    /// 問いを作っている間の表示。
    private var preparingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(doquizAccentColor)
            Text(verbatim: "クイズを作っています")
                .font(.title3.bold())
                .foregroundStyle(doquizTextColor)
                .accessibilityIdentifier("quiz_preparing")
            Text(verbatim: "読んだ範囲から問いを作ります\nこのままお待ちください")
                .font(.subheadline)
                .foregroundStyle(doquizSecondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    /// クイズを出さない時の表示。案内の文と「本の画面に戻る」を出し、`canRetry` が true の時は「もう一度作る」も出す。
    private func guideContent(guide: String, canRetry: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer(minLength: 0)
            Text(verbatim: guide)
                .font(.title3.bold())
                .foregroundStyle(doquizTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("quiz_guide")
            Text(verbatim: "読書の記録は残っています")
                .font(.subheadline)
                .foregroundStyle(doquizSecondaryTextColor)
            Spacer(minLength: 0)
            if canRetry {
                Button {
                    preparationFailureGuide = nil
                    preparationCount += 1
                } label: {
                    Text(verbatim: "もう一度作る")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(doquizAccentColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("quiz_retry")
            }
            leaveButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(20)
    }

    /// クイズをやめて本の画面に戻るボタン。
    private var leaveButton: some View {
        Button {
            endQuiz()
        } label: {
            Text(verbatim: "本の画面に戻る")
                .font(.headline)
                .foregroundStyle(doquizAccentColor)
                .frame(maxWidth: .infinity, minHeight: 54)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizAccentColor, lineWidth: 1.5))
        }
        .accessibilityIdentifier("quiz_leave")
    }

    /// 問いを作って保存し、最初の問いを出す。問いが 1 問も無い時・端末内のモデルが使えない時・失敗した時は、その案内を出す。
    ///
    /// 既に問いを作り終えている時と、クイズを出さないと決まった後は何もしない (画面が出直した時に、問いを 2 回作らないため)。
    /// この画面が閉じて取り消された時は、何も出さずに終わる。
    private func prepareQuiz() async {
        guard questions == nil, noQuizGuide == nil, preparationFailureGuide == nil else {
            return
        }
        do {
            let madeQuestions = try await makeQuizQuestions(
                book: book,
                readingSession: readingSession,
                quizEngine: quizEngine,
                modelContext: modelContext,
                save: modelContext.save
            )
            if madeQuestions.isEmpty {
                noQuizGuide = quizNoQuestionsGuide(capturedPageCount: readingSession.capturedPages.count)
            } else {
                questions = madeQuestions
            }
        } catch is QuizModelUnavailableError {
            noQuizGuide = quizModelUnavailableGuide
        } catch is CancellationError {
            return
        } catch {
            preparationFailureGuide = quizPreparationFailureGuide(error: error)
        }
    }

    /// 次の問いを出す。今の問いが最後の時は、クイズを終えて本の画面に戻る。
    private func advance(questions: [Question]) {
        guard questionIndex + 1 < questions.count else {
            endQuiz()
            return
        }
        questionIndex += 1
    }
}
