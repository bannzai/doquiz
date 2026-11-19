#if DEBUG
    import Foundation
    import SwiftData

    /// 見本のデータの 1 件を区別する値を作る。入れ直しても同じ値になるよう、番号から決まった値を返す。
    private func sampleID(number: UInt8) -> UUID {
        UUID(uuid: (0xD0, 0x0C, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, number))
    }

    /// 見本のデータの日時を作る。入れ直しても同じ値になるよう、決まった起点 (2026-11-06 頃) からの秒数で表す。
    private func sampleDateTime(secondsFromStart: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_794_000_000 + secondsFromStart)
    }

    /// 見本のデータの本を区別する値。見本を入れ直す時に、前に入れた見本の本を探すのに使う。
    private let sampleBookIDs = [sampleID(number: 1), sampleID(number: 2)]

    /// 見本のデータ (本 2 冊と、その終えた読書の記録・ページ・4 種類の問い・合っている回答と合っていない回答) を保存する。
    ///
    /// 前に入れた見本の本は、その読書の記録・ページ・問い・回答ごと消してから入れ直す。そのため何回実行しても、見本は同じ内容で 1 組だけになる。
    /// 見本でない本と、その下のデータには触れない。
    /// 見本の本の名前と本文は、このファイルのために書いた文で、実際の本の本文ではない。
    /// 保存先への書き込みに失敗した時は、SwiftData のエラーを投げる。
    func replaceDeveloperMenuSampleData(modelContext: ModelContext) throws {
        for book in try modelContext.fetch(FetchDescriptor<Book>()) where sampleBookIDs.contains(book.id) {
            modelContext.delete(book)
        }
        try modelContext.save()

        let lighthouseBook = Book(
            id: sampleID(number: 1),
            createdDateTime: sampleDateTime(secondsFromStart: 0),
            title: "潮見町の灯台日誌",
            questionKinds: [.comprehension, .summaryTrueFalse, .fillInTheBlank, .written],
            questionGuidance: "人物の行動の理由を中心に"
        )
        modelContext.insert(lighthouseBook)

        let firstLighthouseReading = ReadingSession(
            id: sampleID(number: 11),
            startedDateTime: sampleDateTime(secondsFromStart: 600),
            endedDateTime: sampleDateTime(secondsFromStart: 4_200),
            book: lighthouseBook
        )
        modelContext.insert(firstLighthouseReading)
        modelContext.insert(
            CapturedPage(
                id: sampleID(number: 21),
                capturedDateTime: sampleDateTime(secondsFromStart: 700),
                text: "潮見町の灯台は、港の東の岬に立っている。灯台守の三枝は、毎朝五時に階段を百二十段のぼり、レンズを布で拭く。",
                readingSession: firstLighthouseReading
            )
        )
        modelContext.insert(
            CapturedPage(
                id: sampleID(number: 22),
                capturedDateTime: sampleDateTime(secondsFromStart: 1_900),
                text: "霧の濃い日は、灯りだけでは船に届かない。三枝は霧笛を三十秒おきに鳴らし、沖の漁船に岬の位置を知らせた。",
                readingSession: firstLighthouseReading
            )
        )

        let comprehensionQuestion = Question(
            id: sampleID(number: 31),
            createdDateTime: sampleDateTime(secondsFromStart: 4_260),
            kind: .comprehension,
            text: "灯台守の三枝が毎朝五時にすることは何か",
            choices: ["レンズを布で拭く", "霧笛を鳴らす", "漁船を出す", "港の門を開ける"],
            modelAnswer: "レンズを布で拭く",
            evidenceQuote: "灯台守の三枝は、毎朝五時に階段を百二十段のぼり、レンズを布で拭く。",
            readingSession: firstLighthouseReading
        )
        modelContext.insert(comprehensionQuestion)
        modelContext.insert(
            Answer(
                id: sampleID(number: 41),
                answeredDateTime: sampleDateTime(secondsFromStart: 4_300),
                text: "レンズを布で拭く",
                isCorrect: true,
                question: comprehensionQuestion
            )
        )

        let summaryTrueFalseQuestion = Question(
            id: sampleID(number: 32),
            createdDateTime: sampleDateTime(secondsFromStart: 4_261),
            kind: .summaryTrueFalse,
            text: "要約「霧の濃い日は、灯りだけで船に岬の位置が伝わる」は本文と合っているか",
            choices: ["合っている", "合っていない"],
            modelAnswer: "合っていない",
            evidenceQuote: "霧の濃い日は、灯りだけでは船に届かない。",
            readingSession: firstLighthouseReading
        )
        modelContext.insert(summaryTrueFalseQuestion)
        modelContext.insert(
            Answer(
                id: sampleID(number: 42),
                answeredDateTime: sampleDateTime(secondsFromStart: 4_360),
                text: "合っている",
                isCorrect: false,
                question: summaryTrueFalseQuestion
            )
        )

        let fillInTheBlankQuestion = Question(
            id: sampleID(number: 33),
            createdDateTime: sampleDateTime(secondsFromStart: 4_262),
            kind: .fillInTheBlank,
            text: "三枝は霧笛を＿＿おきに鳴らした",
            choices: [],
            modelAnswer: "三十秒",
            evidenceQuote: "三枝は霧笛を三十秒おきに鳴らし、沖の漁船に岬の位置を知らせた。",
            readingSession: firstLighthouseReading
        )
        modelContext.insert(fillInTheBlankQuestion)
        modelContext.insert(
            Answer(
                id: sampleID(number: 43),
                answeredDateTime: sampleDateTime(secondsFromStart: 4_420),
                text: "三分",
                isCorrect: false,
                question: fillInTheBlankQuestion
            )
        )
        // 履歴から答え直した回答。同じ問いに、合っていない回答と合っている回答の両方がある状態を作る。
        modelContext.insert(
            Answer(
                id: sampleID(number: 44),
                answeredDateTime: sampleDateTime(secondsFromStart: 93_000),
                text: "三十秒",
                isCorrect: true,
                question: fillInTheBlankQuestion
            )
        )

        let writtenQuestion = Question(
            id: sampleID(number: 34),
            createdDateTime: sampleDateTime(secondsFromStart: 4_263),
            kind: .written,
            text: "三枝が霧の濃い日に霧笛を鳴らすのはなぜか",
            choices: [],
            modelAnswer: "灯りだけでは船に届かないので、音で岬の位置を知らせるため",
            evidenceQuote: "霧の濃い日は、灯りだけでは船に届かない。",
            readingSession: firstLighthouseReading
        )
        modelContext.insert(writtenQuestion)
        modelContext.insert(
            Answer(
                id: sampleID(number: 45),
                answeredDateTime: sampleDateTime(secondsFromStart: 4_480),
                text: "灯りが届かないから、音で岬の場所を伝えるため",
                isCorrect: true,
                question: writtenQuestion
            )
        )

        let secondLighthouseReading = ReadingSession(
            id: sampleID(number: 12),
            startedDateTime: sampleDateTime(secondsFromStart: 86_400),
            endedDateTime: sampleDateTime(secondsFromStart: 90_000),
            book: lighthouseBook
        )
        modelContext.insert(secondLighthouseReading)
        modelContext.insert(
            CapturedPage(
                id: sampleID(number: 23),
                capturedDateTime: sampleDateTime(secondsFromStart: 86_500),
                text: "冬の嵐の夜、灯台の電源が落ちた。三枝は予備の発電機を回し、朝まで灯りを絶やさなかった。",
                readingSession: secondLighthouseReading
            )
        )
        let secondReadingQuestion = Question(
            id: sampleID(number: 35),
            createdDateTime: sampleDateTime(secondsFromStart: 90_060),
            kind: .comprehension,
            text: "灯台の電源が落ちた夜、三枝は何を回したか",
            choices: ["予備の発電機", "風車", "レンズ", "霧笛の弁"],
            modelAnswer: "予備の発電機",
            evidenceQuote: "三枝は予備の発電機を回し、朝まで灯りを絶やさなかった。",
            readingSession: secondLighthouseReading
        )
        modelContext.insert(secondReadingQuestion)
        modelContext.insert(
            Answer(
                id: sampleID(number: 46),
                answeredDateTime: sampleDateTime(secondsFromStart: 90_100),
                text: "風車",
                isCorrect: false,
                question: secondReadingQuestion
            )
        )

        let compostBook = Book(
            id: sampleID(number: 2),
            createdDateTime: sampleDateTime(secondsFromStart: 172_800),
            title: "はじめての堆肥づくり",
            questionKinds: [.summaryTrueFalse],
            questionGuidance: nil
        )
        modelContext.insert(compostBook)
        let compostReading = ReadingSession(
            id: sampleID(number: 13),
            startedDateTime: sampleDateTime(secondsFromStart: 173_000),
            endedDateTime: sampleDateTime(secondsFromStart: 175_000),
            book: compostBook
        )
        modelContext.insert(compostReading)
        modelContext.insert(
            CapturedPage(
                id: sampleID(number: 24),
                capturedDateTime: sampleDateTime(secondsFromStart: 173_100),
                text: "堆肥は、落ち葉と生ごみを交互に重ねて作る。週に一度かき混ぜて空気を入れると、分解が早く進む。",
                readingSession: compostReading
            )
        )
        let compostQuestion = Question(
            id: sampleID(number: 36),
            createdDateTime: sampleDateTime(secondsFromStart: 175_060),
            kind: .summaryTrueFalse,
            text: "要約「堆肥は週に一度かき混ぜると分解が早く進む」は本文と合っているか",
            choices: ["合っている", "合っていない"],
            modelAnswer: "合っている",
            evidenceQuote: "週に一度かき混ぜて空気を入れると、分解が早く進む。",
            readingSession: compostReading
        )
        modelContext.insert(compostQuestion)
        modelContext.insert(
            Answer(
                id: sampleID(number: 47),
                answeredDateTime: sampleDateTime(secondsFromStart: 175_100),
                text: "合っている",
                isCorrect: true,
                question: compostQuestion
            )
        )

        try modelContext.save()
    }

    /// 保存データ (本・読書の記録・ページ・問い・回答) を、見本かどうかに関わらず全部消す。
    ///
    /// 本を消すとその下のデータも消えるが、本や読書の記録に属していないデータも残さないよう、5 つの型のそれぞれを消す。
    /// 何回実行しても、5 つの型のどれも 0 件になる。保存先への書き込みに失敗した時は、SwiftData のエラーを投げる。
    func deleteAllSavedData(modelContext: ModelContext) throws {
        try deleteAll(savedModelType: Book.self, modelContext: modelContext)
        try deleteAll(savedModelType: ReadingSession.self, modelContext: modelContext)
        try deleteAll(savedModelType: CapturedPage.self, modelContext: modelContext)
        try deleteAll(savedModelType: Question.self, modelContext: modelContext)
        try deleteAll(savedModelType: Answer.self, modelContext: modelContext)
    }

    /// 1 つの型の保存データを全部消して保存する。
    ///
    /// 型ごとに保存してから次の型を読むのは、親と一緒に消えたデータをもう一度消さないため。
    private func deleteAll<SavedModel: PersistentModel>(savedModelType _: SavedModel.Type, modelContext: ModelContext) throws {
        for savedModel in try modelContext.fetch(FetchDescriptor<SavedModel>()) {
            modelContext.delete(savedModel)
        }
        try modelContext.save()
    }
#endif
