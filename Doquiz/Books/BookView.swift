import SwiftData
import SwiftUI

/// 本の画面。一覧で選んだ本の名前、読書の回数と最後に読んだ時期、その本の出題の設定への入口、履歴への入口、「読書を始める」を出す。
/// 端末内のモデルが使えない間は、クイズを出せないことと理由の案内を出し、「読書を始める」を押せなくする。
///
/// 「読書を始める」から「読書を終える」までの読書を動かす。初めて読書を始める時だけ同意の説明を出し、
/// 取り込みが始まると読書中の画面を上に出して、終えるとこの画面に戻る。
struct BookView: View {
    /// 一覧で選んだ本。
    let book: Book
    /// 読書の記録とページを保存する、アプリの保存先の context。
    @Environment(\.modelContext) private var modelContext
    /// この画面を閉じて本の一覧に戻る操作。履歴で本を消した後に使う。
    @Environment(\.dismiss) private var dismiss
    /// 端末内のモデルが使えない時の案内の文。使える時は nil。nil でない間は「読書を始める」を押せなくする
    /// (クイズを作れないのに画面を取り込んで本文を保存することを避けるため)。
    @Environment(\.quizUnavailableGuide) private var quizUnavailableGuide
    /// 画面の取り込みの同意の説明に同意済みか。
    /// 既定を false にしているのは、同意の説明をまだ見ていない利用者に、初めての読書の前に説明を出すため。
    @AppStorage(hasAgreedToScreenCaptureKey) private var hasAgreedToScreenCapture = false
    #if DEBUG
        /// 開発者メニューで、読書を偽の取り込みと偽の本文の抽出に切り替えているか。
        /// 既定を false にしているのは、切り替えていない開発用のビルドでは実物を使うため。
        @AppStorage(developerMenuUsesFakeReadingKey) private var usesFakeReading = false
        /// 開発者メニューで、偽の取り込みを途中で止めるようにしているか。
        /// 既定を false にしているのは、切り替えていない時の偽の取り込みを「読書を終える」まで続けるため。
        @AppStorage(developerMenuInterruptsFakeReadingKey) private var interruptsFakeReading = false
        /// 開発者メニューで、読書を終えた後のクイズを偽のクイズに切り替えている時の動き。値が無い時は実物でクイズを作る。
        @AppStorage(developerMenuFakeQuizBehaviorKey) private var fakeQuizBehavior: DeveloperMenuFakeQuizBehavior?
    #endif
    /// 出題の設定の画面を出しているか。
    @State private var isEditingQuestionSettings = false
    /// 履歴の画面を出しているか。
    @State private var isShowingHistory = false
    /// 履歴の画面で本を消したか。消した後は、この画面を閉じ終わるまでの間に消した本の値を読まないよう、中身を出さない。
    @State private var isBookDeleted = false
    /// 同意の説明を出しているか。
    @State private var isShowingScreenCaptureConsent = false
    /// 取り込みを始めている途中か (画面共有の選択画面を出している間など)。
    @State private var isStartingReading = false
    /// 読書を終えている途中か。
    @State private var isFinishingReading = false
    /// 続いている読書の記録か、クイズを出している読書の記録。読書中でもクイズ中でもなければ nil。
    /// nil でない間、読書中の画面かクイズの画面を、この画面の上に出す。
    @State private var readingSession: ReadingSession?
    /// 上に出す画面を、読書中の画面からクイズの画面に切り替えたか。「読書を終える」で読書を終えられた時に true にし、次の読書を始める時に false に戻す
    /// (クイズを終えた時に戻すと、閉じている途中の画面が読書中の画面に変わって見えるため)。
    @State private var isShowingQuiz = false
    /// 続いている読書の取り込み。読書中でなければ nil。
    @State private var screenCapture: (any ScreenCapture)?
    /// 続いている読書の、ページを足す処理を動かしているタスク。読書中でなければ nil。
    @State private var pageSaving: Task<Void, any Error>?
    /// 読書を始められなかった時・途中で止まった時・終える時に保存できなかった時の案内。案内することが無ければ nil。
    @State private var readingGuide: String?

