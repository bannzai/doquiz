#if DEBUG
    import Foundation
    import RevenueCat

    /// 開発者メニューの「偽の購入」の切り替えを保存する、UserDefaults のキー。値が無い時は、実物 (RevenueCat の SDK) で購入する。
    let developerMenuFakePurchaseBehaviorKey = "developerMenuFakePurchaseBehavior"

    /// 開発者メニューで選ぶ、偽の購入の動き。定義の順を、開発者メニューで切り替える順に使う。
    ///
    /// `@AppStorage` が main actor の外からも値を読み書きできるよう、main actor に属さない型にしている。
    nonisolated enum DeveloperMenuFakePurchaseBehavior: String, CaseIterable {
        /// 月額・年額・買い切りの 3 つの商品を返す。利用者は購入しておらず、トライアルを使える。
        case returnsPackages
        /// 商品の取得に失敗する。
        case failsToGetPackages
        /// 利用者がトライアル中である。
        case inTrial
        /// 利用者が購入済みである。
        case purchased
        /// 3 つの商品を返すが、利用者が購入を取り消す (購入しても購入していないままになる)。
        case cancelsPurchase
        /// 3 つの商品を返すが、購入と復元に失敗する。
        case failsToPurchaseAndRestore
    }

    /// 偽の購入で、商品を購入した時に起きること。
    enum DeveloperMenuFakePurchaseResult {
        /// 購入できる。
        case succeeds
        /// 利用者が購入を取り消す。
        case isCancelled
        /// 購入に失敗する。
        case fails
    }

    /// 開発者メニューに出す、今の購入の動きの名前を返す。偽の購入に切り替えていない時 (nil) は実物の名前を返す。
    func developerMenuFakePurchaseBehaviorLabel(behavior: DeveloperMenuFakePurchaseBehavior?) -> String {
        switch behavior {
        case nil:
            "実物"
        case .returnsPackages:
            "商品を返す"
        case .failsToGetPackages:
            "商品を取得できない"
        case .inTrial:
            "トライアル中"
        case .purchased:
            "購入済み"
        case .cancelsPurchase:
            "購入を取り消す"
        case .failsToPurchaseAndRestore:
            "購入と復元に失敗する"
        }
    }

    /// 開発者メニューの切り替えを 1 回押した後の購入の動きを返す。実物 → `DeveloperMenuFakePurchaseBehavior` の定義の順 → 実物、と一巡する。
    func nextDeveloperMenuFakePurchaseBehavior(behavior: DeveloperMenuFakePurchaseBehavior?) -> DeveloperMenuFakePurchaseBehavior? {
        guard let behavior else {
            return DeveloperMenuFakePurchaseBehavior.allCases.first
        }
        return DeveloperMenuFakePurchaseBehavior.allCases.drop { $0 != behavior }.dropFirst().first
    }

    /// 開発者メニューで選んだ動き `behavior` をする、偽の購入を作る。
    func makeDeveloperMenuFakePurchaseService(behavior: DeveloperMenuFakePurchaseBehavior) -> DeveloperMenuFakePurchaseService {
        switch behavior {
        case .returnsPackages:
            DeveloperMenuFakePurchaseService(
                packages: makeDeveloperMenuFakePurchasePackages(),
                introEligibilityStatus: .eligible,
                purchaseState: .notPurchased,
                purchaseResult: .succeeds,
                restoredPurchaseState: .purchased
            )
        case .failsToGetPackages:
            DeveloperMenuFakePurchaseService(
                packages: nil,
                introEligibilityStatus: .unknown,
                purchaseState: .notPurchased,
                purchaseResult: .succeeds,
                restoredPurchaseState: .notPurchased
            )
        case .inTrial:
            DeveloperMenuFakePurchaseService(
                packages: makeDeveloperMenuFakePurchasePackages(),
                introEligibilityStatus: .ineligible,
                purchaseState: .inTrial,
                purchaseResult: .succeeds,
                restoredPurchaseState: .inTrial
            )
        case .purchased:
            DeveloperMenuFakePurchaseService(
                packages: makeDeveloperMenuFakePurchasePackages(),
                introEligibilityStatus: .ineligible,
                purchaseState: .purchased,
                purchaseResult: .succeeds,
                restoredPurchaseState: .purchased
            )
        case .cancelsPurchase:
            DeveloperMenuFakePurchaseService(
                packages: makeDeveloperMenuFakePurchasePackages(),
                introEligibilityStatus: .eligible,
                purchaseState: .notPurchased,
                purchaseResult: .isCancelled,
                restoredPurchaseState: .notPurchased
            )
        case .failsToPurchaseAndRestore:
            DeveloperMenuFakePurchaseService(
                packages: makeDeveloperMenuFakePurchasePackages(),
                introEligibilityStatus: .eligible,
                purchaseState: .notPurchased,
                purchaseResult: .fails,
                restoredPurchaseState: nil
            )
        }
    }

    /// 偽の購入が、商品の取得・購入・復元を失敗させる時に投げる error。
    struct DeveloperMenuFakePurchaseFailure: Error {}

    /// 決めた商品と状態を返す、偽の `PurchaseService`。RevenueCat の SDK も App Store も呼ばない。
    ///
    /// iOS Simulator と CI では App Store の商品を取得できないため、購入の画面を Simulator と UI テストと単体テストで確かめるのに使う
    /// (`documents/adr/0001-verify-on-external-machines.md`)。購入と復元で変わる状態を覚えるため class にしている。
    final class DeveloperMenuFakePurchaseService: PurchaseService {
        /// 返す商品。nil の時は、商品の取得に失敗する。
        private let fakePackages: [Package]?
        /// どの商品にも返す、利用者がトライアルを使えるか。
        private let introEligibilityStatus: IntroEligibilityStatus
        /// 利用者の今の購入の状態。購入と復元で変わる。
        private var purchaseState: PurchaseState
        /// 商品を購入した時に起きること。
        private let purchaseResult: DeveloperMenuFakePurchaseResult
        /// 復元した後の購入の状態。nil の時は、復元に失敗する。
        private let restoredPurchaseState: PurchaseState?

        /// 返す商品 `packages` (nil の時は取得に失敗する)、利用者がトライアルを使えるか、初めの購入の状態、商品を購入した時に起きること、
        /// 復元した後の購入の状態 (nil の時は復元に失敗する) を決めて作る。
        init(
            packages: [Package]?,
            introEligibilityStatus: IntroEligibilityStatus,
            purchaseState: PurchaseState,
            purchaseResult: DeveloperMenuFakePurchaseResult,
            restoredPurchaseState: PurchaseState?
        ) {
            fakePackages = packages
            self.introEligibilityStatus = introEligibilityStatus
            self.purchaseState = purchaseState
            self.purchaseResult = purchaseResult
            self.restoredPurchaseState = restoredPurchaseState
        }

        /// 作る時に決めた商品を返す。商品が nil の時は `DeveloperMenuFakePurchaseFailure` を投げる。
        func packages() async throws -> [Package] {
            guard let fakePackages else {
                throw DeveloperMenuFakePurchaseFailure()
            }
            return fakePackages
        }

        /// `packages` のどの商品にも、作る時に決めた「トライアルを使えるか」を返す。
        func introEligibilityStatuses(packages: [Package]) async -> [Package: IntroEligibilityStatus] {
            Dictionary(uniqueKeysWithValues: packages.map { ($0, introEligibilityStatus) })
        }

        /// 購入できる時は、購入の状態を、`package` のトライアルを使える時はトライアル中に、使えない時は購入済みに変えて返す。
        /// 利用者が取り消す時は、状態を変えずに今の状態を返す。購入に失敗する時は、状態を変えずに `DeveloperMenuFakePurchaseFailure` を投げる。
        /// App Store の購入の確認は出さない。
        func purchase(package: Package) async throws -> PurchaseState {
            switch purchaseResult {
            case .succeeds:
                purchaseState = purchaseTrialLengthText(package: package, introEligibilityStatus: introEligibilityStatus) == nil ? .purchased : .inTrial
            case .isCancelled:
                break
            case .fails:
                throw DeveloperMenuFakePurchaseFailure()
            }
            return purchaseState
        }

        /// 購入の状態を、作る時に決めた復元した後の状態に変えて返す。
        /// 復元した後の状態が nil の時は、状態を変えずに `DeveloperMenuFakePurchaseFailure` を投げる。
        func restore() async throws -> PurchaseState {
            guard let restoredPurchaseState else {
                throw DeveloperMenuFakePurchaseFailure()
            }
            purchaseState = restoredPurchaseState
            return purchaseState
        }

        /// 今の購入の状態を返す。
        func state() async throws -> PurchaseState {
            purchaseState
        }
    }

    /// 偽の購入が返す、年額・月額・買い切りの 3 つの商品を作る。並びと値段とトライアルの長さは、購入の画面のモック
    /// (`documents/design/mock-2026-11-18/Purchase.dc.html`) に合わせた見本で、実物の値は App Store が返す。
    func makeDeveloperMenuFakePurchasePackages() -> [Package] {
        [
            makeDeveloperMenuFakePurchasePackage(
                packageType: .annual,
                localizedPriceString: "¥5,000",
                price: 5000,
                subscriptionPeriod: SubscriptionPeriod(value: 1, unit: .year),
                trialPeriod: SubscriptionPeriod(value: 1, unit: .week)
            ),
            makeDeveloperMenuFakePurchasePackage(
                packageType: .monthly,
                localizedPriceString: "¥500",
                price: 500,
                subscriptionPeriod: SubscriptionPeriod(value: 1, unit: .month),
                trialPeriod: SubscriptionPeriod(value: 1, unit: .week)
            ),
            makeDeveloperMenuFakePurchasePackage(
                packageType: .lifetime,
                localizedPriceString: "¥20,000",
                price: 20000,
                subscriptionPeriod: nil,
                trialPeriod: nil
            ),
        ]
    }

    /// 偽の商品を 1 つ作る。
    ///
    /// `subscriptionPeriod` が nil の時は更新の無い商品 (買い切り) に、`trialPeriod` が nil の時は無料のトライアルの無い商品にする。
    /// 商品の識別子は `packageType` から作るため、`packageType` が同じなら同じ識別子になる。
    func makeDeveloperMenuFakePurchasePackage(
        packageType: PackageType,
        localizedPriceString: String,
        price: Decimal,
        subscriptionPeriod: SubscriptionPeriod?,
        trialPeriod: SubscriptionPeriod?
    ) -> Package {
        Package(
            identifier: "fake_package_\(packageType.rawValue)",
            packageType: packageType,
            storeProduct: TestStoreProduct(
                localizedTitle: "偽の商品 \(packageType.rawValue)",
                price: price,
                currencyCode: "JPY",
                localizedPriceString: localizedPriceString,
                productIdentifier: "fake_product_\(packageType.rawValue)",
                productType: subscriptionPeriod == nil ? .nonConsumable : .autoRenewableSubscription,
                localizedDescription: "開発者メニューの偽の購入が返す商品",
                subscriptionPeriod: subscriptionPeriod,
                introductoryDiscount: trialPeriod.map {
                    TestStoreProductDiscount(
                        identifier: "fake_trial_\(packageType.rawValue)",
                        price: 0,
                        localizedPriceString: "¥0",
                        paymentMode: .freeTrial,
                        subscriptionPeriod: $0,
                        numberOfPeriods: 1,
                        type: .introductory
                    )
                },
                locale: Locale(identifier: "ja_JP")
            ).toStoreProduct(),
            offeringIdentifier: "fake_offering",
            webCheckoutUrl: nil
        )
    }
#endif
