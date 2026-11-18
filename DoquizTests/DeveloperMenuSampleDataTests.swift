#if DEBUG
    import Foundation
    import SwiftData
    import Testing
    @testable import Doquiz

    /// 開発者メニューの「見本のデータを入れる」操作と「保存データを全部消す」操作を、端末に書き込まないメモリ内の保存先で確かめる。
    struct DeveloperMenuSampleDataTests {
        /// 操作を実行する context。
        private let writingContext: ModelContext
        /// 保存先に書かれた結果を読む context。書いた context に残っている値ではなく、保存先の値を確かめるために分ける。
        private let readingContext: ModelContext

        /// テストごとに、メモリ内の保存先を新しく作る。
        init() throws {
            let modelContainer = try makeModelContainer(isStoredInMemoryOnly: true)
            writingContext = ModelContext(modelContainer)
            readingContext = ModelContext(modelContainer)
        }

        /// 見本でない本 1 冊と、その下の読書の記録・ページ・問い・回答を 1 件ずつ足して保存し、足した本を返す。
        private func insertOwnBookWithOneOfEach() throws -> Book {
            let ownBook = Book(
                id: UUID(),
                createdDateTime: Date(timeIntervalSince1970: 1_800_000_000),
                title: "自分で登録した本",
                questionKinds: [.written],
                questionGuidance: nil
            )
            writingContext.insert(ownBook)
            let ownReadingSession = ReadingSession(
                id: UUID(),
                startedDateTime: Date(timeIntervalSince1970: 1_800_000_100),
                endedDateTime: nil,
                book: ownBook
            )
            writingContext.insert(ownReadingSession)
            writingContext.insert(
                CapturedPage(
                    id: UUID(),
                    capturedDateTime: Date(timeIntervalSince1970: 1_800_000_200),
                    text: "自分で取り込んだページの本文",
                    readingSession: ownReadingSession
                )
            )
            let ownQuestion = Question(
                id: UUID(),
                createdDateTime: Date(timeIntervalSince1970: 1_800_000_300),
                kind: .written,
                text: "自分の本の問い",
                choices: [],
                modelAnswer: "模範の答え",
                evidenceQuote: "自分で取り込んだページの本文",
                readingSession: ownReadingSession
            )
            writingContext.insert(ownQuestion)
            writingContext.insert(
                Answer(
                    id: UUID(),
                    answeredDateTime: Date(timeIntervalSince1970: 1_800_000_400),
                    text: "自分の答え",
                    isCorrect: true,
                    question: ownQuestion
                )
            )
            try writingContext.save()
            return ownBook
        }

        /// 本にも読書の記録にも問いにも属していない読書の記録・ページ・問い・回答を 1 件ずつ足して保存する。
        private func insertRecordsWithoutParent() throws {
            writingContext.insert(
                ReadingSession(
                    id: UUID(),
                    startedDateTime: Date(timeIntervalSince1970: 1_800_001_000),
                    endedDateTime: nil,
                    book: nil
                )
            )
            writingContext.insert(
                CapturedPage(
                    id: UUID(),
                    capturedDateTime: Date(timeIntervalSince1970: 1_800_001_100),
                    text: "読書の記録に属していないページ",
                    readingSession: nil
                )
            )
            writingContext.insert(
                Question(
                    id: UUID(),
                    createdDateTime: Date(timeIntervalSince1970: 1_800_001_200),
                    kind: .fillInTheBlank,
                    text: "読書の記録に属していない問い",
                    choices: [],
                    modelAnswer: "模範の答え",
                    evidenceQuote: "根拠の引用",
                    readingSession: nil
                )
            )
            writingContext.insert(
                Answer(
                    id: UUID(),
                    answeredDateTime: Date(timeIntervalSince1970: 1_800_001_300),
                    text: "問いに属していない回答",
                    isCorrect: false,
                    question: nil
                )
            )
            try writingContext.save()
        }

        /// 保存先にある 5 つの型の件数を、本・読書の記録・ページ・問い・回答の順に返す。
        private func savedCounts() throws -> [Int] {
            try [
                readingContext.fetchCount(FetchDescriptor<Book>()),
                readingContext.fetchCount(FetchDescriptor<ReadingSession>()),
                readingContext.fetchCount(FetchDescriptor<CapturedPage>()),
                readingContext.fetchCount(FetchDescriptor<Question>()),
                readingContext.fetchCount(FetchDescriptor<Answer>()),
            ]
        }

        /// 空の保存先に見本のデータを入れると、本 2 冊・読書の記録 3 件・ページ 4 件・問い 6 問・回答 7 件が保存されることを確かめる。
        @Test func 見本のデータを入れると本と読書の記録とページと問いと回答が保存される() throws {
            try replaceDeveloperMenuSampleData(modelContext: writingContext)

            #expect(try savedCounts() == [2, 3, 4, 6, 7])
            #expect(
                try readingContext.fetch(FetchDescriptor<Book>(sortBy: [SortDescriptor(\.createdDateTime)])).map(\.title)
                    == ["潮見町の灯台日誌", "はじめての堆肥づくり"]
            )
        }

        /// 見本の読書の記録が、どれも終えた読書の記録 (終えた日時が始めた日時より後) で、本に属し、ページを 1 件以上持つことを確かめる。
        @Test func 見本の読書の記録はすべて終えていて本に属しページを持つ() throws {
            try replaceDeveloperMenuSampleData(modelContext: writingContext)

            let fetchedReadingSessions = try readingContext.fetch(FetchDescriptor<ReadingSession>())
            try #require(fetchedReadingSessions.count == 3)
            for fetchedReadingSession in fetchedReadingSessions {
                #expect(try #require(fetchedReadingSession.endedDateTime) > fetchedReadingSession.startedDateTime)
                #expect(fetchedReadingSession.book != nil)
                #expect(fetchedReadingSession.capturedPages.isEmpty == false)
            }
        }

        /// 見本の問いに、四択・要約の正誤・穴埋め・記述の 4 種類がすべてあることを確かめる。
        @Test(arguments: [QuestionKind.comprehension, .summaryTrueFalse, .fillInTheBlank, .written])
        func 見本の問いに4種類の問いがそれぞれある(questionKind: QuestionKind) throws {
            try replaceDeveloperMenuSampleData(modelContext: writingContext)

            #expect(try readingContext.fetch(FetchDescriptor<Question>()).contains { $0.kind == questionKind })
        }

        /// 見本の問いが、問いの種類ごとの形 (四択は選択肢 4 つ、要約の正誤は選択肢 2 つで、模範の答えが選択肢のどれか。穴埋めと記述は選択肢が無い) を守り、
        /// 根拠の引用が同じ読書の記録のページの本文にあることを確かめる。
        @Test func 見本の問いは種類ごとの形を守り根拠の引用がページの本文にある() throws {
            try replaceDeveloperMenuSampleData(modelContext: writingContext)

            let fetchedQuestions = try readingContext.fetch(FetchDescriptor<Question>())
            try #require(fetchedQuestions.count == 6)
            for fetchedQuestion in fetchedQuestions {
                switch fetchedQuestion.kind {
                case .comprehension:
                    #expect(fetchedQuestion.choices.count == 4)
                    #expect(fetchedQuestion.choices.contains(fetchedQuestion.modelAnswer))
                case .summaryTrueFalse:
                    #expect(fetchedQuestion.choices.count == 2)
                    #expect(fetchedQuestion.choices.contains(fetchedQuestion.modelAnswer))
                case .fillInTheBlank, .written:
                    #expect(fetchedQuestion.choices.isEmpty)
                }
                #expect(
                    try #require(fetchedQuestion.readingSession).capturedPages.contains {
                        $0.text.contains(fetchedQuestion.evidenceQuote)
                    }
                )
            }
        }

        /// 見本の回答に、合っていると判定された回答が 4 件、合っていないと判定された回答が 3 件あり、
        /// 選択式の問いへの回答の判定が「模範の答えと同じか」と一致することを確かめる。
        @Test func 見本の回答に合っている回答と合っていない回答がある() throws {
            try replaceDeveloperMenuSampleData(modelContext: writingContext)

            let fetchedAnswers = try readingContext.fetch(FetchDescriptor<Answer>())
            #expect(fetchedAnswers.filter(\.isCorrect).count == 4)
            #expect(fetchedAnswers.filter { $0.isCorrect == false }.count == 3)
            for fetchedAnswer in fetchedAnswers {
                let question = try #require(fetchedAnswer.question)
                if question.choices.isEmpty == false {
                    #expect(fetchedAnswer.isCorrect == (fetchedAnswer.text == question.modelAnswer))
                }
            }
        }

        /// 見本のデータを 2 回入れても、保存されている件数が 1 回の時と同じで、見本が二重に増えないことを確かめる。
        @Test func 見本のデータを2回入れても件数は1回の時と同じ() throws {
            try replaceDeveloperMenuSampleData(modelContext: writingContext)
            try replaceDeveloperMenuSampleData(modelContext: writingContext)

            #expect(try savedCounts() == [2, 3, 4, 6, 7])
        }

        /// 入れた後に書き換えた見本の本の名前と、消した見本の読書の記録が、もう一度入れると元の内容に戻ることを確かめる。
        @Test func 書き換えた見本はもう一度入れると元の内容に戻る() throws {
            try replaceDeveloperMenuSampleData(modelContext: writingContext)
            let lighthouseBook = try #require(
                try writingContext.fetch(FetchDescriptor<Book>()).first { $0.title == "潮見町の灯台日誌" }
            )
            lighthouseBook.title = "書き換えた名前"
            try #require(lighthouseBook.readingSessions.count == 2)
            writingContext.delete(lighthouseBook.readingSessions[0])
            try writingContext.save()
            try #require(try savedCounts() != [2, 3, 4, 6, 7])

            try replaceDeveloperMenuSampleData(modelContext: writingContext)

            #expect(try savedCounts() == [2, 3, 4, 6, 7])
            #expect(
                try readingContext.fetch(FetchDescriptor<Book>(sortBy: [SortDescriptor(\.createdDateTime)])).map(\.title)
                    == ["潮見町の灯台日誌", "はじめての堆肥づくり"]
            )
        }

        /// 見本でない本がある保存先に見本のデータを 2 回入れても、見本でない本とその下の読書の記録・ページ・問い・回答が残ることを確かめる。
        @Test func 見本のデータを入れても見本でない本とその下のデータは残る() throws {
            let ownBook = try insertOwnBookWithOneOfEach()

            try replaceDeveloperMenuSampleData(modelContext: writingContext)
            try replaceDeveloperMenuSampleData(modelContext: writingContext)

            #expect(try savedCounts() == [3, 4, 5, 7, 8])
            let fetchedOwnBook = try #require(
                try readingContext.fetch(FetchDescriptor<Book>()).first { $0.id == ownBook.id }
            )
            #expect(fetchedOwnBook.title == "自分で登録した本")
            try #require(fetchedOwnBook.readingSessions.count == 1)
            #expect(fetchedOwnBook.readingSessions[0].capturedPages.map(\.text) == ["自分で取り込んだページの本文"])
            try #require(fetchedOwnBook.readingSessions[0].questions.count == 1)
            #expect(fetchedOwnBook.readingSessions[0].questions[0].answers.map(\.text) == ["自分の答え"])
        }

        /// 見本のデータ・見本でない本・親に属していないデータがある保存先で全部消すと、5 つの型のどれも 0 件になることを確かめる。
        @Test func 全部消すと5つの型のどれも0件になる() throws {
            try replaceDeveloperMenuSampleData(modelContext: writingContext)
            _ = try insertOwnBookWithOneOfEach()
            try insertRecordsWithoutParent()
            try #require(try savedCounts() == [3, 5, 6, 8, 9])

            try deleteAllSavedData(modelContext: writingContext)

            #expect(try savedCounts() == [0, 0, 0, 0, 0])
        }

        /// 親に属していないデータだけがある保存先 (本が 0 冊) で全部消しても、読書の記録・ページ・問い・回答が残らないことを確かめる。
        @Test func 本が無く親に属していないデータだけでも全部消える() throws {
            try insertRecordsWithoutParent()
            try #require(try savedCounts() == [0, 1, 1, 1, 1])

            try deleteAllSavedData(modelContext: writingContext)

            #expect(try savedCounts() == [0, 0, 0, 0, 0])
        }

        /// 空の保存先で全部消しても、続けて 2 回消しても、エラーにならず 0 件のままであることを確かめる。
        @Test func 空の保存先で全部消してもエラーにならない() throws {
            try deleteAllSavedData(modelContext: writingContext)
            try deleteAllSavedData(modelContext: writingContext)

            #expect(try savedCounts() == [0, 0, 0, 0, 0])
        }

        /// 全部消した後に見本のデータを入れ直すと、見本が元の件数で保存されることを確かめる。
        @Test func 全部消した後に見本のデータを入れ直せる() throws {
            try replaceDeveloperMenuSampleData(modelContext: writingContext)
            try deleteAllSavedData(modelContext: writingContext)

            try replaceDeveloperMenuSampleData(modelContext: writingContext)

            #expect(try savedCounts() == [2, 3, 4, 6, 7])
        }
    }
#endif