    var body: some View {
        ScrollView {
            if !isBookDeleted {
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
                    Button {
                        isShowingHistory = true
                    } label: {
                        Text(verbatim: "この本の履歴を見る")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(doquizAccentColor)
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("history_entrance")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                if let readingGuide {
                    Text(verbatim: readingGuide)
                        .font(.footnote)
                        .foregroundStyle(doquizCapturingColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reading_guide")
                }
                if let quizUnavailableGuide {
                    QuizUnavailableGuidePanel(guide: quizUnavailableGuide)
                } else {
                    Text(verbatim: "次の画面で画面全体を選ぶと取り込みが始まります")
                        .font(.footnote)
                        .foregroundStyle(doquizSecondaryTextColor)
                }
                Button {
                    if hasAgreedToScreenCapture {
                        beginReading()
                    } else {
                        isShowingScreenCaptureConsent = true
                    }
                } label: {
                    Text(verbatim: "読書を始める")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(doquizAccentColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isStartingReading || quizUnavailableGuide != nil)
                // 押せないことが色でも分かるよう、端末内のモデルが使えない間はボタンを薄くする。
                .opacity(quizUnavailableGuide == nil ? 1 : 0.4)
                .accessibilityIdentifier("reading_start")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(doquizBackgroundColor)
        }
        .background(doquizBackgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        // 取り込みを始めている途中にこの画面を離れると、始まった取り込みを止める画面が無くなるため、始まるか始められないと分かるまで戻れなくする。
        .navigationBarBackButtonHidden(isStartingReading)
        .sheet(isPresented: $isEditingQuestionSettings) {
            QuestionSettingsView(book: book)
        }
        // 同意した時は、説明の sheet が閉じ切ってから取り込みを始める (閉じている途中に画面共有の選択画面を重ねないため)。
        .sheet(
            isPresented: $isShowingScreenCaptureConsent,
            onDismiss: {
                if hasAgreedToScreenCapture {
                    beginReading()
                }
            },
            content: {
                ScreenCaptureConsentView(
                    agree: {
                        hasAgreedToScreenCapture = true
                        isShowingScreenCaptureConsent = false
                    },
                    cancel: {
                        isShowingScreenCaptureConsent = false
                    }
                )
            }
        )
        // 本を消した時は、履歴が閉じ切ってからこの画面を閉じる (閉じている途中の覆いの下で、画面を戻さないため)。
        .fullScreenCover(
            isPresented: $isShowingHistory,
            onDismiss: {
                if isBookDeleted {
                    dismiss()
                }
            },
            content: {
                if !isBookDeleted {
                    HistoryView(
                        book: book,
                        makeQuizEngine: makeQuizEngineForReading,
                        close: {
                            isShowingHistory = false
                        },
                        leaveDeletedBook: {
                            isBookDeleted = true
                            isShowingHistory = false
                        }
                    )
                }
            }
        )
        // 同意の説明を出している間に端末内のモデルが使えなくなった時は、説明を閉じる。同意されていないまま閉じるため、読書は始まらない。
        // 同意の説明を閉じた時の処理の中で使えるかを確かめる形にしていないのは、その形では同意の後に読書が始まることを
        // UI テストで確かめたため (https://github.com/bannzai/doquiz/actions/runs/44525376320)。
        .onChange(of: quizUnavailableGuide) {
            if quizUnavailableGuide != nil {
                isShowingScreenCaptureConsent = false
            }
        }
        // 読書中の画面とクイズの画面を同じ覆いの中で切り替える (覆いを閉じてから別の覆いを出すと、間に本の画面が見えるため)。
        .fullScreenCover(item: $readingSession) { readingSession in
            ReadingAndQuizView(
                book: book,
                readingSession: readingSession,
                isShowingQuiz: $isShowingQuiz,
                makeQuizEngine: makeQuizEngineForReading,
                endReading: {
                    Task {
                        await finishReading()
                    }
                },
                endQuiz: {
                    self.readingSession = nil
                }
            )
        }
    }

    /// 読書を終えた後のクイズと、履歴の答え直しで使う `QuizEngine` を作る。開発者メニューで偽のクイズに切り替えている時は、選んだ動きをする偽のクイズを返す。
    private func makeQuizEngineForReading() -> any QuizEngine {
        #if DEBUG
            if let fakeQuizBehavior {
                return DeveloperMenuFakeQuizEngine(behavior: fakeQuizBehavior)
            }
        #endif
        return FoundationModelsQuizEngine()
    }

    /// 読書で使う画面の取り込みを作る。開発者メニューで偽の取り込みに切り替えている時は、偽の取り込みを返す。
    private func makeScreenCaptureForReading() -> any ScreenCapture {
        #if DEBUG
            if usesFakeReading {
                return makeDeveloperMenuFakeScreenCapture(interrupts: interruptsFakeReading)
            }
        #endif
        return makeScreenCapture()
    }

    /// 読書で使う本文の抽出を作る。開発者メニューで偽の取り込みに切り替えている時は、決まった本文を返す偽の抽出を返す。
    private func makePageTextExtractorForReading() -> any PageTextExtractor {
        #if DEBUG
            if usesFakeReading {
                return FixedPageTextExtractor(pageText: developerMenuFakeReadingPageText)
            }
        #endif
        return VisionPageTextExtractor()
    }

    /// 読書を始める。取り込みが始まったら読書中の画面を出し、ページを足す処理を動かす。
    ///
    /// 始められなかった時は、読書の記録を残さず、この画面に案内を出す。取り込みが途中で止まった時は、読書を終えて案内を出す。
    /// 始めている途中にもう一度呼ばれた時は何もしない。
    private func beginReading() {
        guard !isStartingReading else {
            return
        }
        isStartingReading = true
        readingGuide = nil
        let screenCapture = makeScreenCaptureForReading()
        Task {
            do {
                let startedReading = try await startReading(
                    book: book,
                    screenCapture: screenCapture,
                    modelContext: modelContext,
                    currentDateTime: { Date() },
                    save: modelContext.save
                )
                let pageSaving = Task {
                    try await saveCapturedPages(
                        capturedImages: startedReading.capturedImages,
                        readingSession: startedReading.readingSession,
                        pageTextExtractor: makePageTextExtractorForReading(),
                        modelContext: modelContext,
                        currentDateTime: { Date() },
                        pauseAfterEachImage: readingPauseAfterEachImage,
                        save: modelContext.save
                    )
                }
                self.screenCapture = screenCapture
                self.pageSaving = pageSaving
                isShowingQuiz = false
                readingSession = startedReading.readingSession
                isStartingReading = false
                do {
                    try await pageSaving.value
                } catch {
                    await finishReading()
                }
            } catch {
                readingGuide = readingStartFailureGuide(error: error)
                isStartingReading = false
            }
        }
    }

    /// 続いている読書を終えて、読書中の画面をクイズの画面に切り替える。読書中でなければ何もしない。
    ///
    /// 取り込みが途中で止まっていた時は、クイズを出さずに読書中の画面を閉じて、この画面にその案内を出す。
    /// 読書の記録を保存できなかった時も、クイズを出さずに読書中の画面を閉じて、この画面にエラーの内容を出す
    /// (取り込みは既に止まっていて、読書中の画面の「取り込み中」が事実と違う表示になるため)。
    /// 終えている途中にもう一度呼ばれた時は何もしない (後から終わった方が、先の保存の失敗の案内を消さないようにするため)。
    private func finishReading() async {
        guard !isFinishingReading, let readingSession, let screenCapture, let pageSaving else {
            return
        }
        isFinishingReading = true
        defer { isFinishingReading = false }
        do {
            readingGuide = readingEndGuide(
                pageSavingError: try await endReading(
                    readingSession: readingSession,
                    screenCapture: screenCapture,
                    pageSaving: pageSaving,
                    currentDateTime: { Date() },
                    save: modelContext.save
                )
            )
        } catch {
            readingGuide = readingEndSaveFailureGuide(error: error)
        }
        self.screenCapture = nil
        self.pageSaving = nil
        if readingGuide == nil {
            isShowingQuiz = true
        } else {
            self.readingSession = nil
        }
    }
}

/// 本の画面の上に、画面全体を覆って出す画面。読書中は読書中の画面を出し、読書を終えた後はクイズの画面に切り替える。
///
/// 切り替えを本の画面の覆いの中に直接書かず、この型で受けるのは、覆いが出ている間に変わった `isShowingQuiz` を読み直して中身を切り替えるため。
private struct ReadingAndQuizView: View {
    /// 読んでいる本。
    let book: Book
    /// 続いている読書の記録か、クイズを出している読書の記録。
    let readingSession: ReadingSession
    /// クイズの画面に切り替えたか。本の画面が、読書を終えられた時に true にする。
    @Binding var isShowingQuiz: Bool
    /// クイズで使う `QuizEngine` を作る操作。クイズの画面に切り替えた時に呼ぶ。
    let makeQuizEngine: () -> any QuizEngine
    /// 「読書を終える」を押した時に呼ぶ操作。
    let endReading: () -> Void
    /// クイズを終えて本の画面に戻る時に呼ぶ操作。
    let endQuiz: () -> Void

    var body: some View {
        if isShowingQuiz {
            QuizView(book: book, readingSession: readingSession, quizEngine: makeQuizEngine(), endQuiz: endQuiz)
        } else {
            ReadingView(book: book, readingSession: readingSession, endReading: endReading)
        }
    }
}
