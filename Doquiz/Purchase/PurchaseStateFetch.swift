/// 購入の状態の取得をやり直す前に待つ時間。1 回目に失敗した後に 1 秒、2 回目に失敗した後に 3 秒待ってやり直し、合わせて 3 回取得を試す。
///
/// RevenueCat の SDK (5.103.2) は、購入の情報 (CustomerInfo) の取得を、端末が通信できない失敗では自分でやり直さない
/// (`HTTPClient` の間隔を置くやり直しは `isRetryable` の要求の 429 だけで、`GetCustomerInfoOperation` は `isRetryable` を付けない。
/// 予備のホストへの切り替えも `isDeviceConnectivityError` を外す。PR 本文に出典)。そのため、つながりかけの通信 (圏外から戻った直後等) を
/// アプリの側で拾い直す。1 回の取得は SDK が 15 秒 (10 分以内にタイムアウトしたホストには 5 秒) で打ち切るため、待つ時間は短くし、
/// 回数は利用者が「読書を始める」を押してから待てる長さに収まる 2 回のやり直しにした (タイムアウトが続いた時の最長はおよそ 15 + 1 + 5 + 3 + 5 秒)。
let purchaseStateRetryDelays: [Duration] = [.seconds(1), .seconds(3)]

/// 購入の状態を取得できなかったことを表す error。取得をやり直しても取得できなかった時に投げる。`underlyingError` は最後の取得の失敗。
struct PurchaseStateUnavailableError: Error {
    /// 最後に試した取得の失敗。
    let underlyingError: any Error
}

/// `purchaseService` から購入の状態を取得する。失敗した時は `retryDelays` の時間だけ順に待ってやり直し、取得できた時点の状態を返す。
///
/// - やり直しても取得できなかった時は `PurchaseStateUnavailableError` を投げる。購入していない・購入済みのどちらかの値に写さない
///   (owner の決定 https://github.com/bannzai/doquiz/pull/84#issuecomment-7071830203 )
/// - RevenueCat の SDK を初期化していない時 (`RevenueCatNotConfiguredError`) は、やり直しても結果が変わらないため、待たずに投げる
/// - 呼び出したタスクが取り消された時は、`sleep` が投げる `CancellationError` をそのまま投げる
/// - Parameter sleep: 待つ操作。アプリは `Task.sleep(for:)` を渡す (テストで待たずに済むよう引数にしている)
func fetchPurchaseStateRetrying(
    purchaseService: any PurchaseService,
    retryDelays: [Duration] = purchaseStateRetryDelays,
    sleep: (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
) async throws -> PurchaseState {
    var remainingDelays = retryDelays[...]
    while true {
        do {
            return try await purchaseService.state()
        } catch let error as RevenueCatNotConfiguredError {
            throw PurchaseStateUnavailableError(underlyingError: error)
        } catch {
            guard let delay = remainingDelays.popFirst() else {
                throw PurchaseStateUnavailableError(underlyingError: error)
            }
            try await sleep(delay)
        }
    }
}
