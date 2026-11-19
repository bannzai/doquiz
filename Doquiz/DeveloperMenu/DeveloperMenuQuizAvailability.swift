#if DEBUG
    import FoundationModels

    /// 開発者メニューの「端末内のモデルが使えるか」の切り替えを保存する、UserDefaults のキー。
    let developerMenuQuizAvailabilityKey = "developerMenuQuizAvailability"

    /// 開発者メニューで選ぶ、端末内のモデルが使えるかの確かめ方。UserDefaults には rawValue を保存する。
    ///
    /// 端末内のモデルが使えない状態は、対応していない端末か設定を切った実機でしか作れないため、
    /// 偽の `FixedQuizEngine` が返す値を開発者メニューで選べるようにする。
    enum DeveloperMenuQuizAvailability: String, CaseIterable {
        /// 実物 (`FoundationModelsQuizEngine`) で確かめる。
        case real
        /// 偽物で、使えることにする。
        case available
        /// 偽物で、端末が Apple Intelligence に対応していないことにする。
        case deviceNotEligible
        /// 偽物で、Apple Intelligence が切られていることにする。
        case appleIntelligenceNotEnabled
        /// 偽物で、モデルの準備ができていないことにする。
        case modelNotReady
    }

    /// 開発者メニューのボタンに出す、`developerMenuQuizAvailability` の名前を返す。
    func developerMenuQuizAvailabilityTitle(developerMenuQuizAvailability: DeveloperMenuQuizAvailability) -> String {
        switch developerMenuQuizAvailability {
        case .real:
            "実物で確かめる"
        case .available:
            "使えることにする"
        case .deviceNotEligible:
            "使えないことにする (端末が対応していない)"
        case .appleIntelligenceNotEnabled:
            "使えないことにする (Apple Intelligence がオフ)"
        case .modelNotReady:
            "使えないことにする (モデルの準備中)"
        }
    }

    /// 開発者メニューで選んだ `developerMenuQuizAvailability` の時に、偽の `FixedQuizEngine` に返させる値を返す。
    ///
    /// 実物で確かめる時 (`.real`) は、偽物を使わないため nil を返す。
    func developerMenuFakeQuizAvailability(
        developerMenuQuizAvailability: DeveloperMenuQuizAvailability
    ) -> SystemLanguageModel.Availability? {
        switch developerMenuQuizAvailability {
        case .real:
            nil
        case .available:
            .available
        case .deviceNotEligible:
            .unavailable(.deviceNotEligible)
        case .appleIntelligenceNotEnabled:
            .unavailable(.appleIntelligenceNotEnabled)
        case .modelNotReady:
            .unavailable(.modelNotReady)
        }
    }
#endif
