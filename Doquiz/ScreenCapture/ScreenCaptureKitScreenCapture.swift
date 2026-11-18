// iOS Simulator の SDK には ScreenCaptureKit が無いため、実機向けのビルドだけに入れる
// (Apple のサンプルの README: "ScreenCaptureKit on iOS requires a physical device running iOS 27 or later; it is not available in Simulator."
//  https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios )。
#if canImport(ScreenCaptureKit)
import CoreMedia
// ScreenCaptureKit の型 (SCContentFilter 等) は Sendable の宣言を持たないため、Apple のサンプルと同じく @preconcurrency で読み込む。
@preconcurrency import ScreenCaptureKit
import VideoToolbox

/// ScreenCaptureKit で画面全体を取り込む `ScreenCapture` の実物。
///
/// iOS の画面共有の選択画面 (`SCContentSharingPicker`) で利用者が選んだ内容を `SCStream` で受け取る。
/// アプリが背面にある間も続けるには、Info.plist の `UIBackgroundModes` に `screen-capture` が要る (`Doquiz-Info.plist`)。
final class ScreenCaptureKitScreenCapture: ScreenCapture {
    /// 取り込み中の stream。取り込んでいない間は nil。
    private var stream: SCStream?
    /// 取り込み中の stream のフレームと停止を受ける相手。stream が持ち続けるとは限らないため、ここで持つ。
    private var streamReceiver: ScreenCaptureKitStreamReceiver?
    /// 選択画面の結果を待っている `start()` の再開先。待っていない間は nil。
    private var contentFilterContinuation: CheckedContinuation<SCContentFilter, any Error>?
    /// フレームを画像に変える処理を main の外で動かすための queue。
    private let sampleHandlerQueue = DispatchQueue(label: "app.bannzai.doquiz.screen-capture")

    /// 取り込みを終わらせた回数 (`stop()` と、始め直す `start()` が増やす)。
    /// 途中で待った `start()` と、遅れて届いた選択画面の結果が、今の取り込みのものかを確かめるのに使う。
    private var endCount = 0

    /// 画面共有の選択画面を出し、利用者が選んだ内容の取り込みを始めて、画面の画像の流れを返す。
    /// 取り込みを使えない端末・選択画面を閉じた時・stream を始められなかった時は error を投げ、取り込みを止めた状態に戻す。
    /// 待っている間に `stop()` か次の `start()` が呼ばれた時は、`selectionCancelled` を投げ、後から呼ばれた側の状態に触れずに終わる。
    func start() async throws -> AsyncThrowingStream<CGImage, any Error> {
        let ended = endCurrentCapture()
        // 止める時の失敗は、呼び出し側が取れる対処が無いため伝えない (Apple のサンプルの tearDownStream と同じ扱い)。
        try? await ended.stream?.stopCapture()
        do {
            // 前の取り込みを止めるのを待っている間に止められた・始め直された時は、選択画面を出さない。
            guard ended.endCount == endCount else { throw ScreenCaptureStartError.selectionCancelled }
            let images = AsyncThrowingStream.makeStream(
                of: CGImage.self,
                throwing: (any Error).self,
                bufferingPolicy: .bufferingNewest(1)
            )
            let streamReceiver = ScreenCaptureKitStreamReceiver(continuation: images.continuation)
            let stream = SCStream(
                filter: try await selectedContentFilter(endCount: ended.endCount),
                configuration: SCStreamConfiguration(),
                delegate: streamReceiver
            )
            // 選んだ内容が届いてからここへ戻るまでの間に止められた時は、取り込みを始めない。
            guard ended.endCount == endCount else { throw ScreenCaptureStartError.selectionCancelled }
            try stream.addStreamOutput(streamReceiver, type: .screen, sampleHandlerQueue: sampleHandlerQueue)
            self.stream = stream
            self.streamReceiver = streamReceiver
            try await stream.startCapture()
            // 始まるのを待っている間に止められた時は、止めた側の停止が開始より先に届いて効かなかった場合に備えて、ここでも止める。
            guard ended.endCount == endCount else {
                try? await stream.stopCapture()
                throw ScreenCaptureStartError.selectionCancelled
            }
            return images.stream
        } catch {
            // 待っている間に止められた・始め直された時は、今の状態は後から呼ばれた側のものなので片付けず、止められたことだけを伝える。
            guard ended.endCount == endCount else { throw ScreenCaptureStartError.selectionCancelled }
            await stop()
            throw error
        }
    }

    /// 選択画面を待っている `start()` を `selectionCancelled` で終わらせ、stream を止めて、画像の流れを error なしで終わらせる。
    /// 何度呼んでも同じ結果になる。
    func stop() async {
        // 止める時の失敗は、呼び出し側が取れる対処が無いため伝えない (Apple のサンプルの tearDownStream と同じ扱い)。
        try? await endCurrentCapture().stream?.stopCapture()
    }

