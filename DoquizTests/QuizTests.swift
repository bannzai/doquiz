import Foundation
import FoundationModels
import SwiftData
import Testing

@testable import Doquiz

/// 読書を終えた後のクイズの処理 (問いを作って保存する・答えを判定して回答を保存する) を、偽のクイズを使い、端末に書き込まないメモリ内の保存先で確かめる。
@MainActor struct QuizTests {
    /// クイズの処理を実行する context。
    private let writingContext: ModelContext
    /// 保存先に書かれた結果を読む context。書いた context に残っている値ではなく、保存先の値を確かめるために分ける。
    private let readingContext: ModelContext
    /// クイズを出す本。出題の設定は、穴埋めと四択の 2 種類と、出題への希望。
    private let book: Book
    /// 今回の読書の記録 (2 回目の読書)。ページは、取り込んだ順と逆の順に足してある。
    private let readingSession: ReadingSession

    /// テストごとに、メモリ内の保存先を新しく作り、本を 2 冊と読書の記録を 4 件保存する。
    ///
    /// クイズを出す本には、今回の読書と、それより前に始めた読書を 2 件 (片方は終えた日時が無い) 入れる。もう 1 冊の本には、今回より前に始めた読書を 1 件入れる。
    init() throws {
        let modelContainer = try makeModelContainer(isStoredInMemoryOnly: true)
        writingContext = ModelContext(modelContainer)
        readingContext = ModelContext(modelContainer)
        book = Book(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 0),
            title: "潮見町の灯台日誌",
            questionKinds: [.fillInTheBlank, .comprehension],
            questionGuidance: "人物の行動の理由を中心に"
        )
        writingContext.insert(book)
        readingSession = ReadingSession(
            id: UUID(),
            startedDateTime: Date(timeIntervalSince1970: 3_000),
            endedDateTime: Date(timeIntervalSince1970: 3_600),
            book: book
        )
        writingContext.insert(readingSession)
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 3_200), text: "今回の二枚目", readingSession: readingSession))
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 3_100), text: "今回の一枚目", readingSession: readingSession))

        // 前の読書は、始めた順と逆の順に足す (保存した順ではなく、始めた日時で並ぶことを確かめるため)。
        let secondPreviousReadingSession = ReadingSession(id: UUID(), startedDateTime: Date(timeIntervalSince1970: 2_000), endedDateTime: nil, book: book)
        writingContext.insert(secondPreviousReadingSession)
        writingContext.insert(
            CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 2_100), text: "終えた日時の無い読書の一枚目", readingSession: secondPreviousReadingSession)
        )
        let firstPreviousReadingSession = ReadingSession(
            id: UUID(),
            startedDateTime: Date(timeIntervalSince1970: 1_000),
            endedDateTime: Date(timeIntervalSince1970: 1_600),
            book: book
        )
        writingContext.insert(firstPreviousReadingSession)
        writingContext.insert(
            CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 1_200), text: "最初の読書の二枚目", readingSession: firstPreviousReadingSession)
        )
        writingContext.insert(
            CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 1_100), text: "最初の読書の一枚目", readingSession: firstPreviousReadingSession)
        )

        let otherBook = Book(id: UUID(), createdDateTime: Date(timeIntervalSince1970: 0), title: "はじめての堆肥づくり", questionKinds: [.written], questionGuidance: nil)
        writingContext.insert(otherBook)
        let otherBookReadingSession = ReadingSession(
            id: UUID(),
            startedDateTime: Date(timeIntervalSince1970: 500),
            endedDateTime: Date(timeIntervalSince1970: 900),
            book: otherBook
        )
        writingContext.insert(otherBookReadingSession)
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 600), text: "別の本のページ", readingSession: otherBookReadingSession))
        try writingContext.save()
    }

    /// 偽のクイズと、保存先への書き込みに起こさせる失敗。
    private struct QuizFailure: Error {}

    /// 保存していない問いを作る。
    private func makeQuestion(kind: QuestionKind, choices: [String], modelAnswer: String) -> Question {
        Question(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 4_000),
            kind: kind,
            text: "問いの文",
            choices: choices,
            modelAnswer: modelAnswer,
            evidenceQuote: "根拠の引用",
            readingSession: nil
        )
    }

    /// `questions` を返す偽のクイズで、今回の読書の問いを作って保存し、保存した問いを返す。
    private func makeSavedQuestions(questions: [Question]) async throws -> [Question] {
        try await makeQuizQuestions(
            book: book,
            readingSession: readingSession,
            quizEngine: FixedQuizEngine(availability: .available, questions: questions, modelJudgement: false),
            modelContext: writingContext,
            save: writingContext.save
        )
    }

    /// 読書を終えた後、偽のクイズが返した問いが、返した順のまま返り、今回の読書の記録に付いて保存されている。
    @Test func 偽のクイズが返した問いが今回の読書の記録に付いて保存される() async throws {
        let comprehensionQuestion = makeQuestion(kind: .comprehension, choices: ["犬", "猫", "人", "鳥"], modelAnswer: "猫")
        let fillInTheBlankQuestion = makeQuestion(kind: .fillInTheBlank, choices: [], modelAnswer: "霧")

        #expect(
            try await makeSavedQuestions(questions: [comprehensionQuestion, fillInTheBlankQuestion]).map(\.id)
                == [comprehensionQuestion.id, fillInTheBlankQuestion.id]
        )

        let fetchedQuestions = try readingContext.fetch(FetchDescriptor<Question>())
        #expect(Set(fetchedQuestions.map(\.id)) == [comprehensionQuestion.id, fillInTheBlankQuestion.id])
        #expect(fetchedQuestions.allSatisfy { $0.readingSession?.id == readingSession.id })
        let fetchedComprehensionQuestion = try #require(fetchedQuestions.first { $0.id == comprehensionQuestion.id })
        #expect(fetchedComprehensionQuestion.kind == .comprehension)
        #expect(fetchedComprehensionQuestion.choices == ["犬", "猫", "人", "鳥"])
        #expect(fetchedComprehensionQuestion.modelAnswer == "猫")
        #expect(fetchedComprehensionQuestion.answers.isEmpty)
        #expect(try readingContext.fetch(FetchDescriptor<Answer>()).isEmpty)
    }

    /// 問いを作る処理に、今回の読書のページの本文 (取り込んだ順)、同じ本の前の読書のページの本文 (読書を始めた順で、その中は取り込んだ順。
    /// 終えた日時の無い読書を含み、別の本の読書は含まない)、本の出題の設定が渡っている。
    @Test func 問いを作る処理に今回の本文と前の読書の本文と出題の設定が渡る() async throws {
        let recordingQuizEngine = RecordingQuizEngine(availability: .available, makeQuestionsError: nil, judgementError: nil)

        _ = try await makeQuizQuestions(
            book: book,
            readingSession: readingSession,
            quizEngine: recordingQuizEngine,
            modelContext: writingContext,
            save: writingContext.save
        )

        #expect(recordingQuizEngine.makeQuestionsCallCount == 1)
        #expect(recordingQuizEngine.currentReadingPageTexts == ["今回の一枚目", "今回の二枚目"])
        #expect(recordingQuizEngine.previousReadingPageTexts == ["最初の読書の一枚目", "最初の読書の二枚目", "終えた日時の無い読書の一枚目"])
        #expect(recordingQuizEngine.questionKinds == [.fillInTheBlank, .comprehension])
        #expect(recordingQuizEngine.questionGuidance == "人物の行動の理由を中心に")
    }

    /// 同じ本の、今回と同じ日時に始めた別の読書のページの本文は、前の読書の本文として渡さない (前の読書は、今回より前に始めた読書だけ)。
    @Test func 今回と同じ日時に始めた別の読書の本文は前の読書として渡さない() async throws {
        let sameTimeReadingSession = ReadingSession(id: UUID(), startedDateTime: readingSession.startedDateTime, endedDateTime: nil, book: book)
        writingContext.insert(sameTimeReadingSession)
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 3_050), text: "同じ日時の読書のページ", readingSession: sameTimeReadingSession))
        try writingContext.save()
        let recordingQuizEngine = RecordingQuizEngine(availability: .available, makeQuestionsError: nil, judgementError: nil)

        _ = try await makeQuizQuestions(
            book: book,
            readingSession: readingSession,
            quizEngine: recordingQuizEngine,
            modelContext: writingContext,
            save: writingContext.save
        )

        #expect(recordingQuizEngine.currentReadingPageTexts == ["今回の一枚目", "今回の二枚目"])
        #expect(recordingQuizEngine.previousReadingPageTexts == ["最初の読書の一枚目", "最初の読書の二枚目", "終えた日時の無い読書の一枚目"])
    }

    /// 同じ本の、今回より後に始めた読書のページの本文は、前の読書の本文として渡さない。
    @Test func 今回より後に始めた読書の本文は前の読書として渡さない() async throws {
        let laterReadingSession = ReadingSession(id: UUID(), startedDateTime: Date(timeIntervalSince1970: 5_000), endedDateTime: nil, book: book)
        writingContext.insert(laterReadingSession)
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 5_100), text: "後の読書のページ", readingSession: laterReadingSession))
        try writingContext.save()
        let recordingQuizEngine = RecordingQuizEngine(availability: .available, makeQuestionsError: nil, judgementError: nil)

        _ = try await makeQuizQuestions(
            book: book,
            readingSession: readingSession,
            quizEngine: recordingQuizEngine,
            modelContext: writingContext,
            save: writingContext.save
        )

        #expect(recordingQuizEngine.previousReadingPageTexts == ["最初の読書の一枚目", "最初の読書の二枚目", "終えた日時の無い読書の一枚目"])
    }

    /// 出題への希望を書いていない本では、希望が無い (nil) まま渡る。前の読書が無い本では、前の読書の本文が空で渡る。
    @Test func 希望の無い本と前の読書の無い本ではその値が空で渡る() async throws {
        let newBook = Book(id: UUID(), createdDateTime: Date(timeIntervalSince1970: 0), title: "霧の岬の航海記", questionKinds: [.written], questionGuidance: nil)
        writingContext.insert(newBook)
        let firstReadingSession = ReadingSession(id: UUID(), startedDateTime: Date(timeIntervalSince1970: 6_000), endedDateTime: Date(timeIntervalSince1970: 6_600), book: newBook)
        writingContext.insert(firstReadingSession)
        writingContext.insert(CapturedPage(id: UUID(), capturedDateTime: Date(timeIntervalSince1970: 6_100), text: "初めての読書のページ", readingSession: firstReadingSession))
        try writingContext.save()
        let recordingQuizEngine = RecordingQuizEngine(availability: .available, makeQuestionsError: nil, judgementError: nil)

        _ = try await makeQuizQuestions(
            book: newBook,
            readingSession: firstReadingSession,
            quizEngine: recordingQuizEngine,
            modelContext: writingContext,
            save: writingContext.save
        )

        #expect(recordingQuizEngine.currentReadingPageTexts == ["初めての読書のページ"])
        #expect(recordingQuizEngine.previousReadingPageTexts == [])
        #expect(recordingQuizEngine.questionKinds == [.written])
        #expect(recordingQuizEngine.questionGuidance == nil)
    }

    /// 問いが 1 問も返らなかった時は、空の配列が返り、問いと回答が 1 件も保存されない。
    @Test func 問いが1問も返らなかった時は問いと回答が保存されない() async throws {
        #expect(try await makeSavedQuestions(questions: []).isEmpty)

        #expect(try readingContext.fetch(FetchDescriptor<Question>()).isEmpty)
        #expect(try readingContext.fetch(FetchDescriptor<Answer>()).isEmpty)
    }

    /// 問いが 1 問も返らなかった時は、保存先への書き込みを呼ばない (書き込みが失敗する状態でも、失敗にならずに空の配列が返る)。
    @Test func 問いが1問も返らなかった時は保存先への書き込みを呼ばない() async throws {
        #expect(
            try await makeQuizQuestions(
                book: book,
                readingSession: readingSession,
                quizEngine: FixedQuizEngine(availability: .available, questions: [], modelJudgement: false),
                modelContext: writingContext,
                save: { throw QuizFailure() }
            ).isEmpty
        )
    }

    /// 端末内のモデルが使えない時は、使えない理由がどれでも、問いを作る処理を呼ばずに `QuizModelUnavailableError` を投げ、問いと回答が 1 件も保存されない。
    @Test func 端末内のモデルが使えない時は問いを作らず問いと回答が保存されない() async throws {
        for unavailableReason in [SystemLanguageModel.Availability.UnavailableReason.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady] {
            let recordingQuizEngine = RecordingQuizEngine(availability: .unavailable(unavailableReason), makeQuestionsError: nil, judgementError: nil)

            await #expect(throws: QuizModelUnavailableError.self) {
                _ = try await makeQuizQuestions(
                    book: book,
                    readingSession: readingSession,
                    quizEngine: recordingQuizEngine,
                    modelContext: writingContext,
                    save: writingContext.save
                )
            }

            #expect(recordingQuizEngine.makeQuestionsCallCount == 0)
            #expect(try readingContext.fetch(FetchDescriptor<Question>()).isEmpty)
            #expect(try readingContext.fetch(FetchDescriptor<Answer>()).isEmpty)
        }
    }

    /// 問いを作る処理が失敗した時は、その error がそのまま投げられ、問いが 1 件も保存されない。
    @Test func 問いを作る処理が失敗した時はそのerrorを投げて問いが保存されない() async throws {
        await #expect(throws: QuizFailure.self) {
            _ = try await makeQuizQuestions(
                book: book,
                readingSession: readingSession,
                quizEngine: RecordingQuizEngine(availability: .available, makeQuestionsError: QuizFailure(), judgementError: nil),
                modelContext: writingContext,
                save: writingContext.save
            )
        }

        #expect(try readingContext.fetch(FetchDescriptor<Question>()).isEmpty)
    }

    /// 作った問いの保存に失敗した時は、保存の error が投げられ、その問いは後の保存でも保存されない (context に残らない)。
    @Test func 問いの保存に失敗した時は後の保存にもその問いが混ざらない() async throws {
        await #expect(throws: QuizFailure.self) {
            _ = try await makeQuizQuestions(
                book: book,
                readingSession: readingSession,
                quizEngine: FixedQuizEngine(
                    availability: .available,
                    questions: [makeQuestion(kind: .written, choices: [], modelAnswer: "答えの例")],
                    modelJudgement: false
                ),
                modelContext: writingContext,
                save: { throw QuizFailure() }
            )
        }

        try writingContext.save()
        #expect(try readingContext.fetch(FetchDescriptor<Question>()).isEmpty)
    }

    /// 四択の問いに模範の答えと同じ選択肢で答えると、回答が 1 件保存され、利用者の答え・合っているという判定・答えた日時・答えた問いが入っている。
    @Test func 四択に模範の答えで答えると合っている回答が1件保存される() async throws {
        let question = try #require(try await makeSavedQuestions(questions: [makeQuestion(kind: .comprehension, choices: ["犬", "猫", "人", "鳥"], modelAnswer: "猫")]).first)

        let answer = try await answerQuizQuestion(
            question: question,
            answerText: "猫",
            // 選択式は端末内のモデルの判定 (ここでは「合っていない」) を使わない。
            quizEngine: FixedQuizEngine(availability: .available, questions: [], modelJudgement: false),
            modelContext: writingContext,
            currentDateTime: { Date(timeIntervalSince1970: 4_500) },
            save: writingContext.save
        )

        let fetchedAnswers = try readingContext.fetch(FetchDescriptor<Answer>())
        try #require(fetchedAnswers.count == 1)
        #expect(fetchedAnswers[0].id == answer.id)
        #expect(fetchedAnswers[0].text == "猫")
        #expect(fetchedAnswers[0].isCorrect)
        #expect(fetchedAnswers[0].answeredDateTime == Date(timeIntervalSince1970: 4_500))
        #expect(fetchedAnswers[0].question?.id == question.id)
    }

    /// 要約の正誤の問いに模範の答えと違う選択肢で答えると、回答が 1 件保存され、利用者の答えと、合っていないという判定が入っている。
    @Test func 要約の正誤に模範の答えと違う選択肢で答えると合っていない回答が保存される() async throws {
        let question = try #require(try await makeSavedQuestions(questions: [makeQuestion(kind: .summaryTrueFalse, choices: ["正しい", "誤り"], modelAnswer: "誤り")]).first)

        _ = try await answerQuizQuestion(
            question: question,
            answerText: "正しい",
            // 選択式は端末内のモデルの判定 (ここでは「合っている」) を使わない。
            quizEngine: FixedQuizEngine(availability: .available, questions: [], modelJudgement: true),
            modelContext: writingContext,
            currentDateTime: { Date(timeIntervalSince1970: 4_500) },
            save: writingContext.save
        )

        let fetchedAnswers = try readingContext.fetch(FetchDescriptor<Answer>())
        try #require(fetchedAnswers.count == 1)
        #expect(fetchedAnswers[0].text == "正しい")
        #expect(!fetchedAnswers[0].isCorrect)
    }

    /// 穴埋めの問いに答えると、前後の空白と改行を除いた答えが判定に渡り、その答えと端末内のモデルの判定 (合っている) が回答に保存される。
    @Test func 穴埋めは空白を除いた答えと端末内のモデルの合っている判定が保存される() async throws {
        try await expectTrimmedAnswerAndModelJudgementAreSaved(kind: .fillInTheBlank, modelJudgement: true)
    }

    /// 穴埋めの問いで、端末内のモデルの判定が合っていない時は、合っていないという判定が回答に保存される。
    @Test func 穴埋めは端末内のモデルの合っていない判定が保存される() async throws {
        try await expectTrimmedAnswerAndModelJudgementAreSaved(kind: .fillInTheBlank, modelJudgement: false)
    }

    /// 記述の問いに答えると、前後の空白と改行を除いた答えが判定に渡り、その答えと端末内のモデルの判定 (合っている) が回答に保存される。
    @Test func 記述は空白を除いた答えと端末内のモデルの合っている判定が保存される() async throws {
        try await expectTrimmedAnswerAndModelJudgementAreSaved(kind: .written, modelJudgement: true)
    }

    /// 記述の問いで、端末内のモデルの判定が合っていない時は、合っていないという判定が回答に保存される。
    @Test func 記述は端末内のモデルの合っていない判定が保存される() async throws {
        try await expectTrimmedAnswerAndModelJudgementAreSaved(kind: .written, modelJudgement: false)
    }

    /// 種類 `kind` の問いに、前後に空白と改行のある答えで答え、空白を除いた答えが判定に渡って保存され、判定 `modelJudgement` が保存されていることを確かめる。
    private func expectTrimmedAnswerAndModelJudgementAreSaved(kind: QuestionKind, modelJudgement: Bool) async throws {
        let question = try #require(try await makeSavedQuestions(questions: [makeQuestion(kind: kind, choices: [], modelAnswer: "霧")]).first)
        let recordingQuizEngine = RecordingQuizEngine(availability: .available, makeQuestionsError: nil, judgementError: nil)
        recordingQuizEngine.modelJudgement = modelJudgement

        _ = try await answerQuizQuestion(
            question: question,
            answerText: " \n霧 の中\n",
            quizEngine: recordingQuizEngine,
            modelContext: writingContext,
            currentDateTime: { Date(timeIntervalSince1970: 4_500) },
            save: writingContext.save
        )

        #expect(recordingQuizEngine.judgedAnswerTexts == ["霧 の中"])
        let fetchedAnswers = try readingContext.fetch(FetchDescriptor<Answer>())
        try #require(fetchedAnswers.count == 1)
        #expect(fetchedAnswers[0].text == "霧 の中")
        #expect(fetchedAnswers[0].isCorrect == modelJudgement)
    }

    /// 四択の選んだ選択肢は、前後に空白があっても変えずに保存し、模範の答えと同じ文字列かで判定する。
    @Test func 選択式の答えは前後の空白を除かずに保存して判定する() async throws {
        let question = try #require(try await makeSavedQuestions(questions: [makeQuestion(kind: .comprehension, choices: [" 猫 ", "猫", "人", "鳥"], modelAnswer: " 猫 ")]).first)

        _ = try await answerQuizQuestion(
            question: question,
            answerText: " 猫 ",
            quizEngine: FixedQuizEngine(availability: .available, questions: [], modelJudgement: false),
            modelContext: writingContext,
            currentDateTime: { Date(timeIntervalSince1970: 4_500) },
            save: writingContext.save
        )

        let fetchedAnswers = try readingContext.fetch(FetchDescriptor<Answer>())
        try #require(fetchedAnswers.count == 1)
        #expect(fetchedAnswers[0].text == " 猫 ")
        #expect(fetchedAnswers[0].isCorrect)
    }

    /// 同じ問いに 2 回答えると、回答が 2 件保存される (答えるたびに 1 件増える)。
    @Test func 同じ問いに2回答えると回答が2件保存される() async throws {
        let question = try #require(try await makeSavedQuestions(questions: [makeQuestion(kind: .comprehension, choices: ["犬", "猫", "人", "鳥"], modelAnswer: "猫")]).first)

        for answerText in ["犬", "猫"] {
            _ = try await answerQuizQuestion(
                question: question,
                answerText: answerText,
                quizEngine: FixedQuizEngine(availability: .available, questions: [], modelJudgement: false),
                modelContext: writingContext,
                currentDateTime: { Date(timeIntervalSince1970: 4_500) },
                save: writingContext.save
            )
        }

        let fetchedAnswers = try readingContext.fetch(FetchDescriptor<Answer>())
        #expect(fetchedAnswers.count == 2)
        #expect(Set(fetchedAnswers.map(\.text)) == ["犬", "猫"])
    }

    /// 端末内のモデルが判定を返せなかった時は、その error がそのまま投げられ、回答が 1 件も保存されない。
    @Test func 判定が失敗した時はそのerrorを投げて回答が保存されない() async throws {
        let question = try #require(try await makeSavedQuestions(questions: [makeQuestion(kind: .written, choices: [], modelAnswer: "答えの例")]).first)

        await #expect(throws: QuizFailure.self) {
            _ = try await answerQuizQuestion(
                question: question,
                answerText: "答え",
                quizEngine: RecordingQuizEngine(availability: .available, makeQuestionsError: nil, judgementError: QuizFailure()),
                modelContext: writingContext,
                currentDateTime: { Date(timeIntervalSince1970: 4_500) },
                save: writingContext.save
            )
        }

        try writingContext.save()
        #expect(try readingContext.fetch(FetchDescriptor<Answer>()).isEmpty)
    }

    /// 回答の保存に失敗した時は、保存の error が投げられ、その回答は後の保存でも保存されない (context に残らない)。
    @Test func 回答の保存に失敗した時は後の保存にもその回答が混ざらない() async throws {
        let question = try #require(try await makeSavedQuestions(questions: [makeQuestion(kind: .comprehension, choices: ["犬", "猫", "人", "鳥"], modelAnswer: "猫")]).first)

        await #expect(throws: QuizFailure.self) {
            _ = try await answerQuizQuestion(
                question: question,
                answerText: "猫",
                quizEngine: FixedQuizEngine(availability: .available, questions: [], modelJudgement: false),
                modelContext: writingContext,
                currentDateTime: { Date(timeIntervalSince1970: 4_500) },
                save: { throw QuizFailure() }
            )
        }

        try writingContext.save()
        #expect(try readingContext.fetch(FetchDescriptor<Answer>()).isEmpty)
    }

    /// 問いが 1 問も無い時の案内は、ページを 1 枚も取り込めなかった時は本文を取り込めなかったことを、1 枚以上ある時は読んだ範囲から作れなかったことを伝える。
    @Test func 問いが無い時の案内は取り込んだページの有無で分かれる() {
        #expect(quizNoQuestionsGuide(capturedPageCount: 0) == "本文を取り込めなかったため\n今回の読書のクイズはありません")
        #expect(quizNoQuestionsGuide(capturedPageCount: 1) == "読んだ範囲から問いを作れなかったため\n今回の読書のクイズはありません")
        #expect(quizNoQuestionsGuide(capturedPageCount: 12) == "読んだ範囲から問いを作れなかったため\n今回の読書のクイズはありません")
    }

    /// 判定の文は、四択と要約の正誤では言い切り、穴埋めと記述では言い切らない。
    @Test func 判定の文は選択式では言い切り穴埋めと記述では言い切らない() {
        #expect(quizJudgementText(questionKind: .comprehension, isCorrect: true) == "合っています")
        #expect(quizJudgementText(questionKind: .comprehension, isCorrect: false) == "合っていません")
        #expect(quizJudgementText(questionKind: .summaryTrueFalse, isCorrect: true) == "合っています")
        #expect(quizJudgementText(questionKind: .summaryTrueFalse, isCorrect: false) == "合っていません")
        #expect(quizJudgementText(questionKind: .fillInTheBlank, isCorrect: true) == "合っていそうです")
        #expect(quizJudgementText(questionKind: .fillInTheBlank, isCorrect: false) == "合っていないかもしれません")
        #expect(quizJudgementText(questionKind: .written, isCorrect: true) == "合っていそうです")
        #expect(quizJudgementText(questionKind: .written, isCorrect: false) == "合っていないかもしれません")
    }

    /// 判定が間違うことがある旨の文は、端末内のモデルが判定する穴埋めと記述にだけ添え、四択と要約の正誤には添えない。
    @Test func 判定が間違うことがある旨は穴埋めと記述にだけ添える() throws {
        #expect(quizJudgementCaution(questionKind: .comprehension) == nil)
        #expect(quizJudgementCaution(questionKind: .summaryTrueFalse) == nil)
        #expect(try #require(quizJudgementCaution(questionKind: .fillInTheBlank)).contains("間違うことがあります"))
        #expect(try #require(quizJudgementCaution(questionKind: .written)).contains("間違うことがあります"))
    }

    /// 問いを作れなかった時の案内と、答えを判定・保存できなかった時の案内は、error の内容を含む。
    @Test func 失敗の案内はerrorの内容を含む() {
        #expect(quizPreparationFailureGuide(error: QuizFailure()).hasPrefix("問いを作れませんでした\n"))
        #expect(quizPreparationFailureGuide(error: QuizFailure()).contains("QuizFailure"))
        #expect(quizAnswerFailureGuide(error: QuizFailure()).hasPrefix("答えを判定して保存できませんでした\n"))
        #expect(quizAnswerFailureGuide(error: QuizFailure()).contains("QuizFailure"))
    }

    /// 判定の文の前の印は、合っている時は ○、合っていない時は × になる。
    @Test func 判定の印は合っている時は丸で合っていない時はバツになる() {
        #expect(quizJudgementSign(isCorrect: true) == "○")
        #expect(quizJudgementSign(isCorrect: false) == "×")
    }

    /// 動きを減らす設定が入っていない時は、合っている時に弾み (紙吹雪も落ちる)、合っていない時に揺れる。
    @Test func 動きを減らす設定が無い時は合っていると弾み合っていないと揺れる() {
        #expect(quizAnswerMotion(isCorrect: true, reducesMotion: false) == .pop)
        #expect(quizAnswerMotion(isCorrect: false, reducesMotion: false) == .shake)
    }

    /// 動きを減らす設定が入っている時は、合っている時も合っていない時も動かさない (弾まず、紙吹雪も落ちず、揺れない)。
    @Test func 動きを減らす設定がある時は答えても動かない() {
        #expect(quizAnswerMotion(isCorrect: true, reducesMotion: true) == nil)
        #expect(quizAnswerMotion(isCorrect: false, reducesMotion: true) == nil)
    }

    /// 進み具合の線は、動きを減らす設定が無い時だけ、今の問いの区切りが画面が出る前は 0 で、出た後に伸びきる。ほかの区切りは初めから伸びきっている。
    @Test func 進み具合の線は今の問いの区切りだけが伸びる() {
        #expect(quizProgressSegmentScale(segmentIndex: 1, currentIndex: 1, hasGrown: false, reducesMotion: false) == 0)
        #expect(quizProgressSegmentScale(segmentIndex: 1, currentIndex: 1, hasGrown: true, reducesMotion: false) == 1)
        #expect(quizProgressSegmentScale(segmentIndex: 0, currentIndex: 1, hasGrown: false, reducesMotion: false) == 1)
        #expect(quizProgressSegmentScale(segmentIndex: 2, currentIndex: 1, hasGrown: false, reducesMotion: false) == 1)
    }

    /// 動きを減らす設定が入っている時は、今の問いの区切りも画面が出る前から伸びきっていて、伸びる動きが無い。
    @Test func 動きを減らす設定がある時は進み具合の線が伸びる動きをしない() {
        #expect(quizProgressSegmentScale(segmentIndex: 1, currentIndex: 1, hasGrown: false, reducesMotion: true) == 1)
        #expect(quizProgressSegmentScale(segmentIndex: 1, currentIndex: 1, hasGrown: true, reducesMotion: true) == 1)
    }
}

