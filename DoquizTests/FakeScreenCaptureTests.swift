import CoreGraphics
import Testing
@testable import Doquiz

/// 偽の取り込み (`FakeScreenCapture`) が、取り込みの protocol の約束どおりに画像を流し、止まり、失敗を伝えることを確かめる。
struct FakeScreenCaptureTests {
    /// 偽の取り込みに起こさせる失敗。
    private struct CaptureFailure: Error {}

    /// 1×1 の画像を新しく作る。作るたびに別の画像になる。
    private func makeImage() throws -> CGImage {
        try #require(
            CGContext(
                data: nil,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        )
    }

    /// 流れに最初に届く画像を返す。画像が届かずに流れが終わった時は nil を返し、流れが error で終わった時はその error を投げる。
    private func firstImage(stream: AsyncThrowingStream<CGImage, any Error>) async throws -> CGImage? {
        for try await image in stream {
            return image
        }
        return nil
    }

    /// 始めると、渡しておいた画像が渡した順に、1 枚も欠けずに届く。
    @Test func 始めると渡しておいた画像が渡した順に届く() async throws {
        let images = [try makeImage(), try makeImage(), try makeImage()]
        let capture = FakeScreenCapture(images: images, startError: nil, interruptionError: nil)
        var iterator = try await capture.start().makeAsyncIterator()

        var receivedImages: [CGImage] = []
        for _ in images {
            receivedImages.append(try #require(try await iterator.next()))
        }

        #expect(receivedImages.elementsEqual(images, by: ===))
        capture.stop()
    }

    /// 渡す画像が 1 枚も無い時は、画像が届かないまま、止めると流れが error なしで終わる。
    @Test func 渡す画像が無い時は止めると何も届かずに流れが終わる() async throws {
        let capture = FakeScreenCapture(images: [], startError: nil, interruptionError: nil)
        var iterator = try await capture.start().makeAsyncIterator()

        capture.stop()

        #expect(try await iterator.next() == nil)
    }

    /// 渡し切る前に止めると、残りの画像は届かず、流れが error なしで終わる。
    @Test func 止めた後は画像が届かない() async throws {
        let capture = FakeScreenCapture(
            images: [try makeImage(), try makeImage(), try makeImage()],
            startError: nil,
            interruptionError: nil
        )
        var iterator = try await capture.start().makeAsyncIterator()
        _ = try #require(try await iterator.next())

        capture.stop()

        #expect(try await iterator.next() == nil)
    }

    /// 画像を渡し切った後、受け取り側が次の画像を待っている間に止めると、待っていた受け取り側の流れが error なしで終わる。
    @Test(.timeLimit(.minutes(1))) func 受け取り側が待っている間に止めると流れが終わる() async throws {
        let capture = FakeScreenCapture(images: [try makeImage()], startError: nil, interruptionError: nil)
        let stream = try await capture.start()
        let receivedImageCount = Task {
            var count = 0
            for try await _ in stream {
                count += 1
            }
            return count
        }
        while !capture.isWaitingForStop {
            await Task.yield()
        }

        capture.stop()

        #expect(try await receivedImageCount.value == 1)
    }

    /// 止めるのを 2 回続けて呼んでも、1 回の時と同じく流れが error なしで終わり、その後に始め直せる。
    @Test func 続けて2回止めても流れが終わり後から始め直せる() async throws {
        let images = [try makeImage(), try makeImage()]
        let capture = FakeScreenCapture(images: images, startError: nil, interruptionError: nil)
        var iterator = try await capture.start().makeAsyncIterator()
        _ = try #require(try await iterator.next())

        capture.stop()
        capture.stop()

        #expect(try await iterator.next() == nil)
        #expect(try #require(try await firstImage(stream: capture.start())) === images[0])
        capture.stop()
    }

    /// 止めずにもう一度始めると、前の流れは残りの画像を渡さずに error なしで終わり、新しい流れに最初の画像から順に届く。
    @Test func 取り込み中に始め直すと前の流れが終わり新しい流れに最初から届く() async throws {
        let images = [try makeImage(), try makeImage(), try makeImage()]
        let capture = FakeScreenCapture(images: images, startError: nil, interruptionError: nil)
        var previousIterator = try await capture.start().makeAsyncIterator()
        _ = try #require(try await previousIterator.next())

        var iterator = try await capture.start().makeAsyncIterator()

        #expect(try await previousIterator.next() == nil)
        var receivedImages: [CGImage] = []
        for _ in images {
            receivedImages.append(try #require(try await iterator.next()))
        }
        #expect(receivedImages.elementsEqual(images, by: ===))
        capture.stop()
    }

    /// 始める前に止めても何も起きず、その後に始めると画像が届く。
    @Test func 始める前に止めても後から始められる() async throws {
        let images = [try makeImage()]
        let capture = FakeScreenCapture(images: images, startError: nil, interruptionError: nil)

        capture.stop()

        #expect(try #require(try await firstImage(stream: capture.start())) === images[0])
        capture.stop()
    }

    /// 始められなかった時は、`start()` が渡しておいた error を投げる。
    @Test func 始められなかった時は呼び出し側がerrorを受け取る() async throws {
        await #expect(throws: CaptureFailure.self) {
            _ = try await FakeScreenCapture(images: [try makeImage()], startError: CaptureFailure(), interruptionError: nil).start()
        }
    }

    /// 途中で止まった時は、それまでの画像が届いた後に、流れが渡しておいた error を投げる。
    @Test func 途中で止まった時は画像が届いた後に呼び出し側がerrorを受け取る() async throws {
        let images = [try makeImage(), try makeImage()]
        var iterator = try await FakeScreenCapture(images: images, startError: nil, interruptionError: CaptureFailure())
            .start()
            .makeAsyncIterator()

        var receivedImages: [CGImage] = []
        for _ in images {
            receivedImages.append(try #require(try await iterator.next()))
        }
        #expect(receivedImages.elementsEqual(images, by: ===))

        do {
            _ = try await iterator.next()
            Issue.record("画像を渡し切った後に error が投げられなかった")
        } catch {
            #expect(error is CaptureFailure)
        }
    }

    /// 止めた後に始め直すと、渡しておいた画像が最初からもう一度届く。
    @Test func 止めた後に始め直すと最初の画像から届く() async throws {
        let images = [try makeImage(), try makeImage()]
        let capture = FakeScreenCapture(images: images, startError: nil, interruptionError: nil)
        _ = try #require(try await firstImage(stream: capture.start()))
        capture.stop()

        #expect(try #require(try await firstImage(stream: capture.start())) === images[0])
        capture.stop()
    }
}
