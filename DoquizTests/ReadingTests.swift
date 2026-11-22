import CoreGraphics
import Foundation
import Security
import SwiftData
import Testing

@testable import Doquiz

/// 読書を始めてから終えるまでの処理を、偽の取り込みと偽の本文の抽出を使い、端末に書き込まないメモリ内の保存先で確かめる。
struct ReadingTests {
    /// 読書の処理を実行する context。
    private let writingContext: ModelContext
    /// 保存先に書かれた結果を読む context。書いた context に残っている値ではなく、保存先の値を確かめるために分ける。
    private let readingContext: ModelContext
    /// 読書の記録を属させる本。
    private let book: Book
    /// 購入していない利用者の、偽の購入。無料の回数を確かめないテストは、無料の回数を 1 回も使っていない状態でこれを渡す。
    private let notPurchasedService = makeDeveloperMenuFakePurchaseService(behavior: .returnsPackages)

    /// テストごとに、メモリ内の保存先を新しく作り、本を 1 冊保存する。
    init() throws {
        let modelContainer = try makeModelContainer(isStoredInMemoryOnly: true)
        writingContext = ModelContext(modelContainer)
        readingContext = ModelContext(modelContainer)
        book = Book(id: UUID(), createdDateTime: Date(timeIntervalSince1970: 0), title: "潮見町の灯台日誌", questionKinds: QuestionKind.allCases, questionGuidance: nil)
        writingContext.insert(book)
        try writingContext.save()
    }

    /// 偽の取り込みに起こさせる失敗。
    private struct ReadingFailure: Error {}

    /// 幅が `width` で高さが 1 の画像を作る。偽の本文の抽出が、幅で画像を見分ける。
    private func makeImage(width: Int) throws -> CGImage {
        try #require(
            CGContext(
                data: nil,
                width: width,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        )
    }

    /// 偽の取り込みの受け取り側が、画像を渡し切って `stop()` を待ち始めるまで待つ。
    /// テストが制限時間で取り消された時は `CancellationError` を投げる (待ち始めない不具合で、テストが終わらなくなるのを防ぐ)。
    private func waitUntilWaitingForStop(capture: FakeScreenCapture) async throws {
        while !capture.isWaitingForStop {
            try Task.checkCancellation()
            await Task.yield()
        }
    }

    /// 保存先にあるページの本文を、取り込んだ日時の古い順に返す。
    private func savedPageTexts() throws -> [String] {
        try readingContext.fetch(FetchDescriptor<CapturedPage>(sortBy: [SortDescriptor(\.capturedDateTime)])).map(\.text)
    }

    /// 幅 1・2・3… の画像を `pageTextsByImageWidth` の件数だけ流す読書を始め、流し切るまでページを足してから、読書を終える。
    /// - Returns: 作られた読書の記録
    private func readThroughImages(pageTextsByImageWidth: [Int: String]) async throws -> ReadingSession {
        let capture = FakeScreenCapture(
            images: try (1...pageTextsByImageWidth.count).map { try makeImage(width: $0) },
            startError: nil,
            interruptionError: nil
        )
        let dateTimes = IncreasingDateTimes()
        let startedReading = try await startReading(
            book: book,
            purchaseService: notPurchasedService,
            loadFreeReadingStartCount: { 0 },
            countFreeReadingStart: {},
            screenCapture: capture,
            modelContext: writingContext,
            currentDateTime: dateTimes.next,
            save: writingContext.save
        )
        let pageSaving = Task {
            try await saveCapturedPages(
                capturedImages: startedReading.capturedImages,
                readingSession: startedReading.readingSession,
                pageTextExtractor: ImageWidthPageTextExtractor(pageTextsByImageWidth: pageTextsByImageWidth),
                modelContext: writingContext,
                currentDateTime: dateTimes.next,
                pauseAfterEachImage: .zero,
                save: writingContext.save
            )
        }
        // 流し切る前に制限時間で抜けた時も、ページを足すタスクを残さない。
        defer { pageSaving.cancel() }
        try await waitUntilWaitingForStop(capture: capture)
        _ = try await endReading(
            readingSession: startedReading.readingSession,
            screenCapture: capture,
            pageSaving: pageSaving,
            currentDateTime: dateTimes.next,
            save: writingContext.save
        )
        return startedReading.readingSession
    }