/// 渡された値を覚える、偽の `QuizEngine`。問いは 1 問も返さない。
@MainActor private final class RecordingQuizEngine: QuizEngine {
    /// 端末内のモデルが使えるかとして返す値。
    let availability: SystemLanguageModel.Availability
    /// 問いを作る処理に起こさせる失敗。起こさない時は nil。
    private let makeQuestionsError: (any Error)?
    /// 端末内のモデルの判定に起こさせる失敗。起こさない時は nil。
    private let judgementError: (any Error)?
    /// 穴埋めと記述の問いへの、どの答えにも返す判定。
    var modelJudgement = false
    /// `makeQuestions` が呼ばれた回数。
    private(set) var makeQuestionsCallCount = 0
    /// 最後の `makeQuestions` に渡された、今回の読書のページの本文。
    private(set) var currentReadingPageTexts: [String] = []
    /// 最後の `makeQuestions` に渡された、同じ本の前の読書のページの本文。
    private(set) var previousReadingPageTexts: [String] = []
    /// 最後の `makeQuestions` に渡された、出題する問いの種類。
    private(set) var questionKinds: [QuestionKind] = []
    /// 最後の `makeQuestions` に渡された、出題への希望。
    private(set) var questionGuidance: String?
    /// `judgeWithModel` に渡された答え。呼ばれた順。
    private(set) var judgedAnswerTexts: [String] = []

