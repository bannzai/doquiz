import CoreGraphics
import Foundation
import SwiftData

/// 読書を始める。画面の取り込みを始め、始められた時だけ読書の記録を 1 件作って保存する。
///
/// 「読書を始める」を押してから取り込みを始めるまでの処理は、この関数だけに置く (始める前の判定を後から足す場所を 1 か所にするため)。
/// - 取り込みを始める前に、`purchaseService` から購入の状態を取り (`fetchPurchaseStateRetrying` で取得をやり直す)、
///   無料で始められる読書の判定 (`countsAsFreeReadingStart`) を通す。
///   使い切っていてトライアル中でも購入済みでもない時は、取り込みを始めずに `FreeReadingsUsedUpError` を投げ、読書の記録を残さない
/// - 取得をやり直しても購入の状態を取得できなかった時は、取り込みを始めずに `PurchaseStateUnavailableError` を投げ、読書の記録を残さない
///   (購入していない・購入済みのどちらかに写さない。owner の決定 https://github.com/bannzai/doquiz/pull/84#issuecomment-7071830203 )
/// - 取り込みを始められなかった時は、`screenCapture.start()` の error をそのまま投げ、読書の記録を残さない
/// - 読書の記録の保存に失敗した時は、足した読書の記録を取り除き、取り込みを止めてから `save` の error を投げる
/// - 読書の記録を保存できて、その読書を無料の回数に数える時だけ、`countFreeReadingStart` を 1 回呼ぶ。回数を保存できなかった時は、
///   読書の記録を取り除いて保存し直し、取り込みを止めてから `countFreeReadingStart` の error を投げる (数えずに無料の読書を始めさせないため)
///
/// 保存先への書き込みは `save` で行う (アプリは `modelContext.save` を渡す。保存の失敗をテストで起こせるよう引数にしている)。
/// 冪等ではない: 読書 1 回ごとに読書の記録を 1 件作るため、呼ぶたびに取り込みを始め直して読書の記録が 1 件増え、無料の回数に数える時は回数も 1 増える。
/// - Parameters:
///   - loadFreeReadingStartCount: これまでに無料で始めた読書の回数を読み出す操作。購入していない時だけ呼ぶ (`countsAsFreeReadingStart`)
///   - countFreeReadingStart: 無料で始めた読書の回数を 1 増やして保存する操作。保存できない時は error を投げる
///   - retryDelays: 購入の状態の取得をやり直す前に待つ時間 (`fetchPurchaseStateRetrying` に渡す)
///   - sleep: 待つ操作 (アプリは `Task.sleep(for:)`。テストで待たずに済むよう引数にしている)
///   - currentDateTime: 今の日時を返す。取り込みが始まった時に 1 回呼び、読書を始めた日時にする
/// - Returns: 作った読書の記録と、取り込んだ画面の画像が順に届く流れ
func startReading(
    book: Book,
    purchaseService: any PurchaseService,
    loadFreeReadingStartCount: () throws -> Int,
    countFreeReadingStart: () throws -> Void,
    retryDelays: [Duration] = purchaseStateRetryDelays,
    sleep: (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
    screenCapture: any ScreenCapture,
    modelContext: ModelContext,
    currentDateTime: () -> Date,
    save: () throws -> Void
) async throws -> (readingSession: ReadingSession, capturedImages: AsyncThrowingStream<CGImage, any Error>) {
    // 判定は取り込みを始める前に行う (使い切った時と取得できない時に、取り込みを始めずに投げるため)。結果を使うのは読書の記録を保存できた後なので、変数に持つ。
    let countsAsFreeReading = try countsAsFreeReadingStart(
        purchaseState: try await fetchPurchaseStateRetrying(purchaseService: purchaseService, retryDelays: retryDelays, sleep: sleep),
        loadFreeReadingStartCount: loadFreeReadingStartCount
    )
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
    if countsAsFreeReading {
        do {
            try countFreeReadingStart()
        } catch {
            modelContext.delete(readingSession)
            // 取り除いた読書の記録の保存に失敗しても、回数を保存できなかった error を投げる (利用者に知らせる理由は回数の方のため)。
            try? save()
            await screenCapture.stop()
            throw error
        }
    }
    return (readingSession, capturedImages)
}

/// 取り込んだ画像が届くたびに本文を抽出し、読書の記録にページを足して保存する。画像の流れが終わるまで続ける。
///
/// - 抽出した本文は前後の空白と改行を除く。除いて空の時と、直前に足したページと同じ時は、ページを足さない
/// - 本文の抽出に失敗した画像は、ページを足さずに次の画像へ進む (1 枚の失敗で読書を止めないため)
/// - 画像は本文の抽出に渡すだけで、ファイルにも保存データにも書かない
/// - 流れが error で終わった時 (取り込みが途中で止まった時) と、ページの保存に失敗した時は、その error を投げる。それまでに保存できたページは残り、保存できなかったページは残さない
/// - 呼び出したタスクが取り消された時は `CancellationError` を投げる
///
/// 冪等ではない: 届いた画像ごとにページを足すため、同じ画像の流れは 1 回だけ渡す。
/// - Parameters:
///   - currentDateTime: 今の日時を返す。ページを足すたびに呼び、取り込んだ日時にする
///   - pauseAfterEachImage: 画像を 1 枚処理した後、次の画像を受け取るまで待つ時間 (同じページを繰り返し処理しないための間引き)
///   - save: 保存先への書き込み。ページを足すたびに呼ぶ (アプリは `modelContext.save` を渡す。保存の失敗をテストで起こせるよう引数にしている)
func saveCapturedPages(
    capturedImages: AsyncThrowingStream<CGImage, any Error>,
    readingSession: ReadingSession,
    pageTextExtractor: any PageTextExtractor,
    modelContext: ModelContext,
    currentDateTime: () -> Date,
    pauseAfterEachImage: Duration,
    save: () throws -> Void
) async throws {
    var lastPageText: String?
    for try await capturedImage in capturedImages {
        if let pageText = try await extractedPageText(image: capturedImage, pageTextExtractor: pageTextExtractor), !pageText.isEmpty, pageText != lastPageText {
            let capturedPage = CapturedPage(id: UUID(), capturedDateTime: currentDateTime(), text: pageText, readingSession: readingSession)
            modelContext.insert(capturedPage)
            do {
                try save()
            } catch {
                // 保存できなかったページを context に残すと、後の保存 (読書を終える・次の読書を始める) に混ざるため、取り除いてから投げる。
                modelContext.delete(capturedPage)
                throw error
            }
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
/// 保存に失敗した時は、`save` の error を投げる。入れた終えた日時は読書の記録に残す
/// (取り込みは止まっていて読書は終わっており、同じ保存先への次の保存で一緒に書かれるようにするため)。
/// - Parameters:
///   - pageSaving: この読書の `saveCapturedPages` を動かしているタスク
///   - currentDateTime: 今の日時を返す。終えた日時を入れる時に 1 回呼ぶ
///   - save: 保存先への書き込み (アプリは `modelContext.save` を渡す。保存の失敗をテストで起こせるよう引数にしている)
/// - Returns: ページを足す処理が error で終わっていた時 (取り込みが途中で止まった時・ページを保存できなかった時) の error。
///   最後まで動いた時と、タスクの取り消しで終わった時は nil
func endReading(
    readingSession: ReadingSession,
    screenCapture: any ScreenCapture,
    pageSaving: Task<Void, any Error>,
    currentDateTime: () -> Date,
    save: () throws -> Void
) async throws -> (any Error)? {
    await screenCapture.stop()
    // 終えた日時を入れるより先に、ページを足す処理の終わりを待つ (終えた日時より後にページが足されないようにするため)。
    let pageSavingResult = await pageSaving.result
    if readingSession.endedDateTime == nil {
        readingSession.endedDateTime = currentDateTime()
        try save()
    }
    if case .failure(let error) = pageSavingResult, !(error is CancellationError) {
        return error
    }
    return nil
}

/// 読書を終えた時に、本の画面に出す案内の文を返す。案内することが無ければ nil。
///
/// - Parameter pageSavingError: `endReading` が返した、ページを足す処理の error。最後まで動いた時は nil
func readingEndGuide(pageSavingError: (any Error)?) -> String? {
    guard pageSavingError != nil else {
        return nil
    }
    return "取り込みが途中で止まったため 読書を終えました\n止まるまでに読んだページの本文は残っています"
}

/// 読書を終える時に、読書の記録を保存できなかった場合に本の画面に出す案内の文を返す。
func readingEndSaveFailureGuide(error: any Error) -> String {
    "読書の記録を保存できませんでした\n\(error)"
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
    case is FreeReadingsUsedUpError:
        "無料で始められる読書を使い切りました\n続けて読むには購入のプランを選んでください"
    case is PurchaseStateUnavailableError:
        "購入の状態を確かめられませんでした\n通信できる所でもう一度「読書を始める」を押してください"
    case is FreeReadingStartCountUnavailableError, is FreeReadingStartCountKeychainError:
        "無料で始めた読書の回数を読み書きできませんでした\nもう一度「読書を始める」を押してください"
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
