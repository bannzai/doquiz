import Foundation
import RevenueCat
import Testing

@testable import Doquiz

/// 購入の画面に出す中身と文を、偽の購入 (`DeveloperMenuFakePurchaseService`) と偽の商品で確かめる。
/// RevenueCat と App Store は呼ばない (単体テストの起動では SDK を初期化しないことも確かめる)。
struct PurchaseTests {
    /// 画面に出す中身 `purchaseContent` の種類の名前を返す (中身は商品を持ち `==` で比べられないため、種類を名前で比べる)。
    private func purchaseContentName(purchaseContent: PurchaseContent) -> String {
        switch purchaseContent {
        case .loading:
            "loading"
        case .packages:
            "packages"
        case .unavailable:
            "unavailable"
        case .inTrial:
            "inTrial"
        case .purchased:
            "purchased"
        }
    }

    /// 導入の特典が `paymentMode` で、長さが `period` の `numberOfPeriods` 個分の、年額の偽の商品を作る。値段は「¥1,234」。
    private func makeAnnualPackage(
        paymentMode: StoreProductDiscount.PaymentMode,
        period: SubscriptionPeriod,
        numberOfPeriods: Int
    ) -> Package {
        Package(
            identifier: "test_annual",
            packageType: .annual,
            storeProduct: TestStoreProduct(
                localizedTitle: "テストの年額",
                price: 1234,
                currencyCode: "JPY",
                localizedPriceString: "¥1,234",
                productIdentifier: "test_annual_product",
                productType: .autoRenewableSubscription,
                localizedDescription: "単体テストの商品",
                subscriptionPeriod: SubscriptionPeriod(value: 1, unit: .year),
                introductoryDiscount: TestStoreProductDiscount(
                    identifier: "test_intro",
                    price: 0,
                    localizedPriceString: "¥0",
                    paymentMode: paymentMode,
                    subscriptionPeriod: period,
                    numberOfPeriods: numberOfPeriods,
                    type: .introductory
                ),
                locale: Locale(identifier: "ja_JP")
            ).toStoreProduct(),
            offeringIdentifier: "test_offering",
            webCheckoutUrl: nil
        )
    }

