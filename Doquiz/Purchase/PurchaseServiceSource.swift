import SwiftUI

/// 画面が使う購入の境界 (`PurchaseService`) の作り方。購入の境界を使う画面は、これを 1 つ持って `makePurchaseService()` で作る。
///
/// 開発者メニューの偽の購入の切り替えを読むため、SwiftUI の `DynamicProperty` にしている (画面に置くと、切り替えが変わった時に画面が描き直される)。
/// 作り方を画面ごとに書かず 1 か所に置くため。
struct PurchaseServiceSource: DynamicProperty {
    #if DEBUG
        /// 開発者メニューで、購入を偽の購入に切り替えている時の動き。値が無い時は実物で購入する。
        @AppStorage(developerMenuFakePurchaseBehaviorKey) var fakePurchaseBehavior: DeveloperMenuFakePurchaseBehavior?
    #endif

    /// 購入の境界を作る。開発者メニューで偽の購入に切り替えている時は、選んだ動きをする偽の購入を返し、それ以外は実物 (RevenueCat) を返す。
    /// 呼ぶたびに新しい境界を作る。
    func makePurchaseService() -> any PurchaseService {
        #if DEBUG
            if let fakePurchaseBehavior {
                return makeDeveloperMenuFakePurchaseService(behavior: fakePurchaseBehavior)
            }
        #endif
        return RevenueCatPurchaseService()
    }

    /// 作る購入の境界の種類を表す値。開発者メニューで偽の購入の動きを変えた時に変わる。
    var kindID: String {
        #if DEBUG
            fakePurchaseBehavior?.rawValue ?? "real"
        #else
            "real"
        #endif
    }
}
