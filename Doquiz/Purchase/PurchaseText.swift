import RevenueCat

// 購入の画面に出す文を、取得した商品 (`Package`) から作る。値段・更新の間隔・トライアルの長さは取得した値だけから作り、固定の値を書かない。

/// 期間の長さの文 (例: 「1 週間」「1 か月」「1 年」) を返す。`value` は単位 `unit` の個数。
func purchasePeriodLengthText(value: Int, unit: SubscriptionPeriod.Unit) -> String {
    switch unit {
    case .day:
        "\(value) 日間"
    case .week:
        "\(value) 週間"
    case .month:
        "\(value) か月"
    case .year:
        "\(value) 年"
    }
}

/// 商品 `package` の名前 (月額・年額・買い切り) を返す。3 つのどれでもない商品は、ストアの商品の名前を返す。
func purchasePlanName(package: Package) -> String {
    switch package.packageType {
    case .monthly:
        "月額"
    case .annual:
        "年額"
    case .lifetime:
        "買い切り"
    default:
        package.storeProduct.localizedTitle
    }
}

/// 商品 `package` を買う利用者に付く、トライアルの長さの文 (例: 「1 週間」) を返す。
///
/// 長さを返すのは、商品に無料のトライアルがあり、利用者がトライアルを使えると確かめられた時 (`introEligibilityStatus` が `.eligible`) だけ。
/// トライアルが無い商品・使えない利用者・確かめられなかった時 (nil か `.unknown`) は nil を返す
/// (使えるか分からない利用者に「無料」と出さないため。購入の確認の表示は App Store が正しい内容を出す
/// https://www.revenuecat.com/docs/subscription-guidance/subscription-offers )。
func purchaseTrialLengthText(package: Package, introEligibilityStatus: IntroEligibilityStatus?) -> String? {
    guard package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial else {
        return nil
    }
    return package.storeProduct.introductoryDiscount.map {
        purchasePeriodLengthText(value: $0.subscriptionPeriod.value * $0.numberOfPeriods, unit: $0.subscriptionPeriod.unit)
    }
}

/// 商品の行の、名前の下に出す説明を返す。
///
/// 更新のある商品は、トライアルの長さ (`purchaseTrialLengthText` が返す時だけ) と更新の間隔を返す。更新の無い商品は、1 回の支払いであることを返す。
func purchasePlanDescription(package: Package, introEligibilityStatus: IntroEligibilityStatus?) -> String {
    guard let subscriptionPeriod = package.storeProduct.subscriptionPeriod else {
        return "1 回の支払いでずっと使えます"
    }
    let renewalText = "\(purchasePeriodLengthText(value: subscriptionPeriod.value, unit: subscriptionPeriod.unit))ごとに更新"
    guard let trialLengthText = purchaseTrialLengthText(package: package, introEligibilityStatus: introEligibilityStatus) else {
        return renewalText
    }
    return "\(trialLengthText)無料 その後 \(renewalText)"
}

/// 購入のボタンの文を返す。トライアルの長さを出せる時 (`purchaseTrialLengthText` が返す時) は、無料で始めることを書く。
func purchaseButtonTitle(package: Package, introEligibilityStatus: IntroEligibilityStatus?) -> String {
    guard let trialLengthText = purchaseTrialLengthText(package: package, introEligibilityStatus: introEligibilityStatus) else {
        return "購入する"
    }
    return "\(trialLengthText)無料で始める"
}

/// 購入のボタンの下に出す、自動で更新されることの説明を返す。更新の無い商品は nil を返す。
func purchaseRenewalNote(package: Package, introEligibilityStatus: IntroEligibilityStatus?) -> String? {
    guard package.storeProduct.subscriptionPeriod != nil else {
        return nil
    }
    let planPriceText = "\(purchasePlanName(package: package)) ¥5,000 で自動で更新されます"
    guard purchaseTrialLengthText(package: package, introEligibilityStatus: introEligibilityStatus) != nil else {
        return planPriceText
    }
    return "無料の期間が終わると\(planPriceText)"
}
