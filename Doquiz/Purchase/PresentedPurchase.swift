import Foundation

/// 購入の画面を 1 回出すこと。`sheet(item:)` に渡して、購入の画面と、その画面が使う購入の境界を一緒に出す。
struct PresentedPurchase: Identifiable {
    /// 出すたびに変える識別子。同じ画面を出している間は変えない。
    let id: UUID
    /// この回の購入の画面が、出している間ずっと使う購入の境界。
    let purchaseService: any PurchaseService
}
