import Foundation
import RevenueCat

/// RevenueCat の公開 SDK キーを入れている、Info.plist のキー。
///
/// 値はビルド設定 `REVENUECAT_PUBLIC_API_KEY_IOS` (`Doquiz.xcconfig` と git 管理外の `Secrets.xcconfig`) からビルド時に入る。
let revenueCatPublicAPIKeyInfoDictionaryKey = "REVENUECAT_PUBLIC_API_KEY_IOS"

/// 購入した利用者に付く、RevenueCat の entitlement の識別子。RevenueCat のプロジェクトの設定と同じ値にする。
let revenueCatPremiumEntitlementIdentifier = "premium"

/// RevenueCat の SDK を初期化していない (公開 SDK キーが無い) のに、購入の処理を呼んだことを表す error。
struct RevenueCatNotConfiguredError: Error {}

/// Info.plist から読んだ値 `infoDictionaryValue` から、RevenueCat の公開 SDK キーを返す。
///
/// 値が無い時・文字列でない時・空の時 (`Secrets.xcconfig` が無いビルド) は nil を返す。
func revenueCatPublicAPIKey(infoDictionaryValue: Any?) -> String? {
    guard let publicAPIKey = infoDictionaryValue as? String, !publicAPIKey.isEmpty else {
        return nil
    }
    return publicAPIKey
}

/// アプリが、単体テストを動かすために起動されたかを、プロセスの環境変数 `environment` から返す。
///
/// 単体テストはアプリの中で動き、Xcode がその起動に環境変数 `XCTestConfigurationFilePath` を渡す
/// (渡されることは `DoquizTests/PurchaseTests.swift` の単体テストが、実際の環境変数で確かめている)。
func isLaunchedAsUnitTestHost(environment: [String: String]) -> Bool {
    environment["XCTestConfigurationFilePath"] != nil
}

/// RevenueCat の SDK を、公開 SDK キー `publicAPIKey` で初期化する。アプリの入口で呼ぶ。
///
/// `publicAPIKey` が nil の時は初期化しない (購入の画面は、商品を取得できない時の表示になる)。初期化済みの時は何もしないため、何度呼んでも結果は同じ。
/// 利用者の識別子は渡さず、SDK が端末の中に作る匿名の識別子を使う
/// (https://www.revenuecat.com/docs/customers/identifying-customers )。本・本文・問い・回答は SDK に渡さない。
func configureRevenueCat(publicAPIKey: String?) {
    guard let publicAPIKey, !Purchases.isConfigured else {
        return
    }
    Purchases.configure(withAPIKey: publicAPIKey)
}

/// RevenueCat の SDK を呼ぶ、実物の `PurchaseService`。
///
/// SDK を初期化していない時 (`configureRevenueCat(publicAPIKey:)` に nil を渡した時) は、どの処理も SDK を呼ばない。
struct RevenueCatPurchaseService: PurchaseService {
    /// RevenueCat の今の offering の商品を、offering の並びのまま返す。今の offering が無い時は空の配列を返す。
    /// SDK を初期化していない時は `RevenueCatNotConfiguredError` を投げる。
    func packages() async throws -> [Package] {
        guard Purchases.isConfigured else {
            throw RevenueCatNotConfiguredError()
        }
        // 今の offering が無い時に出す商品は無いため、空の配列にする (画面は商品を取得できない時の表示になる)。
        return try await Purchases.shared.offerings().current?.availablePackages ?? []
    }

    /// SDK を初期化していない時は、どの商品も確かめられないため空の辞書を返す。
    func introEligibilityStatuses(packages: [Package]) async -> [Package: IntroEligibilityStatus] {
        guard Purchases.isConfigured else {
            return [:]
        }
        return await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: packages).mapValues(\.status)
    }

    /// SDK を初期化していない時は `RevenueCatNotConfiguredError` を投げる。
    func purchase(package: Package) async throws -> PurchaseState {
        guard Purchases.isConfigured else {
            throw RevenueCatNotConfiguredError()
        }
        do {
            // 利用者が取り消した時、SDK は購入の前と同じ customerInfo を返すため、返す状態は変わらない。
            return purchaseState(
                premiumEntitlementInfo: try await Purchases.shared.purchase(package: package).customerInfo
                    .entitlements[revenueCatPremiumEntitlementIdentifier]
            )
        } catch ErrorCode.purchaseCancelledError {
            // 取り消した時に customerInfo を取得できないと、SDK はこの error を投げる。
            return try await state()
        }
    }

    /// SDK を初期化していない時は `RevenueCatNotConfiguredError` を投げる。
    func restore() async throws -> PurchaseState {
        guard Purchases.isConfigured else {
            throw RevenueCatNotConfiguredError()
        }
        return purchaseState(
            premiumEntitlementInfo: try await Purchases.shared.restorePurchases().entitlements[revenueCatPremiumEntitlementIdentifier]
        )
    }

    /// SDK を初期化していない時は `RevenueCatNotConfiguredError` を投げる。
    func state() async throws -> PurchaseState {
        guard Purchases.isConfigured else {
            throw RevenueCatNotConfiguredError()
        }
        return purchaseState(
            premiumEntitlementInfo: try await Purchases.shared.customerInfo().entitlements[revenueCatPremiumEntitlementIdentifier]
        )
    }
}
