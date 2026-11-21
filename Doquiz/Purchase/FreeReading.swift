/// 購入もトライアルもしていない利用者が、無料で始められる読書の回数。
///
/// 20 回は owner の決定 (`documents/DIRECTION.md`「決めたこと」の 2026-11-19 の行。原文「20回くらいは無料でいいよ」
/// https://github.com/bannzai/doquiz/issues/20#issuecomment-7001615361 )。
let freeReadingStartLimit = 20

/// 購入もトライアルもしていない状態で始めた読書の回数を保存する、UserDefaults のキー。
///
/// 読書の記録の件数から求めずに回数を保存するのは、トライアル中・購入済みの間に始めた読書を数えないため (どの状態で始めたかは読書の記録に残らない)
/// と、読書の記録や本を消しても回数が戻らないようにするため。購入の状態は保存せず、`PurchaseService` から取る。
let freeReadingStartCountKey = "freeReadingStartCount"

/// 無料で始められる読書を使い切っていて、トライアル中でも購入済みでもない利用者が、読書を始めようとしたことを表す error。
struct FreeReadingsUsedUpError: Error {}

/// 無料で始められる読書の、残りの回数を返す。`freeReadingStartCount` は、これまでに無料で始めた読書の回数。
///
/// 使い切った後は 0 を返す (開発者メニュー等で上限より多い回数が入っていても、負の数にしない)。
func remainingFreeReadingStartCount(freeReadingStartCount: Int) -> Int {
    max(0, freeReadingStartLimit - freeReadingStartCount)
}

/// 読書を始める時の購入の状態 `purchaseState` で、その読書を無料の回数に数えるかを返す。始められない時は `FreeReadingsUsedUpError` を投げる。
///
/// - トライアル中と購入済みの時は、無料の回数にかかわらず始められ、数えない (owner の決定。https://github.com/bannzai/doquiz/issues/49#issuecomment-7007196095 )
/// - 購入していない時は、残りの回数があれば始められて数え、残りが無ければ投げる
/// - 購入の状態を取得できなかった時 (`purchaseState` が nil) は、購入していない時と同じに扱う。購入済みとして通さないのは、
///   取得できない理由 (通信できない・RevenueCat の SDK を初期化していない) から購入しているかを決められないため。
///   RevenueCat の文書は、SDK が購入の情報を端末に持ち、購入した利用者は通信できなくても使えると書いている
///   ("Users who unlock entitlements will be able to access them even without an internet connection."
///   https://www.revenuecat.com/docs/customers/customer-info )。端末に持っている情報も無く通信できない時に error になるかは、同じ文書に書かれておらず未確認
/// - Parameter freeReadingStartCount: これまでに無料で始めた読書の回数
func countsAsFreeReadingStart(purchaseState: PurchaseState?, freeReadingStartCount: Int) throws -> Bool {
    switch purchaseState {
    case .inTrial, .purchased:
        return false
    case .notPurchased, nil:
        guard remainingFreeReadingStartCount(freeReadingStartCount: freeReadingStartCount) > 0 else {
            throw FreeReadingsUsedUpError()
        }
        return true
    }
}

/// 無料の回数を使い切って出した購入の画面を閉じた時の購入の状態 `purchaseState` で、読書をそのまま始めるかを返す。
///
/// トライアル中と購入済みの時だけ始める。購入していないまま閉じた時と、購入の状態を取得できなかった時 (nil) は始めない
/// (取得できない時に始めないのは、`countsAsFreeReadingStart` と同じく購入済みとして通さないため)。
func resumesReadingAfterPurchase(purchaseState: PurchaseState?) -> Bool {
    switch purchaseState {
    case .inTrial, .purchased:
        true
    case .notPurchased, nil:
        false
    }
}

/// ホーム (本を選ぶ画面) で、購入の画面への入口に添える、無料で始められる読書の残りの文を返す。
func freeReadingRemainingText(freeReadingStartCount: Int) -> String {
    let remainingCount = remainingFreeReadingStartCount(freeReadingStartCount: freeReadingStartCount)
    guard remainingCount > 0 else {
        return "無料で始められる読書を使い切りました"
    }
    return "無料で始められる読書 あと \(remainingCount) 回"
}
