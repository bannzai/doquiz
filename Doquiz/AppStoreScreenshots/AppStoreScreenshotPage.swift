#if DEBUG
    /// App Store の製品ページに出すスクリーンショットの 1 枚。並びの順が、製品ページに出す順。
    ///
    /// 値の文字列は、起動の引数 `-appStoreScreenshotPage` の値と、書き出す画像のファイル名に使う。
    /// 撮るのは `DoquizUITests/AppStoreScreenshotTests.swift` で、画像にするのは `.github/workflows/appstore-screenshots.yml`。
    enum AppStoreScreenshotPage: String, CaseIterable {
        /// 読み終えた後のクイズの画面。
        case quiz
        /// 読書中の画面。
        case reading
        /// 出題の設定の画面 (問いの 4 種類)。
        case questionKinds = "question-kinds"
        /// 答えた後の、判定・模範の答え・根拠にした本文が出た画面。
        case evidence
        /// 本文の扱い (画像を残さない・端末の中で作る・アカウントが要らない)。
        case privacy
        /// 履歴の画面。
        case history
    }

    /// 起動の引数から、出す App Store のスクリーンショットを返す。引数が無い時と、値がどのスクリーンショットにも当たらない時は nil。
    ///
    /// 引数は `-appStoreScreenshotPage <値>` の形で、値は `AppStoreScreenshotPage` の文字列。
    /// 開発用のビルド (DEBUG) にだけあるため、公開用のビルドでは引数を渡してもスクリーンショットの画面は出ない。
    func appStoreScreenshotPage(launchArguments: [String]) -> AppStoreScreenshotPage? {
        guard let flagIndex = launchArguments.firstIndex(of: "-appStoreScreenshotPage"),
            launchArguments.indices.contains(flagIndex + 1)
        else {
            return nil
        }
        return AppStoreScreenshotPage(rawValue: launchArguments[flagIndex + 1])
    }
#endif