    /// 読書を始めると、選んだ本に属し、始めた日時が入り、終えた日時が入っていない読書の記録が 1 件保存される。
    @Test func 読書を始めると本と始めた日時を持つ読書の記録が1件保存される() async throws {
        let capture = FakeScreenCapture(images: [], startError: nil, interruptionError: nil)

        let startedReading = try await startReading(
            book: book,
            purchaseService: notPurchasedService,
            loadFreeReadingStartCount: { 0 },
            countFreeReadingStart: {},
            screenCapture: capture,
            modelContext: writingContext,
            currentDateTime: { Date(timeIntervalSince1970: 1_000) },
            save: writingContext.save
        )

        let fetchedReadingSessions = try readingContext.fetch(FetchDescriptor<ReadingSession>())
        try #require(fetchedReadingSessions.count == 1)
        #expect(fetchedReadingSessions[0].id == startedReading.readingSession.id)
        #expect(fetchedReadingSessions[0].book?.id == book.id)
        #expect(fetchedReadingSessions[0].startedDateTime == Date(timeIntervalSince1970: 1_000))
        #expect(fetchedReadingSessions[0].endedDateTime == nil)
        #expect(fetchedReadingSessions[0].capturedPages.isEmpty)
        capture.stop()
    }

    /// 画像を 3 枚流し、2 枚目と 3 枚目の本文が同じ時、保存されるページは 2 件で、取り込んだ順に並び、どれも始めた読書の記録に属する。
    @Test(.timeLimit(.minutes(1))) func 直前のページと本文が同じ画像ではページを足さず取り込んだ順に並ぶ() async throws {
        let readingSession = try await readThroughImages(pageTextsByImageWidth: [1: "一枚目の本文", 2: "二枚目の本文", 3: "二枚目の本文"])

        #expect(try savedPageTexts() == ["一枚目の本文", "二枚目の本文"])
        #expect(try readingContext.fetch(FetchDescriptor<CapturedPage>()).allSatisfy { $0.readingSession?.id == readingSession.id })
    }

    /// 同じ本文でも、間に違う本文のページを挟んでいれば足す (比べる相手は直前のページだけ)。
    @Test(.timeLimit(.minutes(1))) func 前に戻って同じ本文が間を空けて届いた時はページを足す() async throws {
        _ = try await readThroughImages(pageTextsByImageWidth: [1: "一枚目の本文", 2: "二枚目の本文", 3: "一枚目の本文"])

        #expect(try savedPageTexts() == ["一枚目の本文", "二枚目の本文", "一枚目の本文"])
    }

    /// 本文が空の画像と、空白と改行だけの画像ではページを足さず、本文のある画像のページだけが残る。
    /// 空の画像を挟んでも、その前のページと同じ本文は足さない。
    @Test(.timeLimit(.minutes(1))) func 本文が空の画像ではページを足さない() async throws {
        _ = try await readThroughImages(pageTextsByImageWidth: [1: "", 2: "一枚目の本文", 3: " \n　", 4: "一枚目の本文", 5: "二枚目の本文"])

        #expect(try savedPageTexts() == ["一枚目の本文", "二枚目の本文"])
    }

    /// 抽出した本文の前後の空白と改行は除いて保存し、前後の空白だけが違う本文は同じページとして扱う。
    @Test(.timeLimit(.minutes(1))) func 本文の前後の空白と改行は除いて保存する() async throws {
        _ = try await readThroughImages(pageTextsByImageWidth: [1: "\n 一枚目の 本文 \n", 2: "一枚目の 本文"])

        #expect(try savedPageTexts() == ["一枚目の 本文"])
    }