    /// 今の取り込みを、待たずに終わらせる。選択画面を待っている `start()` を `selectionCancelled` で再開し、画像の流れを error なしで終わらせる。
    /// 待ちを挟まないため、呼び出しの間に別の `start()`・`stop()` が割り込まない。
    /// - Returns: 増やした後の `endCount` と、手放した stream (取り込んでいなかった時は nil)。stream を止めるのは呼び出し側が行う
    private func endCurrentCapture() -> (endCount: Int, stream: SCStream?) {
        defer { stream = nil }
        endCount += 1
        contentFilterContinuation?.resume(throwing: ScreenCaptureStartError.selectionCancelled)
        contentFilterContinuation = nil
        SCContentSharingPicker.shared.isActive = false
        streamReceiver?.continuation.finish()
        streamReceiver = nil
        return (endCount, stream)
    }

    /// 画面共有の選択画面を出し、利用者が選んだ内容を返す。
    /// 取り込みを使えない端末・選択画面を閉じた時・選択画面を出せなかった時は error を投げる。
    /// - Parameter endCount: 呼び出した `start()` が始まった時の `endCount`。これと違う回に届いた選択画面の結果は捨てる
    private func selectedContentFilter(endCount: Int) async throws -> SCContentFilter {
        let picker = SCContentSharingPicker.shared
        guard picker.isAvailable else { throw ScreenCaptureStartError.unavailable }
        let pickerObserver = ScreenCaptureKitPickerObserver { [weak self] result in
            // 前の回の選択画面の結果が、始め直した後に遅れて届いた時は、今の回の選択として使わない。
            guard let self, endCount == self.endCount else { return }
            contentFilterContinuation?.resume(with: result)
            contentFilterContinuation = nil
        }
        picker.add(pickerObserver)
        defer { picker.remove(pickerObserver) }
        picker.isActive = true
        return try await withCheckedThrowingContinuation { continuation in
            contentFilterContinuation = continuation
            picker.present()
        }
    }
}

/// 画面共有の選択画面の結果を、main actor の上の受け取り先へ渡す。
///
/// ScreenCaptureKit が observer を main 以外から呼ぶため、main actor に属さない別の型にしている
/// (Apple のサンプルの `PickerDelegate` のコメント: "ScreenCaptureKit calls these delegate methods from background queues, not the main actor")。
nonisolated final class ScreenCaptureKitPickerObserver: NSObject, SCContentSharingPickerObserver, Sendable {
    /// 選択画面の結果 (選んだ内容か、始められなかった理由) の受け取り先。
    private let onSelectionResult: @MainActor @Sendable (sending Result<SCContentFilter, any Error>) -> Void

    /// - Parameter onSelectionResult: 選択画面の結果ごとに main actor の上で呼ばれる受け取り先
    init(onSelectionResult: @escaping @MainActor @Sendable (sending Result<SCContentFilter, any Error>) -> Void) {
        self.onSelectionResult = onSelectionResult
    }

    /// 利用者が選んだ内容を、受け取り先に成功として渡す。
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in onSelectionResult(.success(filter)) }
    }

    /// 利用者が何も選ばずに閉じたことを、受け取り先に `selectionCancelled` として渡す。
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in onSelectionResult(.failure(ScreenCaptureStartError.selectionCancelled)) }
    }

    /// 選択画面を出せなかった理由を、受け取り先に失敗として渡す。
    func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in onSelectionResult(.failure(error)) }
    }
}

/// `SCStream` が渡す画面のフレームと停止を、取り込んだ画像の流れに渡す。
///
/// フレームは受け取った queue の上で `CGImage` に変えてから流し、`CMSampleBuffer` を queue の外に出さない。
nonisolated final class ScreenCaptureKitStreamReceiver: NSObject, SCStreamOutput, SCStreamDelegate, Sendable {
    /// 取り込んだ画像の流れの送り口。
    let continuation: AsyncThrowingStream<CGImage, any Error>.Continuation

    /// - Parameter continuation: 取り込んだ画像の流れの送り口
    init(continuation: AsyncThrowingStream<CGImage, any Error>.Continuation) {
        self.continuation = continuation
    }

    /// 画面のフレームを `CGImage` に変えて流れに送る。画面以外の出力と、画像を持たないフレームは送らない。
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let imageBuffer = sampleBuffer.imageBuffer else { return }
        var image: CGImage?
        VTCreateCGImageFromCVPixelBuffer(imageBuffer, options: nil, imageOut: &image)
        if let image {
            continuation.yield(image)
        }
    }

    /// stream が途中で止まった理由を、流れの終わりの error として送る。
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        continuation.finish(throwing: error)
    }
}
#endif
