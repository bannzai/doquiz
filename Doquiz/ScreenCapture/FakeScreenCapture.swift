#if DEBUG
import CoreGraphics

/// あらかじめ渡した画像を順に流す、自動テスト用の `ScreenCapture` の偽物。
///
/// ほかのアプリの画面の取り込みは自動テストの環境で動かせないため、取り込みを使う処理はこの偽物で確かめる
/// (`documents/adr/0001-verify-on-external-machines.md`)。
/// 画像は、受け取り側が次を求めるたびに 1 枚ずつ渡す。渡し切った後は、`stop()` が呼ばれるまで流れを終わらせない。
final class FakeScreenCapture: ScreenCapture {
    /// 流す画像。この順に届く。
    private let images: [CGImage]
    /// nil でなければ、`start()` がこの error を投げる (始められなかった場合)。
    private let startError: (any Error)?
    /// nil でなければ、画像を渡し切った後に流れがこの error を投げて終わる (途中で止まった場合)。
    private let interruptionError: (any Error)?
    /// 次に渡す画像の `images` の中の位置。
    private var nextImageIndex = 0
    /// `stop()` が呼ばれた後かどうか。
    private var isStopped = false
    /// 画像を渡し切って `stop()` を待っている受け取り側の再開先。待っていない間は nil。
    private var stopContinuation: CheckedContinuation<Void, Never>?

    /// - Parameters:
    ///   - images: 流す画像。この順に届く
    ///   - startError: nil でなければ、`start()` がこの error を投げる
    ///   - interruptionError: nil でなければ、画像を渡し切った後に流れがこの error を投げて終わる
    init(images: [CGImage], startError: (any Error)?, interruptionError: (any Error)?) {
        self.images = images
        self.startError = startError
        self.interruptionError = interruptionError
    }

    /// `startError` があれば投げ、無ければ `images` を最初から順に渡す流れを返す。
    /// 前に返した流れは、止めた時と同じく error なしで終わる。
    func start() async throws -> AsyncThrowingStream<CGImage, any Error> {
        if let startError {
            throw startError
        }
        stop()
        nextImageIndex = 0
        isStopped = false
        return AsyncThrowingStream { [self] in
            try await nextImage()
        }
    }

    /// 残りの画像を渡さずに、`start()` が返した流れを error なしで終わらせる。何度呼んでも同じ結果になる。
    func stop() {
        isStopped = true
        stopContinuation?.resume()
        stopContinuation = nil
    }

    /// 流れの次の要素を返す。止めた後は nil (流れの終わり) を返す。
    /// 画像を渡し切った後は、`interruptionError` があれば投げ、無ければ `stop()` を待って nil を返す。
    private func nextImage() async throws -> CGImage? {
        if isStopped {
            return nil
        }
        if nextImageIndex < images.count {
            defer { nextImageIndex += 1 }
            return images[nextImageIndex]
        }
        if let interruptionError {
            throw interruptionError
        }
        await withCheckedContinuation { stopContinuation = $0 }
        return nil
    }
}
#endif
