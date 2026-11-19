import CoreGraphics
import Foundation
import SwiftData

/// 読書を始める。画面の取り込みを始め、始められた時だけ読書の記録を 1 件作って保存する。
///
/// 「読書を始める」を押してから取り込みを始めるまでの処理は、この関数だけに置く (始める前の判定を後から足す場所を 1 か所にするため)。
/// - 取り込みを始められなかった時は、`screenCapture.start()` の error をそのまま投げ、読書の記録を残さない
/// - 読書の記録の保存に失敗した時は、足した読書の記録を取り除き、取り込みを止めてから `save` の error を投げる
///
/// 保存先への書き込みは `save` で行う (アプリは `modelContext.save` を渡す。保存の失敗をテストで起こせるよう引数にしている)。
/// 冪等ではない: 読書 1 回ごとに読書の記録を 1 件作るため、呼ぶたびに取り込みを始め直して読書の記録が 1 件増える。
/// - Parameter currentDateTime: 今の日時を返す。取り込みが始まった時に 1 回呼び、読書を始めた日時にする
/// - Returns: 作った読書の記録と、取り込んだ画面の画像が順に届く流れ
func startReading(
    book: Book,
    screenCapture: any ScreenCapture,
    modelContext: ModelContext,
    currentDateTime: () -> Date,
    save: () throws -> Void
) async throws -> (readingSession: ReadingSession, capturedImages: AsyncThrowingStream<CGImage, any Error>) {
    let capturedImages = try await screenCapture.start()
    let readingSession = ReadingSession(id: UUID(), startedDateTime: currentDateTime(), endedDateTime: nil, book: book)
    modelContext.insert(readingSession)
    do {
        try save()
    } catch {
        modelContext.delete(readingSession)
        await screenCapture.stop()
        throw error
    }
    return (readingSession, capturedImages)
}

/// 取り込んだ画像が届くたびに本文を抽出し、読書の記録にページを足して保存する。画像の流れが終わるまで続ける。
///
/// - 抽出した本文は前後の空白と改行を除く。除いて空の時と、直前に足したページと同じ時は、ページを足さない
/// - 本文の抽出に失敗した画像は、ページを足さずに次の画像へ進む (1 枚の失敗で読書を止めないため)
/// - 画像は本文の抽出に渡すだけで、ファイルにも保存データにも書かない
/// - 流れが error で終わった時 (取り込みが途中で止まった時) と、ページの保存に失敗した時は、その error を投げる。それまでに足したページは残る
/// - 呼び出したタスクが取り消された時は `CancellationError` を投げる
///
/// 冪等ではない: 届いた画像ごとにページを足すため、同じ画像の流れは 1 回だけ渡す。
/// - Parameters:
///   - currentDateTime: 今の日時を返す。ページを足すたびに呼び、取り込んだ日時にする
///   - pauseAfterEachImage: 画像を 1 枚処理した後、次の画像を受け取るまで待つ時間 (同じページを繰り返し処理しないための間引き)
func saveCapturedPages(
    capturedImages: AsyncThrowingStream<CGImage, any Error>,
    readingSession: ReadingSession,
    pageTextExtractor: any PageTextExtractor,
    modelContext: ModelContext,
    currentDateTime: () -> Date,
    pauseAfterEachImage: Duration
) async throws {
    var lastPageText: String?
    for try await capturedImage in capturedImages {
        if let pageText = try await extractedPageText(image: capturedImage, pageTextExtractor: pageTextExtractor), !pageText.isEmpty, pageText != lastPageText {
            modelContext.insert(CapturedPage(id: UUID(), capturedDateTime: currentDateTime(), text: pageText, readingSession: readingSession))
            try modelContext.save()
            lastPageText = pageText
        }
        try await Task.sleep(for: pauseAfterEachImage)
    }
}

/// 画像から抽出した本文を、前後の空白と改行を除いて返す。
///
/// 抽出に失敗した時は nil を返す。呼び出したタスクが取り消された時だけは、`CancellationError` を投げる。
private func extractedPageText(image: CGImage, pageTextExtractor: any PageTextExtractor) async throws -> String? {
    do {
        return try await pageTextExtractor.extractPageText(image: image).trimmingCharacters(in: .whitespacesAndNewlines)
    } catch let cancellationError as CancellationError {
        throw cancellationError
    } catch {
        return nil
    }
}

/// 読書を終える。取り込みを止め、ページを足す処理が終わるのを待ってから、読書の記録に終えた日時を入れて保存する。
///
/// 取り込みの実物は、止める直前に取り込んだ 1 枚が止めた後に届くことがあるため、ページを足す処理が終わってから終えた日時を入れる。
/// ページを足す処理が error で終わっていても (取り込みが途中で止まった時)、終えた日時を入れる。
/// 既に終えた日時が入っている読書の記録には何もしない (何度呼んでも、最初に入れた終えた日時のままになる)。
/// 保存に失敗した時は、SwiftData の error を投げる。
/// - Parameters:
///   - pageSaving: この読書の `saveCapturedPages` を動かしているタスク
///   - currentDateTime: 今の日時を返す。終えた日時を入れる時に 1 回呼ぶ
func endReading(
    readingSession: ReadingSession,
    screenCapture: any ScreenCapture,
    pageSaving: Task<Void, any Error>,
    modelContext: ModelContext,
    currentDateTime: () -> Date
) async throws {
    await screenCapture.stop()
    _ = await pageSaving.result
    guard readingSession.endedDateTime == nil else {
        return
    }
    readingSession.endedDateTime = currentDateTime()
    try modelContext.save()
}

/// 読書中の画面で、画像を 1 枚処理した後に次の画像を受け取るまで待つ時間。
///
/// 1 秒にした理由: ページをめくる間隔は秒の単位で、1 秒に 1 回の文字認識でもページを取りこぼしにくく、届いた画面を全部文字認識するより処理が減るため。
/// 電池の消費への効果と、めくってから 1 秒未満で次へ進む読み方での取りこぼしは、実機で計測していない。
let readingPauseAfterEachImage = Duration.seconds(1)

/// 読書を始めてから今までの時間を、分の単位の文にして返す (例: 「18 分」)。1 分に満たない端数は切り捨てる。
///
/// `currentDateTime` が `startedDateTime` より前の時 (端末の時計を戻した時) は「0 分」を返す。
func readingElapsedTimeText(startedDateTime: Date, currentDateTime: Date) -> String {
    "\(max(0, Int(currentDateTime.timeIntervalSince(startedDateTime) / 60))) 分"
}

/// 取り込みを始められなかった時に、本の画面に出す案内の文を返す。
///
/// 呼び出したタスクが取り消されて始めなかった時 (`CancellationError`) は、利用者に伝えることが無いため nil を返す。
func readingStartFailureGuide(error: any Error) -> String? {
    switch error {
    case is CancellationError:
        nil
    case let startError as ScreenCaptureStartError:
        switch startError {
        case .selectionCancelled:
            "取り込みを始めませんでした\n読書を始めるには 次の画面で画面全体を選んでください"
        case .unavailable:
            "この iPhone では画面の取り込みを使えないため 読書を始められません"
        }
    default:
        "読書を始められませんでした\n\(error)"
    }
}
