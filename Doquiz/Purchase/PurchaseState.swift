import RevenueCat

/// 利用者の購入の状態。保存せず、`PurchaseService` から取るたびに求める。
enum PurchaseState: Equatable {
    /// 購入していない。トライアルも始めていないか、トライアルや購入の期間が終わっている。
    case notPurchased
    /// トライアル中。月額か年額の、無料の期間の中にいる。
    case inTrial
    /// 購入済み。月額か年額の支払った期間の中にいるか、買い切りを購入している。
    case purchased
}

/// RevenueCat の entitlement `premium` の情報から、購入の状態を返す。
///
/// `premiumEntitlementInfo` が nil の時 (利用者が `premium` を 1 度も持ったことが無い) と、有効でない時は、購入していないを返す。
func purchaseState(premiumEntitlementInfo: EntitlementInfo?) -> PurchaseState {
    guard let premiumEntitlementInfo, premiumEntitlementInfo.isActive else {
        return .notPurchased
    }
    return premiumEntitlementInfo.periodType == .trial ? .inTrial : .purchased
}
