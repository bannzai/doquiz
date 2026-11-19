#if DEBUG
    import CoreGraphics

    /// 開発者メニューの「読書で偽の取り込みを使う」の切り替えを保存する、UserDefaults のキー。
    let developerMenuUsesFakeReadingKey = "developerMenuUsesFakeReading"

    /// 開発者メニューで偽の取り込みに切り替えた読書で、どの画像からも抽出されたことにする本文。
    let developerMenuFakeReadingPageText = "灯台守は毎朝 霧の濃さを日誌に書きとめた"

    /// 開発者メニューで偽の取り込みに切り替えた読書で使う、画像を 2 枚流す偽の取り込みを作る。
    ///
    /// 画面の取り込みは iOS Simulator で動かないため、読書を始めてから終えるまでの流れを Simulator と UI テストで確かめるのに使う
    /// (`documents/adr/0001-verify-on-external-machines.md`)。画像の中身は読まれない (本文は `developerMenuFakeReadingPageText` に決まっている) ため、1×1 の画像にしている。
    func makeDeveloperMenuFakeScreenCapture() -> FakeScreenCapture {
        FakeScreenCapture(
            images: (0..<2).compactMap { _ in
                CGContext(
                    data: nil,
                    width: 1,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )?.makeImage()
            },
            startError: nil,
            interruptionError: nil
        )
    }
#endif