    /// 本文の抽出に失敗した画像はページを足さずに飛ばし、後の画像のページは足す。
    @Test(.timeLimit(.minutes(1))) func 本文の抽出に失敗した画像は飛ばして次の画像へ進む() async throws {
        let capture = FakeScreenCapture(
            images: [try makeImage(width: 1), try makeImage(width: 2), try makeImage(width: 3)],
            startError: nil,
            interruptionError: nil
        )
        let startedReading = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date() }, save: writingContext.save)
        let dateTimes = IncreasingDateTimes()
        let pageSaving = Task {
            try await saveCapturedPages(
                capturedImages: startedReading.capturedImages,
                readingSession: startedReading.readingSession,
                // 幅 2 の画像の本文を決めていないため、2 枚目の抽出が失敗する。
                pageTextExtractor: ImageWidthPageTextExtractor(pageTextsByImageWidth: [1: "一枚目の本文", 3: "三枚目の本文"]),
                modelContext: writingContext,
                currentDateTime: dateTimes.next,
                pauseAfterEachImage: .zero,
                save: writingContext.save
            )
        }
        defer { pageSaving.cancel() }
        try await waitUntilWaitingForStop(capture: capture)
        capture.stop()
        try await pageSaving.value

        #expect(try savedPageTexts() == ["一枚目の本文", "三枚目の本文"])
    }

    /// 「読書を終える」の処理の後、読書の記録に終えた日時が入り、取り込みが止まっている (画像の流れが終わっている)。
    @Test(.timeLimit(.minutes(1))) func 読書を終えると終えた日時が入り取り込みが止まる() async throws {
        let capture = FakeScreenCapture(images: [try makeImage(width: 1)], startError: nil, interruptionError: nil)
        let startedReading = try await startReading(
            book: book,
            purchaseService: notPurchasedService,
            loadFreeReadingStartCount: { 0 },
            countFreeReadingStart: {},
            screenCapture: capture,
            modelContext: writingContext,
            currentDateTime: { Date(timeIntervalSince1970: 1_000) },
            save: writingContext.save
        )
        let pageSaving = Task {
            try await saveCapturedPages(
                capturedImages: startedReading.capturedImages,
                readingSession: startedReading.readingSession,
                pageTextExtractor: FixedPageTextExtractor(pageText: "一枚目の本文"),
                modelContext: writingContext,
                currentDateTime: { Date(timeIntervalSince1970: 1_500) },
                pauseAfterEachImage: .zero,
                save: writingContext.save
            )
        }
        defer { pageSaving.cancel() }
        try await waitUntilWaitingForStop(capture: capture)

        #expect(
            try await endReading(
                readingSession: startedReading.readingSession,
                screenCapture: capture,
                pageSaving: pageSaving,
                currentDateTime: { Date(timeIntervalSince1970: 2_000) },
                save: writingContext.save
            ) == nil
        )

        let fetchedReadingSessions = try readingContext.fetch(FetchDescriptor<ReadingSession>())
        try #require(fetchedReadingSessions.count == 1)
        #expect(fetchedReadingSessions[0].endedDateTime == Date(timeIntervalSince1970: 2_000))
        #expect(fetchedReadingSessions[0].capturedPages.map(\.text) == ["一枚目の本文"])
        #expect(capture.isWaitingForStop == false)
        for try await _ in startedReading.capturedImages {
            Issue.record("読書を終えた後に、取り込んだ画像が届いた")
        }
        // ページを足す処理は、取り消されずに終わっている。
        try await pageSaving.value
    }

    /// 読書を終える処理を 2 回呼んでも、終えた日時は 1 回目に入れた値のままになる。
    @Test(.timeLimit(.minutes(1))) func 読書を2回終えても終えた日時は最初の値のまま() async throws {
        let capture = FakeScreenCapture(images: [], startError: nil, interruptionError: nil)
        let startedReading = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date(timeIntervalSince1970: 1_000) }, save: writingContext.save)
        let pageSaving = Task {
            try await saveCapturedPages(
                capturedImages: startedReading.capturedImages,
                readingSession: startedReading.readingSession,
                pageTextExtractor: FixedPageTextExtractor(pageText: "一枚目の本文"),
                modelContext: writingContext,
                currentDateTime: { Date() },
                pauseAfterEachImage: .zero,
                save: writingContext.save
            )
        }
        defer { pageSaving.cancel() }

        for endedSeconds in [2_000.0, 3_000.0] {
            _ = try await endReading(
                readingSession: startedReading.readingSession,
                screenCapture: capture,
                pageSaving: pageSaving,
                currentDateTime: { Date(timeIntervalSince1970: endedSeconds) },
                save: writingContext.save
            )
        }

        #expect(try readingContext.fetch(FetchDescriptor<ReadingSession>()).map(\.endedDateTime) == [Date(timeIntervalSince1970: 2_000)])
    }

    /// 取り込みを始められなかった時は、取り込みの error がそのまま投げられ、読書の記録が 1 件も残らない。
    @Test func 取り込みを始められなかった時は読書の記録が残らない() async throws {
        do {
            _ = try await startReading(
                book: book,
                purchaseService: notPurchasedService,
                loadFreeReadingStartCount: { 0 },
                countFreeReadingStart: {},
                screenCapture: FakeScreenCapture(images: [try makeImage(width: 1)], startError: ScreenCaptureStartError.selectionCancelled, interruptionError: nil),
                modelContext: writingContext,
                currentDateTime: { Date() },
                save: writingContext.save
            )
            Issue.record("始められなかったのに error が投げられなかった")
        } catch {
            #expect(error as? ScreenCaptureStartError == .selectionCancelled)
        }

        try writingContext.save()
        #expect(try readingContext.fetchCount(FetchDescriptor<ReadingSession>()) == 0)
        #expect(try #require(try readingContext.fetch(FetchDescriptor<Book>()).first).readingSessions.isEmpty)
    }

    /// 読書の記録の保存に失敗した時は、`save` の error が投げられ、読書の記録が残らず、始めた取り込みが 1 回止められている。
    @Test func 読書の記録を保存できなかった時は記録を残さず取り込みを止める() async throws {
        let capture = StopCountingScreenCapture()

        await #expect(throws: SaveFailure.self) {
            _ = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date() }, save: { throw SaveFailure() })
        }

        #expect(capture.startCount == 1)
        #expect(capture.stopCount == 1)
        try writingContext.save()
        #expect(try readingContext.fetchCount(FetchDescriptor<ReadingSession>()) == 0)
    }

    /// 読書の記録を保存できた時は、始めた取り込みを止めない (保存の失敗の時だけ止めることの、反対側の確認)。
    @Test func 読書の記録を保存できた時は取り込みを止めない() async throws {
        let capture = StopCountingScreenCapture()

        _ = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date() }, save: writingContext.save)

        #expect(capture.startCount == 1)
        #expect(capture.stopCount == 0)
    }

    /// 取り込みが途中で止まった時は、ページを足す処理が取り込みの error を投げ、止まるまでのページは残る。
    /// その後に読書を終えると、終えた日時が入る。
    @Test(.timeLimit(.minutes(1))) func 取り込みが途中で止まった時は止まるまでのページが残り読書を終えられる() async throws {
        let capture = FakeScreenCapture(images: [try makeImage(width: 1), try makeImage(width: 2)], startError: nil, interruptionError: ReadingFailure())
        let startedReading = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date(timeIntervalSince1970: 1_000) }, save: writingContext.save)
        let dateTimes = IncreasingDateTimes()
        let pageSaving = Task {
            try await saveCapturedPages(
                capturedImages: startedReading.capturedImages,
                readingSession: startedReading.readingSession,
                pageTextExtractor: ImageWidthPageTextExtractor(pageTextsByImageWidth: [1: "一枚目の本文", 2: "二枚目の本文"]),
                modelContext: writingContext,
                currentDateTime: dateTimes.next,
                pauseAfterEachImage: .zero,
                save: writingContext.save
            )
        }
        defer { pageSaving.cancel() }

        await #expect(throws: ReadingFailure.self) {
            try await pageSaving.value
        }
        #expect(try savedPageTexts() == ["一枚目の本文", "二枚目の本文"])

        #expect(
            try await endReading(
                readingSession: startedReading.readingSession,
                screenCapture: capture,
                pageSaving: pageSaving,
                currentDateTime: { Date(timeIntervalSince1970: 2_000) },
                save: writingContext.save
            ) is ReadingFailure
        )
        #expect(try readingContext.fetch(FetchDescriptor<ReadingSession>()).map(\.endedDateTime) == [Date(timeIntervalSince1970: 2_000)])
    }

    /// 本文の抽出が取り消しで終わった時は、飛ばさずに `CancellationError` を投げ、後の画像のページを足さない。
    @Test(.timeLimit(.minutes(1))) func 本文の抽出が取り消された時は飛ばさずに取り消しを投げる() async throws {
        let capture = FakeScreenCapture(images: [try makeImage(width: 1), try makeImage(width: 2)], startError: nil, interruptionError: nil)
        let startedReading = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date() }, save: writingContext.save)

        await #expect(throws: CancellationError.self) {
            try await saveCapturedPages(
                capturedImages: startedReading.capturedImages,
                readingSession: startedReading.readingSession,
                pageTextExtractor: CancelledPageTextExtractor(),
                modelContext: writingContext,
                currentDateTime: { Date() },
                pauseAfterEachImage: .zero,
                save: writingContext.save
            )
        }

        capture.stop()
        #expect(try savedPageTexts().isEmpty)
    }

    /// ページの保存に失敗した時は、`save` の error を投げ、後の画像へ進まない。
    @Test(.timeLimit(.minutes(1))) func ページを保存できなかった時は保存の失敗を投げる() async throws {
        let capture = FakeScreenCapture(images: [try makeImage(width: 1), try makeImage(width: 2)], startError: nil, interruptionError: nil)
        let startedReading = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date() }, save: writingContext.save)
        let saveCounter = SaveCounter()

        await #expect(throws: SaveFailure.self) {
            try await saveCapturedPages(
                capturedImages: startedReading.capturedImages,
                readingSession: startedReading.readingSession,
                pageTextExtractor: ImageWidthPageTextExtractor(pageTextsByImageWidth: [1: "一枚目の本文", 2: "二枚目の本文"]),
                modelContext: writingContext,
                currentDateTime: { Date() },
                pauseAfterEachImage: .zero,
                save: {
                    saveCounter.count += 1
                    throw SaveFailure()
                }
            )
        }

        capture.stop()
        #expect(saveCounter.count == 1)
        // 保存できなかったページが context に残っていれば、この保存で保存先に書かれる。
        try writingContext.save()
        #expect(try savedPageTexts().isEmpty)
    }

    /// 読書を終える時に読書の記録を保存できなかった時は、`save` の error を投げ、入れた終えた日時は読書の記録に残る。
    @Test(.timeLimit(.minutes(1))) func 読書を終える時に保存できなかった時は保存の失敗を投げる() async throws {
        let capture = FakeScreenCapture(images: [], startError: nil, interruptionError: nil)
        let startedReading = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date() }, save: writingContext.save)
        let pageSaving = Task {
            try await saveCapturedPages(
                capturedImages: startedReading.capturedImages,
                readingSession: startedReading.readingSession,
                pageTextExtractor: FixedPageTextExtractor(pageText: "一枚目の本文"),
                modelContext: writingContext,
                currentDateTime: { Date() },
                pauseAfterEachImage: .zero,
                save: writingContext.save
            )
        }
        defer { pageSaving.cancel() }

        await #expect(throws: SaveFailure.self) {
            _ = try await endReading(
                readingSession: startedReading.readingSession,
                screenCapture: capture,
                pageSaving: pageSaving,
                currentDateTime: { Date(timeIntervalSince1970: 2_000) },
                save: { throw SaveFailure() }
            )
        }
        // 入れた終えた日時は読書の記録に残り、次の保存で保存先に書かれる。
        try writingContext.save()
        #expect(try readingContext.fetch(FetchDescriptor<ReadingSession>()).map(\.endedDateTime) == [Date(timeIntervalSince1970: 2_000)])
    }

    /// 読書を終えた時の案内は、ページを足す処理が error で終わっていた時だけ途中で止まったことを伝え、最後まで動いた時は無い。
    @Test func 読書を終えた時の案内は途中で止まった時だけ出る() throws {
        #expect(try #require(readingEndGuide(pageSavingError: ReadingFailure())).contains("取り込みが途中で止まったため 読書を終えました"))
        #expect(readingEndGuide(pageSavingError: nil) == nil)
    }

    /// 読書を終える時に保存できなかった時の案内は、保存できなかったことと error の内容を含む。
    @Test func 読書を終える時に保存できなかった時の案内はエラーの内容を含む() {
        #expect(readingEndSaveFailureGuide(error: ReadingFailure()).contains("読書の記録を保存できませんでした"))
        #expect(readingEndSaveFailureGuide(error: ReadingFailure()).contains("ReadingFailure"))
    }

    /// 画像を 1 枚処理した後の待ちの間に取り消されると、次の画像を待たずに `CancellationError` を投げる。足したページは残る。
    @Test(.timeLimit(.minutes(1))) func 画像を処理した後の待ちの間に取り消されると取り消しを投げる() async throws {
        let capture = FakeScreenCapture(images: [try makeImage(width: 1)], startError: nil, interruptionError: nil)
        let startedReading = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date() }, save: writingContext.save)
        let pageSaving = Task {
            try await saveCapturedPages(
                capturedImages: startedReading.capturedImages,
                readingSession: startedReading.readingSession,
                pageTextExtractor: FixedPageTextExtractor(pageText: "一枚目の本文"),
                modelContext: writingContext,
                currentDateTime: { Date() },
                // テストの制限時間 (1 分) より長く待たせ、待ちが取り消しで終わらなければテストが落ちるようにする。
                pauseAfterEachImage: .seconds(600),
                save: writingContext.save
            )
        }
        defer { pageSaving.cancel() }
        while try savedPageTexts().isEmpty {
            try Task.checkCancellation()
            await Task.yield()
        }

        pageSaving.cancel()

        await #expect(throws: CancellationError.self) {
            try await pageSaving.value
        }
        capture.stop()
        #expect(try savedPageTexts() == ["一枚目の本文"])
    }

    /// ページを足す処理が取り消しで終わっていた時は、読書を終える処理が error を返さず、終えた日時は入る。
    @Test(.timeLimit(.minutes(1))) func ページを足す処理が取り消しで終わった時は読書を終えてもerrorを返さない() async throws {
        let capture = FakeScreenCapture(images: [], startError: nil, interruptionError: nil)
        let startedReading = try await startReading(book: book, purchaseService: notPurchasedService, loadFreeReadingStartCount: { 0 }, countFreeReadingStart: {}, screenCapture: capture, modelContext: writingContext, currentDateTime: { Date(timeIntervalSince1970: 1_000) }, save: writingContext.save)
        let pageSaving = Task<Void, any Error> {
            throw CancellationError()
        }

        #expect(
            try await endReading(
                readingSession: startedReading.readingSession,
                screenCapture: capture,
                pageSaving: pageSaving,
                currentDateTime: { Date(timeIntervalSince1970: 2_000) },
                save: writingContext.save
            ) == nil
        )
        #expect(try readingContext.fetch(FetchDescriptor<ReadingSession>()).map(\.endedDateTime) == [Date(timeIntervalSince1970: 2_000)])
    }

    /// 読んだ時間の文は、分に満たない端数を切り捨て、始めた日時より前の日時では「0 分」になる。
    @Test(arguments: [
        (0.0, "0 分"),
        (59.0, "0 分"),
        (60.0, "1 分"),
        (119.0, "1 分"),
        (18 * 60.0, "18 分"),
        (90 * 60.0, "90 分"),
        (-120.0, "0 分"),
    ])
    func 読んだ時間は分の単位で端数を切り捨てる(elapsedSeconds: Double, expectedText: String) {
        #expect(
            readingElapsedTimeText(
                startedDateTime: Date(timeIntervalSince1970: 10_000),
                currentDateTime: Date(timeIntervalSince1970: 10_000 + elapsedSeconds)
            ) == expectedText
        )
    }

    /// 始められなかった時の案内は、選択をやめた時は画面全体を選ぶ案内、取り込みを使えない時は使えないことの案内、
    /// 無料の回数を使い切った時は購入のプランを選ぶ案内、それ以外の error ではその内容を含む案内になり、タスクの取り消しでは案内が無い。
    @Test func 始められなかった時の案内は理由ごとに分かれる() throws {
        #expect(
            readingStartFailureGuide(error: FreeReadingsUsedUpError()) == "無料で始められる読書を使い切りました\n続けて読むには購入のプランを選んでください"
        )
        #expect(
            readingStartFailureGuide(error: PurchaseStateUnavailableError(underlyingError: RevenueCatNotConfiguredError()))
                == "購入の状態を確かめられませんでした\n通信できる所でもう一度「読書を始める」を押してください"
        )
        #expect(
            readingStartFailureGuide(error: FreeReadingStartCountUnavailableError())
                == "無料で始めた読書の回数を読み書きできませんでした\nもう一度「読書を始める」を押してください"
        )
        #expect(
            readingStartFailureGuide(error: FreeReadingStartCountKeychainError(status: errSecInteractionNotAllowed))
                == "無料で始めた読書の回数を読み書きできませんでした\nもう一度「読書を始める」を押してください"
        )
        #expect(try #require(readingStartFailureGuide(error: ScreenCaptureStartError.selectionCancelled)).contains("画面全体を選んでください"))
        #expect(try #require(readingStartFailureGuide(error: ScreenCaptureStartError.unavailable)).contains("画面の取り込みを使えない"))
        #expect(try #require(readingStartFailureGuide(error: ReadingFailure())).contains("ReadingFailure"))
        #expect(readingStartFailureGuide(error: CancellationError()) == nil)
    }

    /// 購入していない利用者は、無料で 19 回始めた後の 20 回目の読書を始められ、取り込みが始まり、読書の記録が残り、無料の回数を 1 回数える。
    @Test func 購入していない時は20回目の読書を始められて回数を数える() async throws {
        let capture = StopCountingScreenCapture()
        let freeReadingStartCounter = FreeReadingStartCounter(count: 19)

        _ = try await startReading(
            book: book,
            purchaseService: notPurchasedService,
            loadFreeReadingStartCount: { freeReadingStartCounter.count },
            countFreeReadingStart: freeReadingStartCounter.increment,
            screenCapture: capture,
            modelContext: writingContext,
            currentDateTime: { Date() },
            save: writingContext.save
        )

        #expect(capture.startCount == 1)
        #expect(freeReadingStartCounter.count == 20)
        #expect(try readingContext.fetchCount(FetchDescriptor<ReadingSession>()) == 1)
    }

    /// 購入していない利用者が無料で 20 回始めた後の 21 回目は、取り込みを始めずに `FreeReadingsUsedUpError` を投げ、
    /// 読書の記録を残さず、無料の回数を数えない。上限より多い回数が入っている時 (21 回) も同じ。
    @Test(arguments: [20, 21])
    func 購入していない時は無料の回数を使い切った後に始めようとすると取り込みを始めない(freeReadingStartCount: Int) async throws {
        let capture = StopCountingScreenCapture()
        let freeReadingStartCounter = FreeReadingStartCounter(count: freeReadingStartCount)

        await #expect(throws: FreeReadingsUsedUpError.self) {
            _ = try await startReading(
                book: book,
                purchaseService: notPurchasedService,
                loadFreeReadingStartCount: { freeReadingStartCounter.count },
                countFreeReadingStart: freeReadingStartCounter.increment,
                screenCapture: capture,
                modelContext: writingContext,
                currentDateTime: { Date() },
                save: writingContext.save
            )
        }

        #expect(capture.startCount == 0)
        #expect(freeReadingStartCounter.count == freeReadingStartCount)
        try writingContext.save()
        #expect(try readingContext.fetchCount(FetchDescriptor<ReadingSession>()) == 0)
    }

    /// トライアル中と購入済みの利用者は、無料の回数を使い切っていても読書を始められ、その読書を無料の回数に数えない。
    @Test(arguments: [DeveloperMenuFakePurchaseBehavior.inTrial, .purchased])
    func トライアル中と購入済みの時は無料の回数を使い切っていても始められて回数を数えない(behavior: DeveloperMenuFakePurchaseBehavior) async throws {
        let capture = StopCountingScreenCapture()
        let freeReadingStartCounter = FreeReadingStartCounter(count: 20)

        _ = try await startReading(
            book: book,
            purchaseService: makeDeveloperMenuFakePurchaseService(behavior: behavior),
            loadFreeReadingStartCount: { freeReadingStartCounter.count },
            countFreeReadingStart: freeReadingStartCounter.increment,
            screenCapture: capture,
            modelContext: writingContext,
            currentDateTime: { Date() },
            save: writingContext.save
        )

        #expect(capture.startCount == 1)
        #expect(freeReadingStartCounter.count == 20)
        #expect(try readingContext.fetchCount(FetchDescriptor<ReadingSession>()) == 1)
    }

    /// 購入の状態を取得できない時 (RevenueCat の SDK を初期化していない単体テストの起動) は、残りの回数があっても使い切っていても、
    /// 取り込みを始めずに `PurchaseStateUnavailableError` を投げ、読書の記録を残さず、無料の回数を数えない
    /// (購入していない・購入済みのどちらかに写さない)。
    @Test(arguments: [0, 20])
    func 購入の状態を取得できない時は取り込みを始めずに投げる(freeReadingStartCount: Int) async throws {
        let capture = StopCountingScreenCapture()
        let freeReadingStartCounter = FreeReadingStartCounter(count: freeReadingStartCount)

        await #expect(throws: PurchaseStateUnavailableError.self) {
            _ = try await startReading(
                book: book,
                purchaseService: RevenueCatPurchaseService(),
                loadFreeReadingStartCount: { freeReadingStartCounter.count },
                countFreeReadingStart: freeReadingStartCounter.increment,
                screenCapture: capture,
                modelContext: writingContext,
                currentDateTime: { Date() },
                save: writingContext.save
            )
        }

        #expect(capture.startCount == 0)
        #expect(freeReadingStartCounter.count == freeReadingStartCount)
        try writingContext.save()
        #expect(try readingContext.fetchCount(FetchDescriptor<ReadingSession>()) == 0)
    }

    /// 無料の回数を保存できなかった時は、読書の記録を取り除き、取り込みを止めてから、保存の error を投げる (数えずに無料の読書を始めさせないため)。
    @Test func 無料の回数を保存できなかった時は読書を始めない() async throws {
        let capture = StopCountingScreenCapture()

        await #expect(throws: SaveFailure.self) {
            _ = try await startReading(
                book: book,
                purchaseService: notPurchasedService,
                loadFreeReadingStartCount: { 0 },
                countFreeReadingStart: { throw SaveFailure() },
                screenCapture: capture,
                modelContext: writingContext,
                currentDateTime: { Date() },
                save: writingContext.save
            )
        }

        #expect(capture.startCount == 1)
        #expect(capture.stopCount == 1)
        #expect(try readingContext.fetchCount(FetchDescriptor<ReadingSession>()) == 0)
    }

    /// 取り込みを始められなかった時と、読書の記録を保存できなかった時は、無料の回数を数えない (読書が始まっていないため)。
    @Test func 読書が始まらなかった時は無料の回数を数えない() async throws {
        let freeReadingStartCounter = FreeReadingStartCounter(count: 0)

        await #expect(throws: ScreenCaptureStartError.self) {
            _ = try await startReading(
                book: book,
                purchaseService: notPurchasedService,
                loadFreeReadingStartCount: { freeReadingStartCounter.count },
                countFreeReadingStart: freeReadingStartCounter.increment,
                screenCapture: FakeScreenCapture(images: [], startError: ScreenCaptureStartError.selectionCancelled, interruptionError: nil),
                modelContext: writingContext,
                currentDateTime: { Date() },
                save: writingContext.save
            )
        }
        await #expect(throws: SaveFailure.self) {
            _ = try await startReading(
                book: book,
                purchaseService: notPurchasedService,
                loadFreeReadingStartCount: { freeReadingStartCounter.count },
                countFreeReadingStart: freeReadingStartCounter.increment,
                screenCapture: StopCountingScreenCapture(),
                modelContext: writingContext,
                currentDateTime: { Date() },
                save: { throw SaveFailure() }
            )
        }

        #expect(freeReadingStartCounter.count == 0)
    }

    /// 無料で 5 回読み、トライアルを始めて 30 回読み、トライアルを解約した利用者は、残りの無料の回数が 15 回になる
    /// (owner の決定の例。https://github.com/bannzai/doquiz/issues/49#issuecomment-7007325068 )。
    @Test func トライアル中に始めた読書は無料の回数に数えない() async throws {
        let freeReadingStartCounter = FreeReadingStartCounter(count: 0)
        for purchaseBehavior in Array(repeating: DeveloperMenuFakePurchaseBehavior.returnsPackages, count: 5) + Array(repeating: .inTrial, count: 30) {
            _ = try await startReading(
                book: book,
                purchaseService: makeDeveloperMenuFakePurchaseService(behavior: purchaseBehavior),
                loadFreeReadingStartCount: { freeReadingStartCounter.count },
                countFreeReadingStart: freeReadingStartCounter.increment,
                screenCapture: StopCountingScreenCapture(),
                modelContext: writingContext,
                currentDateTime: { Date() },
                save: writingContext.save
            )
        }

        #expect(remainingFreeReadingStartCount(freeReadingStartCount: freeReadingStartCounter.count) == 15)
    }
}