    /// アプリの Info.plist の、公開 SDK キーのキーの値が、ビルド設定で置き換わった文字列かを返す (値そのものはテストの出力に出さない)。
    private func isPublicAPIKeyInfoDictionaryValueExpanded() -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: revenueCatPublicAPIKeyInfoDictionaryKey) as? String else {
            return false
        }
        return !value.contains("$")
    }

    /// 有効かどうかが `isActive` で、期間の種類が `periodType` の、entitlement `premium` の情報を作る。
    private func makePremiumEntitlementInfo(isActive: Bool, periodType: PeriodType) -> EntitlementInfo {
        EntitlementInfo(
            identifier: revenueCatPremiumEntitlementIdentifier,
            isActive: isActive,
            willRenew: isActive,
            periodType: periodType,
            store: .appStore,
            productIdentifier: "test_annual_product",
            isSandbox: true,
            ownershipType: .purchased
        )
    }

    // MARK: - RevenueCat の entitlement から求める購入の状態

    /// entitlement `premium` を 1 度も持ったことが無い利用者 (情報が無い) は、購入していない。
    @Test func premiumの情報が無い利用者は購入していない() {
        #expect(purchaseState(premiumEntitlementInfo: nil) == .notPurchased)
    }

    /// 有効な `premium` の期間の種類がトライアルの時だけ、トライアル中になる。支払った期間 (通常と、割引の値段で払う導入の期間) は購入済みになる。
    @Test func 有効なpremiumは期間の種類でトライアル中と購入済みに分かれる() {
        #expect(purchaseState(premiumEntitlementInfo: makePremiumEntitlementInfo(isActive: true, periodType: .trial)) == .inTrial)
        #expect(purchaseState(premiumEntitlementInfo: makePremiumEntitlementInfo(isActive: true, periodType: .normal)) == .purchased)
        #expect(purchaseState(premiumEntitlementInfo: makePremiumEntitlementInfo(isActive: true, periodType: .intro)) == .purchased)
    }

    /// `premium` が有効でない利用者 (トライアルや購入の期間が終わった) は、最後の期間の種類に関わらず、購入していない。
    @Test func 有効でないpremiumは購入していない() {
        #expect(purchaseState(premiumEntitlementInfo: makePremiumEntitlementInfo(isActive: false, periodType: .trial)) == .notPurchased)
        #expect(purchaseState(premiumEntitlementInfo: makePremiumEntitlementInfo(isActive: false, periodType: .normal)) == .notPurchased)
    }

    // MARK: - 購入の状態と画面に出す中身

    /// 購入していない・トライアル中・購入済みの 3 つの状態で、画面に出す中身が変わる。
    @Test(arguments: [
        (PurchaseState.notPurchased, "packages"),
        (PurchaseState.inTrial, "inTrial"),
        (PurchaseState.purchased, "purchased"),
    ])
    func 購入の状態ごとに出す中身が変わる(purchaseState: PurchaseState, expectedContentName: String) async {
        #expect(
            purchaseContentName(
                purchaseContent: await loadPurchaseContent(
                    purchaseService: DeveloperMenuFakePurchaseService(
                        packages: makeDeveloperMenuFakePurchasePackages(),
                        introEligibilityStatus: .eligible,
                        purchaseState: purchaseState,
                        purchaseResult: .succeeds,
                        purchaseStateAfterGettingPackages: nil,
                        restoredPurchaseState: purchaseState
                    )
                )
            ) == expectedContentName
        )
    }

    /// 商品を取得できた時は、取得した商品を取得した並びのまま、商品ごとの「トライアルを使えるか」と一緒に出す。
    @Test func 商品を取得できた時は取得した並びのまま出す() async {
        let packages = makeDeveloperMenuFakePurchasePackages()

        let purchaseContent = await loadPurchaseContent(
            purchaseService: DeveloperMenuFakePurchaseService(
                packages: packages,
                introEligibilityStatus: .ineligible,
                purchaseState: .notPurchased,
                purchaseResult: .succeeds,
                purchaseStateAfterGettingPackages: nil,
                restoredPurchaseState: .notPurchased
            )
        )

        guard case .packages(let contentPackages, let introEligibilityStatuses) = purchaseContent else {
            Issue.record("商品を出す中身にならなかった: \(purchaseContentName(purchaseContent: purchaseContent))")
            return
        }
        #expect(contentPackages.map(\.identifier) == packages.map(\.identifier))
        #expect(contentPackages.map(\.packageType) == [.annual, .monthly, .lifetime])
        #expect(packages.map { introEligibilityStatuses[$0] } == [.ineligible, .ineligible, .ineligible])
    }

    /// 商品の取得に失敗した時は、商品を出さず、取得できなかった時の中身にする。
    @Test func 商品を取得できない時は取得できなかった時の中身にする() async {
        #expect(
            purchaseContentName(
                purchaseContent: await loadPurchaseContent(
                    purchaseService: makeDeveloperMenuFakePurchaseService(behavior: .failsToGetPackages)
                )
            ) == "unavailable"
        )
    }

    /// 取得できた商品が 0 件の時は、何も買えない画面を出さず、取得できなかった時の中身にする。1 件あれば商品を出す。
    @Test(arguments: [(0, "unavailable"), (1, "packages")])
    func 商品が0件の時は取得できなかった時の中身にする(packageCount: Int, expectedContentName: String) async {
        #expect(
            purchaseContentName(
                purchaseContent: await loadPurchaseContent(
                    purchaseService: DeveloperMenuFakePurchaseService(
                        packages: Array(makeDeveloperMenuFakePurchasePackages().prefix(packageCount)),
                        introEligibilityStatus: .eligible,
                        purchaseState: .notPurchased,
                        purchaseResult: .succeeds,
                        purchaseStateAfterGettingPackages: nil,
                        restoredPurchaseState: .notPurchased
                    )
                )
            ) == expectedContentName
        )
    }

    /// トライアル中と購入済みの利用者には、商品の取得に失敗しても、状態の中身を出す (商品を出さないため)。
    @Test(arguments: [(PurchaseState.inTrial, "inTrial"), (PurchaseState.purchased, "purchased")])
    func 購入済みの利用者には商品を取得できなくても状態を出す(purchaseState: PurchaseState, expectedContentName: String) async {
        #expect(
            purchaseContentName(
                purchaseContent: await loadPurchaseContent(
                    purchaseService: DeveloperMenuFakePurchaseService(
                        packages: nil,
                        introEligibilityStatus: .unknown,
                        purchaseState: purchaseState,
                        purchaseResult: .succeeds,
                        purchaseStateAfterGettingPackages: nil,
                        restoredPurchaseState: purchaseState
                    )
                )
            ) == expectedContentName
        )
    }

    // MARK: - 購入と復元

    /// トライアルを使える利用者が、トライアルのある商品を購入すると、トライアル中になる。その後に画面を開くと、トライアル中の中身が出る。
    @Test func トライアルを使える利用者がトライアルのある商品を購入するとトライアル中になる() async throws {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .returnsPackages)
        #expect(try await purchaseService.state() == .notPurchased)

        #expect(try await purchaseService.purchase(package: makeDeveloperMenuFakePurchasePackages()[0]) == .inTrial)

        #expect(try await purchaseService.state() == .inTrial)
        #expect(purchaseContentName(purchaseContent: await loadPurchaseContent(purchaseService: purchaseService)) == "inTrial")
    }

    /// トライアルの無い商品 (買い切り) を購入すると、購入済みになる。その後に画面を開くと、購入済みの中身が出る。
    @Test func トライアルの無い商品を購入すると購入済みになる() async throws {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .returnsPackages)

        #expect(try await purchaseService.purchase(package: makeDeveloperMenuFakePurchasePackages()[2]) == .purchased)

        #expect(try await purchaseService.state() == .purchased)
        #expect(purchaseContentName(purchaseContent: await loadPurchaseContent(purchaseService: purchaseService)) == "purchased")
    }

    /// トライアルを使えない利用者は、トライアルのある商品を購入しても、トライアル中ではなく購入済みになる。
    @Test func トライアルを使えない利用者がトライアルのある商品を購入すると購入済みになる() async throws {
        #expect(
            try await DeveloperMenuFakePurchaseService(
                packages: makeDeveloperMenuFakePurchasePackages(),
                introEligibilityStatus: .ineligible,
                purchaseState: .notPurchased,
                purchaseResult: .succeeds,
                purchaseStateAfterGettingPackages: nil,
                restoredPurchaseState: .notPurchased
            ).purchase(package: makeDeveloperMenuFakePurchasePackages()[0]) == .purchased
        )
    }

    /// 復元すると、復元できた購入の状態になる。その後に画面を開くと、購入済みの中身が出る。
    @Test func 復元すると購入済みになる() async throws {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .returnsPackages)

        #expect(try await purchaseService.restore() == .purchased)

        #expect(try await purchaseService.state() == .purchased)
        #expect(purchaseContentName(purchaseContent: await loadPurchaseContent(purchaseService: purchaseService)) == "purchased")
    }

    /// 復元できる購入が無い時は、復元しても購入していないままである。
    @Test func 復元できる購入が無い時は購入していないままである() async throws {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .failsToGetPackages)

        #expect(try await purchaseService.restore() == .notPurchased)
        #expect(try await purchaseService.state() == .notPurchased)
    }

    // MARK: - 購入と復元の結果と、その時に出す文

    /// 購入できた時は、結果がその後の状態 (トライアル中・購入済み) になり、出す文は無い。
    @Test func 購入できた時は状態が変わった結果になり文を出さない() async {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .returnsPackages)

        let trialResult = await purchaseOperationResult {
            try await purchaseService.purchase(package: makeDeveloperMenuFakePurchasePackages()[0])
        }

        #expect(trialResult == .stateChanged(.inTrial))
        #expect(purchaseFailureMessage(result: trialResult) == nil)
        #expect(await purchaseOperationResult { try await purchaseService.purchase(package: makeDeveloperMenuFakePurchasePackages()[2]) } == .stateChanged(.purchased))
    }

    /// 利用者が購入を取り消した時は、状態が購入していないままで、結果は「変わらなかった」になり、購入の失敗の文を出さない。
    @Test func 購入を取り消した時は変わらなかった結果になり文を出さない() async throws {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .cancelsPurchase)

        let result = await purchaseOperationResult {
            try await purchaseService.purchase(package: makeDeveloperMenuFakePurchasePackages()[0])
        }

        #expect(result == .unchanged)
        #expect(purchaseFailureMessage(result: result) == nil)
        #expect(try await purchaseService.state() == .notPurchased)
        #expect(purchaseContentName(purchaseContent: await loadPurchaseContent(purchaseService: purchaseService)) == "packages")
    }

    /// 購入に失敗した時は、error を外へ投げずに結果が「失敗した」になり、購入できなかった文を出す。状態は購入していないままである。
    @Test func 購入に失敗した時は失敗した結果になり購入できなかった文を出す() async throws {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .failsToPurchaseAndRestore)

        let result = await purchaseOperationResult {
            try await purchaseService.purchase(package: makeDeveloperMenuFakePurchasePackages()[0])
        }

        #expect(result == .failed)
        #expect(purchaseFailureMessage(result: result) == "購入できませんでした\n時間をおいて もう一度お試しください")
        #expect(try await purchaseService.state() == .notPurchased)
    }

    /// 復元できた時は、結果が復元の後の状態になり、出す文は無い。
    @Test func 復元できた時は状態が変わった結果になり文を出さない() async {
        let result = await purchaseOperationResult { try await makeDeveloperMenuFakePurchaseService(behavior: .returnsPackages).restore() }

        #expect(result == .stateChanged(.purchased))
        #expect(restoreFailureMessage(result: result) == nil)
    }

    /// 復元できる購入が無かった時は、結果は「変わらなかった」になり、見つからなかった文を出す (購入を取り消した時と違い、文を出す)。
    @Test func 復元できる購入が無い時は見つからなかった文を出す() async {
        let result = await purchaseOperationResult { try await makeDeveloperMenuFakePurchaseService(behavior: .cancelsPurchase).restore() }

        #expect(result == .unchanged)
        #expect(restoreFailureMessage(result: result) == "復元できる購入が見つかりませんでした")
    }

    /// 復元に失敗した時は、error を外へ投げずに結果が「失敗した」になり、復元できなかった文を出す。状態は購入していないままである。
    @Test func 復元に失敗した時は失敗した結果になり復元できなかった文を出す() async throws {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .failsToPurchaseAndRestore)

        let result = await purchaseOperationResult { try await purchaseService.restore() }

        #expect(result == .failed)
        #expect(restoreFailureMessage(result: result) == "復元できませんでした\n時間をおいて もう一度お試しください")
        #expect(try await purchaseService.state() == .notPurchased)
    }

    // MARK: - 画面を出している間に届く、購入の状態の変化

    /// 商品を出している時に、トライアル中か購入済みだと知らされたら、その状態の中身に入れ替える。購入していないと知らされた時は、画面を変えない。
    @Test func 商品を出している時に購入済みと知らされたら状態の中身に入れ替える() {
        let content = PurchaseContent.packages(makeDeveloperMenuFakePurchasePackages(), introEligibilityStatuses: [:])

        #expect(purchaseStateUpdateAction(content: content, purchaseState: .purchased) == .showState)
        #expect(purchaseStateUpdateAction(content: content, purchaseState: .inTrial) == .showState)
        #expect(purchaseStateUpdateAction(content: content, purchaseState: .notPurchased) == .keep)
    }

    /// トライアル中か購入済みの中身を出している時に、購入していないと知らされたら (期間が終わった)、取得し直す。
    /// 同じ状態だと知らされた時は画面を変えず、もう一方の状態だと知らされた時は、その状態の中身に入れ替える。
    @Test func 状態の中身を出している時に購入していないと知らされたら取得し直す() {
        #expect(purchaseStateUpdateAction(content: .purchased, purchaseState: .notPurchased) == .reload)
        #expect(purchaseStateUpdateAction(content: .inTrial, purchaseState: .notPurchased) == .reload)
        #expect(purchaseStateUpdateAction(content: .purchased, purchaseState: .purchased) == .keep)
        #expect(purchaseStateUpdateAction(content: .inTrial, purchaseState: .inTrial) == .keep)
        #expect(purchaseStateUpdateAction(content: .inTrial, purchaseState: .purchased) == .showState)
        #expect(purchaseStateUpdateAction(content: .purchased, purchaseState: .inTrial) == .showState)
    }

    /// 取得できなかった時の中身と取得している間は、購入済みかトライアル中だと知らされたら状態の中身に入れ替え、購入していないと知らされた時は画面を変えない
    /// (取得できなかった時は、利用者が「もう一度取得する」を押すまで取得し直さない)。
    @Test func 取得できなかった時の中身を出している時は購入していないと知らされても画面を変えない() {
        #expect(purchaseStateUpdateAction(content: .unavailable, purchaseState: .notPurchased) == .keep)
        #expect(purchaseStateUpdateAction(content: .unavailable, purchaseState: .purchased) == .showState)
        #expect(purchaseStateUpdateAction(content: .loading, purchaseState: .notPurchased) == .keep)
        #expect(purchaseStateUpdateAction(content: .loading, purchaseState: .inTrial) == .showState)
    }

    /// 偽の購入は、商品を返した直後に購入の状態が変わる時、変わった後の状態を stream に流し、その後の状態の取得も変わった後の状態を返す。
    /// 画面を開き直すと (状態を取得し直すと)、購入済みの中身になる。
    @Test(.timeLimit(.minutes(1)))
    func 商品を返した直後に変わった購入の状態がstreamに流れる() async throws {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .becomesPurchasedAfterGettingPackages)
        #expect(try await purchaseService.state() == .notPurchased)

        #expect(purchaseContentName(purchaseContent: await loadPurchaseContent(purchaseService: purchaseService)) == "packages")

        var receivedPurchaseStates: [PurchaseState] = []
        for await purchaseState in purchaseService.stateUpdates() {
            receivedPurchaseStates.append(purchaseState)
            break
        }
        #expect(receivedPurchaseStates == [.purchased])
        #expect(try await purchaseService.state() == .purchased)
        #expect(purchaseContentName(purchaseContent: await loadPurchaseContent(purchaseService: purchaseService)) == "purchased")
    }

    /// 偽の購入は、購入と復元で状態を変えるたびに、変えた順で stream に流す。
    @Test(.timeLimit(.minutes(1)))
    func 購入と復元で変えた購入の状態がstreamに流れる() async throws {
        let purchaseService = makeDeveloperMenuFakePurchaseService(behavior: .returnsPackages)
        #expect(try await purchaseService.purchase(package: makeDeveloperMenuFakePurchasePackages()[0]) == .inTrial)
        #expect(try await purchaseService.restore() == .purchased)

        var receivedPurchaseStates: [PurchaseState] = []
        for await purchaseState in purchaseService.stateUpdates() {
            receivedPurchaseStates.append(purchaseState)
            if receivedPurchaseStates.count == 2 {
                break
            }
        }
        #expect(receivedPurchaseStates == [.inTrial, .purchased])
    }

    /// 実物の購入は、SDK を初期化していない時、状態の変化を 1 つも流さずに終わる stream を返す (受け取る側が待ち続けない)。
    @Test(.timeLimit(.minutes(1)))
    func 実物の購入はSDKを初期化していない時に何も流さずに終わるstreamを返す() async {
        var receivedPurchaseStates: [PurchaseState] = []
        for await purchaseState in RevenueCatPurchaseService().stateUpdates() {
            receivedPurchaseStates.append(purchaseState)
        }
        #expect(receivedPurchaseStates.isEmpty)
    }

    // MARK: - 画面に出す文

    /// 期間の長さの文は、単位ごとに、渡した個数で作る。
    @Test func 期間の長さの文は単位と個数で作る() {
        #expect(purchasePeriodLengthText(value: 3, unit: .day) == "3 日間")
        #expect(purchasePeriodLengthText(value: 1, unit: .week) == "1 週間")
        #expect(purchasePeriodLengthText(value: 6, unit: .month) == "6 か月")
        #expect(purchasePeriodLengthText(value: 1, unit: .year) == "1 年")
    }

    /// 商品の名前は、商品の種類から月額・年額・買い切りにする。3 つのどれでもない商品は、ストアの商品の名前を出す。
    @Test func 商品の名前は商品の種類で決まる() {
        #expect(makeDeveloperMenuFakePurchasePackages().map { purchasePlanName(package: $0) } == ["年額", "月額", "買い切り"])
        #expect(
            purchasePlanName(
                package: makeDeveloperMenuFakePurchasePackage(
                    packageType: .custom,
                    localizedPriceString: "¥300",
                    price: 300,
                    subscriptionPeriod: nil,
                    trialPeriod: nil
                )
            ) == "偽の商品 \(PackageType.custom.rawValue)"
        )
    }

    /// トライアルの長さは、利用者がトライアルを使えると確かめられた時だけ、取得した商品の長さで出す。
    /// 使えない・確かめられなかった (unknown と nil)・導入の特典が無い、の時は出さない。
    @Test func トライアルの長さは使えると確かめられた時だけ取得した長さで出す() {
        let package = makeAnnualPackage(paymentMode: .freeTrial, period: SubscriptionPeriod(value: 3, unit: .day), numberOfPeriods: 1)

        #expect(purchaseTrialLengthText(package: package, introEligibilityStatus: .eligible) == "3 日間")
        #expect(purchaseTrialLengthText(package: package, introEligibilityStatus: .ineligible) == nil)
        #expect(purchaseTrialLengthText(package: package, introEligibilityStatus: .unknown) == nil)
        #expect(purchaseTrialLengthText(package: package, introEligibilityStatus: .noIntroOfferExists) == nil)
        #expect(purchaseTrialLengthText(package: package, introEligibilityStatus: nil) == nil)
    }

    /// トライアルの長さは、特典の 1 回分の期間に回数を掛けた長さにする。
    @Test func トライアルの長さは期間に回数を掛ける() {
        #expect(
            purchaseTrialLengthText(
                package: makeAnnualPackage(paymentMode: .freeTrial, period: SubscriptionPeriod(value: 1, unit: .month), numberOfPeriods: 2),
                introEligibilityStatus: .eligible
            ) == "2 か月"
        )
    }

    /// 導入の特典が無料ではない (割引の値段で払う) 商品は、利用者が特典を使えても「無料」と出さない。
    @Test func 無料でない導入の特典はトライアルとして出さない() {
        for paymentMode in [StoreProductDiscount.PaymentMode.payAsYouGo, .payUpFront] {
            let package = makeAnnualPackage(paymentMode: paymentMode, period: SubscriptionPeriod(value: 1, unit: .week), numberOfPeriods: 1)

            #expect(purchaseTrialLengthText(package: package, introEligibilityStatus: .eligible) == nil)
            #expect(purchaseButtonTitle(package: package, introEligibilityStatus: .eligible) == "購入する")
            #expect(purchasePlanDescription(package: package, introEligibilityStatus: .eligible) == "1 年ごとに更新")
        }
    }

    /// 導入の特典が無い商品 (買い切り) は、利用者の状態に関わらずトライアルを出さない。
    @Test func 導入の特典が無い商品はトライアルを出さない() {
        #expect(purchaseTrialLengthText(package: makeDeveloperMenuFakePurchasePackages()[2], introEligibilityStatus: .eligible) == nil)
    }

    /// トライアルを使える時の説明・ボタン・更新の説明は、取得した値段とトライアルの長さで作る。
    @Test func トライアルを使える時の文は取得した値段と長さで作る() {
        let package = makeAnnualPackage(paymentMode: .freeTrial, period: SubscriptionPeriod(value: 3, unit: .day), numberOfPeriods: 1)

        #expect(purchasePlanDescription(package: package, introEligibilityStatus: .eligible) == "3 日間無料 その後 1 年ごとに更新")
        #expect(purchaseButtonTitle(package: package, introEligibilityStatus: .eligible) == "3 日間無料で始める")
        #expect(purchaseRenewalNote(package: package, introEligibilityStatus: .eligible) == "無料の期間が終わると年額 ¥1,234 で自動で更新されます")
    }

    /// トライアルを使えない時の説明・ボタン・更新の説明は、「無料」を出さず、取得した値段と更新の間隔で作る。
    @Test func トライアルを使えない時の文は無料を出さない() {
        let package = makeAnnualPackage(paymentMode: .freeTrial, period: SubscriptionPeriod(value: 3, unit: .day), numberOfPeriods: 1)

        #expect(purchasePlanDescription(package: package, introEligibilityStatus: .ineligible) == "1 年ごとに更新")
        #expect(purchaseButtonTitle(package: package, introEligibilityStatus: .ineligible) == "購入する")
        #expect(purchaseRenewalNote(package: package, introEligibilityStatus: .ineligible) == "年額 ¥1,234 で自動で更新されます")
    }

    /// 更新の無い商品 (買い切り) は、1 回の支払いであることを説明に出し、自動で更新される説明を出さない。
    @Test func 更新の無い商品は自動で更新される説明を出さない() {
        let lifetimePackage = makeDeveloperMenuFakePurchasePackages()[2]

        #expect(purchasePlanDescription(package: lifetimePackage, introEligibilityStatus: .eligible) == "1 回の支払いでずっと使えます")
        #expect(purchaseButtonTitle(package: lifetimePackage, introEligibilityStatus: .eligible) == "購入する")
        #expect(purchaseRenewalNote(package: lifetimePackage, introEligibilityStatus: .eligible) == nil)
    }

    /// 月額の商品の説明は、取得した更新の間隔 (1 か月) で作る。
    @Test func 月額の商品の説明は取得した更新の間隔で作る() {
        let monthlyPackage = makeDeveloperMenuFakePurchasePackages()[1]

        #expect(purchasePlanDescription(package: monthlyPackage, introEligibilityStatus: .eligible) == "1 週間無料 その後 1 か月ごとに更新")
        #expect(purchaseRenewalNote(package: monthlyPackage, introEligibilityStatus: .eligible) == "無料の期間が終わると月額 ¥500 で自動で更新されます")
    }

    // MARK: - RevenueCat の SDK の初期化

    /// 公開 SDK キーは、Info.plist の値が空でない文字列の時だけ返す。
    @Test func 公開SDKキーは空でない文字列の時だけ返す() {
        #expect(revenueCatPublicAPIKey(infoDictionaryValue: "appl_FakeKey") == "appl_FakeKey")
        #expect(revenueCatPublicAPIKey(infoDictionaryValue: "") == nil)
        #expect(revenueCatPublicAPIKey(infoDictionaryValue: nil) == nil)
        #expect(revenueCatPublicAPIKey(infoDictionaryValue: 123) == nil)
    }

    /// アプリの Info.plist の公開 SDK キーの値は、ビルド設定で置き換わっている (置き換える前の `$(...)` のままではない)。
    @Test func アプリのInfoPlistの公開SDKキーはビルド設定で置き換わっている() {
        #expect(isPublicAPIKeyInfoDictionaryValueExpanded())
    }

    /// 単体テストの起動かは、環境変数 `XCTestConfigurationFilePath` があるかで決まる。この単体テストの起動にも、その環境変数がある。
    @Test func 単体テストの起動を環境変数で見分ける() {
        #expect(isLaunchedAsUnitTestHost(environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"]))
        #expect(isLaunchedAsUnitTestHost(environment: ["PATH": "/usr/bin"]) == false)
        #expect(isLaunchedAsUnitTestHost(environment: [:]) == false)
        #expect(isLaunchedAsUnitTestHost(environment: ProcessInfo.processInfo.environment))
    }

    /// 単体テストの起動では RevenueCat の SDK を初期化しない。初期化していない間、実物の購入は SDK を呼ばずに、
    /// 商品と状態の取得で error を投げ、トライアルを使えるかを 1 つも返さず、画面は取得できなかった時の中身になる。
    @Test func 実物の購入はSDKを初期化していない時に取得できなかった時の中身になる() async {
        #expect(Purchases.isConfigured == false)
        let purchaseService = RevenueCatPurchaseService()

        await #expect(throws: RevenueCatNotConfiguredError.self) {
            try await purchaseService.packages()
        }
        await #expect(throws: RevenueCatNotConfiguredError.self) {
            try await purchaseService.state()
        }
        await #expect(throws: RevenueCatNotConfiguredError.self) {
            try await purchaseService.restore()
        }
        await #expect(throws: RevenueCatNotConfiguredError.self) {
            try await purchaseService.purchase(package: makeDeveloperMenuFakePurchasePackages()[0])
        }
        #expect(await purchaseService.introEligibilityStatuses(packages: makeDeveloperMenuFakePurchasePackages()).isEmpty)
        #expect(purchaseContentName(purchaseContent: await loadPurchaseContent(purchaseService: purchaseService)) == "unavailable")
    }

    /// 公開 SDK キーが無い時は、SDK を初期化しない。
    @Test func 公開SDKキーが無い時はSDKを初期化しない() {
        configureRevenueCat(publicAPIKey: nil)

        #expect(Purchases.isConfigured == false)
    }

    // MARK: - 開発者メニューの切り替え

    /// 開発者メニューの購入の動きは、実物 → 商品を返す → 商品を取得できない → トライアル中 → 購入済み → 購入を取り消す → 購入と復元に失敗する → 開いた後に購入済みに変わる → 実物、と一巡する。
    @Test func 開発者メニューの購入の動きは一巡する() {
        #expect(nextDeveloperMenuFakePurchaseBehavior(behavior: nil) == .returnsPackages)
        #expect(nextDeveloperMenuFakePurchaseBehavior(behavior: .returnsPackages) == .failsToGetPackages)
        #expect(nextDeveloperMenuFakePurchaseBehavior(behavior: .failsToGetPackages) == .inTrial)
        #expect(nextDeveloperMenuFakePurchaseBehavior(behavior: .inTrial) == .purchased)
        #expect(nextDeveloperMenuFakePurchaseBehavior(behavior: .purchased) == .cancelsPurchase)
        #expect(nextDeveloperMenuFakePurchaseBehavior(behavior: .cancelsPurchase) == .failsToPurchaseAndRestore)
        #expect(nextDeveloperMenuFakePurchaseBehavior(behavior: .failsToPurchaseAndRestore) == .becomesPurchasedAfterGettingPackages)
        #expect(nextDeveloperMenuFakePurchaseBehavior(behavior: .becomesPurchasedAfterGettingPackages) == nil)
    }

    /// 開発者メニューに出す購入の動きの名前は、動きごとに違う。
    @Test func 開発者メニューの購入の動きの名前() {
        #expect(developerMenuFakePurchaseBehaviorLabel(behavior: nil) == "実物")
        #expect(developerMenuFakePurchaseBehaviorLabel(behavior: .returnsPackages) == "商品を返す")
        #expect(developerMenuFakePurchaseBehaviorLabel(behavior: .failsToGetPackages) == "商品を取得できない")
        #expect(developerMenuFakePurchaseBehaviorLabel(behavior: .inTrial) == "トライアル中")
        #expect(developerMenuFakePurchaseBehaviorLabel(behavior: .purchased) == "購入済み")
        #expect(developerMenuFakePurchaseBehaviorLabel(behavior: .cancelsPurchase) == "購入を取り消す")
        #expect(developerMenuFakePurchaseBehaviorLabel(behavior: .failsToPurchaseAndRestore) == "購入と復元に失敗する")
        #expect(developerMenuFakePurchaseBehaviorLabel(behavior: .becomesPurchasedAfterGettingPackages) == "開いた後に購入済みに変わる")
    }
}
