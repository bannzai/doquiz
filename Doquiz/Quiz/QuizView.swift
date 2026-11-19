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
    /// 穴埋めと記述の入力欄に書いている答え。
    @State private var draftAnswerText = ""
    /// 今出している問いへの、保存した回答。答える前は nil。
    @State private var answer: Answer?
    /// 答えを判定して保存している途中か。
    @State private var isJudging = false
    /// 答えの判定か保存に失敗した時の案内。失敗していなければ nil。
    @State private var answerFailureGuide: String?
    /// 答えの入力欄にキーボードの入力先があるか。答えた時にキーボードを閉じるのに使う。
    @FocusState private var isAnswerFieldFocused: Bool

    var body: some View {
        Group {
            if let questions, questions.indices.contains(questionIndex) {
                questionContent(questions: questions, question: questions[questionIndex])
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

    /// 問い 1 問の表示。上に何問目かと問いの種類、問いの文、答える場所、答えた後は判定・模範の答え・根拠にした本文の引用を出す。
    private func questionContent(questions: [Question], question: Question) -> some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(verbatim: "問い \(questionIndex + 1) / \(questions.count)")
                            .accessibilityIdentifier("quiz_position")
                        Spacer()
                        Text(verbatim: questionKindLabel(questionKind: question.kind))
                            .accessibilityIdentifier("quiz_kind")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(doquizSecondaryTextColor)
                    HStack(spacing: 6) {
                        ForEach(questions.indices, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index <= questionIndex ? doquizAccentColor : doquizBorderColor)
                                .frame(height: 4)
                        }
                    }
                    .accessibilityHidden(true)
                    Text(verbatim: question.text)
                        .font(.title3.bold())
                        .foregroundStyle(doquizTextColor)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("quiz_question_text")
                    switch question.kind {
                    case .comprehension, .summaryTrueFalse:
                        choiceButtons(question: question)
                    case .fillInTheBlank, .written:
                        answerField(question: question)
                    }
                    if isJudging {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(verbatim: "判定しています")
                                .font(.subheadline)
                                .foregroundStyle(doquizSecondaryTextColor)
                                .accessibilityIdentifier("quiz_judging")
                        }
                    }
                    if let answerFailureGuide {
                        Text(verbatim: answerFailureGuide)
                            .font(.footnote)
                            .foregroundStyle(doquizIncorrectColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("quiz_answer_failure_guide")
                    }
                    if let answer {
                        answerResult(question: question, answer: answer)
                            .id(answer.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            // 答えた後の判定・模範の答え・根拠の引用が画面の下に隠れないよう、出た時にそこまで送る。
            .onChange(of: answer?.id) { _, answerID in
                if let answerID {
                    withAnimation {
                        scrollViewProxy.scrollTo(answerID, anchor: .bottom)
                    }
                }
            }
        }
        // 次の問いに進んだ時に、前の問いで送った位置を残さず上から出す。
        .id(question.id)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if answer != nil {
                    Button {
                        advance(questions: questions)
                    } label: {
                        Text(verbatim: questionIndex + 1 < questions.count ? "次の問いへ" : "クイズを終える")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(doquizAccentColor, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityIdentifier("quiz_next")
                } else {
                    if question.choices.isEmpty {
                        Button {
                            submitAnswer(question: question, answerText: draftAnswerText)
                        } label: {
                            Text(verbatim: "答える")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(doquizAccentColor, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isJudging || draftAnswerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("quiz_answer_submit")
                    }
                    // 判定か保存が失敗し続ける時に、クイズの画面から出られなくならないようにする。
                    if answerFailureGuide != nil {
                        leaveButton
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(doquizBackgroundColor)
        }
    }

    /// 四択と要約の正誤の、選択肢のボタン。押すとその選択肢で答える。答えた後は、選んだ選択肢を判定の色の枠で示す。
    private func choiceButtons(question: Question) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                Button {
                    submitAnswer(question: question, answerText: choice)
                } label: {
                    Text(verbatim: choice)
                        .font(.subheadline.weight(answer?.text == choice ? .bold : .regular))
                        .foregroundStyle(answer?.text == choice ? doquizTextColor : doquizSecondaryTextColor)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            choiceBorderColor(choice: choice).opacity(answer?.text == choice ? 0.08 : 0),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(choiceBorderColor(choice: choice), lineWidth: answer?.text == choice ? 2 : 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                // 押せなくする時に `disabled` を使うと選択肢の文字が薄くなって読みにくいため、押す操作だけを受け取らないようにする。
                .allowsHitTesting(answer == nil && !isJudging)
                .accessibilityAddTraits(answer?.text == choice ? .isSelected : [])
                .accessibilityIdentifier("quiz_choice_\(choiceIndex)")
            }
        }
    }

    /// 選択肢の枠の色を返す。答えた後の選んだ選択肢は判定の色、それ以外は枠の線の色。
    private func choiceBorderColor(choice: String) -> Color {
        guard let answer, answer.text == choice else {
            return doquizBorderColor
        }
        return answer.isCorrect ? doquizCorrectColor : doquizIncorrectColor
    }

    /// 穴埋めと記述の、答えを書く入力欄。答えた後は、書いた答えを出したまま変えられなくする。
    private func answerField(question: Question) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "あなたの答え")
                .font(.footnote)
                .foregroundStyle(doquizSecondaryTextColor)
            TextField(text: $draftAnswerText, axis: .vertical) {
                Text(verbatim: question.kind == .written ? "答えを文で書く" : "空欄に入る言葉")
            }
            .lineLimit(question.kind == .written ? 3...8 : 1...3)
            .font(.body)
            .foregroundStyle(doquizTextColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(doquizBorderColor, lineWidth: 1))
            .focused($isAnswerFieldFocused)
            .disabled(answer != nil || isJudging)
            .accessibilityIdentifier("quiz_answer_field")
        }
    }

    /// 答えた後に出す、判定・模範の答え・根拠にした本文の引用。
    ///
    /// 根拠にした本文の引用だけ明朝にする (アプリの文と本の文を見分けるため。`documents/DIRECTION.md`「デザインの方向」)。
    private func answerResult(question: Question, answer: Answer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: quizJudgementText(questionKind: question.kind, isCorrect: answer.isCorrect))
                .font(.headline)
                .foregroundStyle(answer.isCorrect ? doquizCorrectColor : doquizIncorrectColor)
                .accessibilityIdentifier("quiz_judgement")
            if let judgementCaution = quizJudgementCaution(questionKind: question.kind) {
                Text(verbatim: judgementCaution)
                    .font(.footnote)
                    .foregroundStyle(doquizSecondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("quiz_judgement_caution")
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
                    .accessibilityIdentifier("quiz_model_answer")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "根拠にした本文")
                    .font(.footnote)
                    .foregroundStyle(doquizSecondaryTextColor)
                Text(verbatim: "")
                    // iOS に入っている明朝の書体 (ヒラギノ明朝 ProN)。文字の大きさの設定に合わせて変わるよう、subheadline に合わせる。
                    .font(.custom("HiraMinProN-W6", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(doquizTextColor)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("quiz_evidence_quote")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(doquizPanelBackgroundColor, in: RoundedRectangle(cornerRadius: 12))
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

    /// `answerText` で今の問いに答える。判定して回答を保存し、判定・模範の答え・根拠の引用を出す。
    ///
    /// 既に答えた問いと、判定している途中にもう一度呼ばれた時は何もしない (1 回の答えで回答を 2 件保存しないため)。
    /// 判定か保存に失敗した時は、案内を出して、もう一度答えられる状態に戻す。
    private func submitAnswer(question: Question, answerText: String) {
        guard answer == nil, !isJudging else {
            return
        }
        isJudging = true
        answerFailureGuide = nil
        isAnswerFieldFocused = false
        Task {
            defer { isJudging = false }
            do {
                answer = try await answerQuizQuestion(
                    question: question,
                    answerText: answerText,
                    quizEngine: quizEngine,
                    modelContext: modelContext,
                    currentDateTime: { Date() },
                    save: modelContext.save
                )
            } catch {
                answerFailureGuide = quizAnswerFailureGuide(error: error)
            }
        }
    }

    /// 次の問いを出す。今の問いが最後の時は、クイズを終えて本の画面に戻る。
    private func advance(questions: [Question]) {
        guard questionIndex + 1 < questions.count else {
            endQuiz()
            return
        }
        questionIndex += 1
        answer = nil
        draftAnswerText = ""
        answerFailureGuide = nil
    }
}