/// 無料で始めた読書の回数を数える。アプリでは Keychain に保存する回数 (`FreeReadingStartCount`) の代わりに使う。
private final class FreeReadingStartCounter {
    /// これまでに無料で始めた読書の回数。
    private(set) var count: Int

    /// 初めの回数 `count` を決めて作る。
    init(count: Int) {
        self.count = count
    }

    /// 回数を 1 増やす。
    func increment() {
        count += 1
    }
}

/// 画像の幅ごとに決めた本文を返す、偽の `PageTextExtractor`。本文を決めていない幅の画像では抽出の失敗を投げる。
private nonisolated struct ImageWidthPageTextExtractor: PageTextExtractor {
    /// 本文を決めていない幅の画像を渡された時に投げる失敗。
    struct MissingPageText: Error {}

    /// 画像の幅と、その画像から抽出されたことにする本文。
    let pageTextsByImageWidth: [Int: String]

    /// `image` の幅に決めた本文を返す。決めていない幅の時は `MissingPageText` を投げる。
    func extractPageText(image: CGImage) async throws -> String {
        guard let pageText = pageTextsByImageWidth[image.width] else {
            throw MissingPageText()
        }
        return pageText
    }
}

/// 呼ぶたびに 1 秒ずつ進む日時を返す。ページの取り込んだ日時が、足した順に並ぶようにするために使う。
private final class IncreasingDateTimes {
    /// これまでに返した回数。
    private var count = 0

