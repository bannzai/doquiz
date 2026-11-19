import FoundationModels

/// 端末内のモデルが使えない時に、クイズを出せないことと理由を利用者に伝える案内の文を返す。使える時は nil を返す。
///
/// 本の一覧・本の画面のほか、読書の途中で使えなくなった時の画面も、同じ文を出すためにこの関数を使う。
/// 理由の種類は Foundation Models の `UnavailableReason` のとおりで、理由ごとに違う文を返す
/// ( https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason )。
/// 利用者が自分で直せる理由 (Apple Intelligence を切っている) には、直し方も書く。
/// 設定アプリの中の項目の名前は iOS の版で変わりうるため、案内には書かない。
func quizUnavailableGuide(availability: SystemLanguageModel.Availability) -> String? {
    switch availability {
    case .available:
        return nil
    case .unavailable(let unavailableReason):
        switch unavailableReason {
        case .deviceNotEligible:
            // Apple の文書の説明は「The device does not support Apple Intelligence.」。
            return "この iPhone ではクイズを出せません\nクイズを作る Apple Intelligence に この iPhone が対応していないためです"
        case .appleIntelligenceNotEnabled:
            // Apple の文書の説明は「Apple Intelligence is not enabled on the system.」。
            return "いまはクイズを作れません\nクイズを作る Apple Intelligence がオフになっています"
        case .modelNotReady:
            // Apple の文書の説明は「The models aren't available on the user's device.」と
            // 「Models are downloaded automatically based on factors like network status, battery level, and system load.」。
            return "この iPhone ではクイズを出せません\nクイズを作る Apple Intelligence に この iPhone が対応していないためです"
        @unknown default:
            // `UnavailableReason` は frozen でなく、iOS の更新で理由が増えうる。増えた理由にも、クイズを出せないことだけは伝える。
            return "いまはクイズを出せません\nクイズを作るモデルを この iPhone で使えない状態です"
        }
    }
}