    /// 自動で作られる initializer が無い型 (class) のため手で書いている。
    init(availability: SystemLanguageModel.Availability, makeQuestionsError: (any Error)?, judgementError: (any Error)?) {
        self.availability = availability
        self.makeQuestionsError = makeQuestionsError
        self.judgementError = judgementError
    }

    /// 渡された値を覚えて、空の配列を返す。`makeQuestionsError` がある時は、覚えた後にそれを投げる。
    func makeQuestions(
        currentReadingPageTexts: [String],
        previousReadingPageTexts: [String],
        questionKinds: [QuestionKind],
        questionGuidance: String?
    ) async throws -> [Question] {
        makeQuestionsCallCount += 1
        self.currentReadingPageTexts = currentReadingPageTexts
        self.previousReadingPageTexts = previousReadingPageTexts
        self.questionKinds = questionKinds
        self.questionGuidance = questionGuidance
        if let makeQuestionsError {
            throw makeQuestionsError
        }
        return []
    }

    /// 渡された答えを覚えて、`modelJudgement` を返す。`judgementError` がある時は、覚えた後にそれを投げる。
    func judgeWithModel(question: Question, answerText: String) async throws -> Bool {
        judgedAnswerTexts.append(answerText)
        if let judgementError {
            throw judgementError
        }
        return modelJudgement
    }
}
