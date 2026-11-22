import Foundation
import RevenueCat
import Testing

@testable import Doquiz

/// 購入の状態の取得をやり直す処理を、決まった回数だけ失敗する偽の購入の境界で確かめる。待つ操作は呼ばれた時間を記録するだけで、実際には待たない。
struct PurchaseStateFetchTests {
    /// 初めの `failureCount` 回は `failure` を投げ、その後は `purchaseState` を返す、偽の購入の境界。購入の状態の取得だけを使う。
    private final class FailingPurchaseService: PurchaseService {
        /// 取得に失敗する残りの回数。
        private var failureCount: Int
        /// 失敗する時に投げる error。
        private let failure: any Error
        /// 失敗し終えた後に返す購入の状態。
        private let purchaseState: PurchaseState
        /// `state()` が呼ばれた回数。
        private(set) var stateCallCount = 0

        /// 失敗する回数 `failureCount`・投げる error `failure`・その後に返す状態 `purchaseState` を決めて作る。
        init(failureCount: Int, failure: any Error, purchaseState: PurchaseState) {
            self.failureCount = failureCount
            self.failure = failure
            self.purchaseState = purchaseState
        }

        /// 使わない。呼ばれた時は error を投げる。
        func packages() async throws -> [Package] { throw UnusedOperationError() }
        /// 使わない。空を返す。
        func introEligibilityStatuses(packages: [Package]) async -> [Package: IntroEligibilityStatus] { [:] }
        /// 使わない。呼ばれた時は error を投げる。
        func purchase(package: Package) async throws -> PurchaseState { throw UnusedOperationError() }
        /// 使わない。呼ばれた時は error を投げる。
        func restore() async throws -> PurchaseState { throw UnusedOperationError() }

        /// 残りの失敗の回数があれば 1 減らして `failure` を投げ、無ければ `purchaseState` を返す。
        func state() async throws -> PurchaseState {
            stateCallCount += 1
            guard failureCount == 0 else {
                failureCount -= 1
                throw failure
            }
            return purchaseState
        }

        /// 使わない。何も流さずに終わる stream を返す。
        func stateUpdates() -> AsyncStream<PurchaseState> { AsyncStream { $0.finish() } }
    }

    /// 偽の購入の境界で使わない操作が呼ばれたことを表す error。
    private struct UnusedOperationError: Error {}
    /// 偽の取得の失敗 (通信できない時の代わり)。
    private struct NetworkFailure: Error {}

    /// 待つ操作が呼ばれた時間を順に記録する。
    private final class SleepRecorder {
        /// 呼ばれた時間。
        private(set) var durations: [Duration] = []

        /// 呼ばれた時間を記録する。待たない。
        func sleep(duration: Duration) async throws {
            durations.append(duration)
        }
    }

    /// 1 回目で取得できた時は、待たずにその状態を返す。
    @Test func 取得できた時は待たずに返す() async throws {
        let purchaseService = FailingPurchaseService(failureCount: 0, failure: NetworkFailure(), purchaseState: .purchased)
        let sleepRecorder = SleepRecorder()

        #expect(try await fetchPurchaseStateRetrying(purchaseService: purchaseService, sleep: sleepRecorder.sleep) == .purchased)
        #expect(purchaseService.stateCallCount == 1)
        #expect(sleepRecorder.durations.isEmpty)
    }

    /// 2 回失敗した後の 3 回目で取得できた時は、1 秒と 3 秒を待ってやり直し、3 回目の状態を返す。
    @Test func 失敗した後に取得できた時はやり直して返す() async throws {
        let purchaseService = FailingPurchaseService(failureCount: 2, failure: NetworkFailure(), purchaseState: .inTrial)
        let sleepRecorder = SleepRecorder()

        #expect(try await fetchPurchaseStateRetrying(purchaseService: purchaseService, sleep: sleepRecorder.sleep) == .inTrial)
        #expect(purchaseService.stateCallCount == 3)
        #expect(sleepRecorder.durations == [.seconds(1), .seconds(3)])
    }

    /// 3 回とも失敗した時は、購入していない・購入済みのどちらの値も返さず、`PurchaseStateUnavailableError` を投げる。
    @Test func やり直しても取得できない時は取得できなかったことを投げる() async throws {
        let purchaseService = FailingPurchaseService(failureCount: 3, failure: NetworkFailure(), purchaseState: .notPurchased)
        let sleepRecorder = SleepRecorder()

        await #expect(throws: PurchaseStateUnavailableError.self) {
            _ = try await fetchPurchaseStateRetrying(purchaseService: purchaseService, sleep: sleepRecorder.sleep)
        }
        #expect(purchaseService.stateCallCount == 3)
        #expect(sleepRecorder.durations == [.seconds(1), .seconds(3)])
    }

    /// RevenueCat の SDK を初期化していない時は、やり直さずに `PurchaseStateUnavailableError` を投げる。
    @Test func 購入のSDKを初期化していない時はやり直さずに投げる() async throws {
        let purchaseService = FailingPurchaseService(failureCount: 3, failure: RevenueCatNotConfiguredError(), purchaseState: .notPurchased)
        let sleepRecorder = SleepRecorder()

        await #expect(throws: PurchaseStateUnavailableError.self) {
            _ = try await fetchPurchaseStateRetrying(purchaseService: purchaseService, sleep: sleepRecorder.sleep)
        }
        #expect(purchaseService.stateCallCount == 1)
        #expect(sleepRecorder.durations.isEmpty)
    }
}