    /// 前に返した日時より 1 秒後の日時を返す (最初は 1970-01-01 00:00:01 UTC)。
    func next() -> Date {
        count += 1
        return Date(timeIntervalSince1970: TimeInterval(count))
    }
}

/// 始めた回数と止めた回数を数える、偽の `ScreenCapture`。画像は 1 枚も流さない。
private final class StopCountingScreenCapture: ScreenCapture {
    /// `start()` が呼ばれた回数。
    private(set) var startCount = 0
    /// `stop()` が呼ばれた回数。
    private(set) var stopCount = 0

    /// 呼ばれた回数を数え、画像を流さずにすぐ終わる流れを返す。
    func start() async throws -> AsyncThrowingStream<CGImage, any Error> {
        startCount += 1
        return AsyncThrowingStream { $0.finish() }
    }

    /// 呼ばれた回数を数える。
    func stop() async {
        stopCount += 1
    }
}

/// どの画像でも、取り消しで終わったことにする偽の `PageTextExtractor`。
private nonisolated struct CancelledPageTextExtractor: PageTextExtractor {
    /// 本文を返さず、`CancellationError` を投げる。
    func extractPageText(image: CGImage) async throws -> String {
        throw CancellationError()
    }
}

/// 保存先への書き込みが呼ばれた回数を数える。
private final class SaveCounter {
    /// 呼ばれた回数。
    var count = 0
}
