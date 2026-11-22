/// 購入もトライアルもしていない利用者が、無料で始められる読書の回数。
///
/// 20 回は owner の決定 (`documents/DIRECTION.md`「決めたこと」の 2026-11-19 の行。原文「20回くらいは無料でいいよ」
/// https://github.com/bannzai/doquiz/issues/20#issuecomment-7001615361 )。
let freeReadingStartLimit = 20

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
///
/// 購入の状態を取得できなかった時は、この関数を呼ばない。呼び出す側が、取得をやり直しても取得できなければ読書を始めずに知らせる
/// (購入していない・購入済みのどちらかに写さない。owner の決定 https://github.com/bannzai/doquiz/pull/84#issuecomment-7071830203 )。
/// - Parameter loadFreeReadingStartCount: これまでに無料で始めた読書の回数を読み出す操作。購入していない時だけ呼ぶ
///   (トライアル中と購入済みの利用者は回数を使わないため、回数を読み出せなくても読書を始められるようにする)。読み出せない時はその error を投げる
func countsAsFreeReadingStart(purchaseState: PurchaseState, loadFreeReadingStartCount: () throws -> Int) throws -> Bool {
    switch purchaseState {
    case .inTrial, .purchased:
        return false
    case .notPurchased:
        guard remainingFreeReadingStartCount(freeReadingStartCount: try loadFreeReadingStartCount()) > 0 else {
            throw FreeReadingsUsedUpError()
        }
        return true
    }
}

/// 無料の回数を使い切って出した購入の画面を閉じ、購入の状態を取り直し終えた時に、本の画面の案内を消すかを返す。
///
/// 取り直した購入の状態 `purchaseState` がトライアル中か購入済みで、今の案内 `readingGuide` がまだ使い切ったことの案内で、
/// 次の読書を始めている途中 (`isStartingReading`) でない時だけ消す。取り直している間に利用者が押した次の「読書を始める」が
/// 別の案内を出していたら、その案内を消さないため。
func clearsFreeReadingsUsedUpGuide(purchaseState: PurchaseState, readingGuide: String?, isStartingReading: Bool) -> Bool {
    switch purchaseState {
    case .inTrial, .purchased:
        readingGuide == readingStartFailureGuide(error: FreeReadingsUsedUpError()) && !isStartingReading
    case .notPurchased:
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
