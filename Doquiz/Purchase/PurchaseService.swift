import RevenueCat

/// 購入 (商品の取得・購入・復元・購入の状態の取得) の境界。
///
/// 実物は RevenueCat の SDK を呼ぶ `RevenueCatPurchaseService`。iOS Simulator と CI では App Store の商品を取得できないため、
/// 購入の画面は偽の実装 (`DeveloperMenuFakePurchaseService`) に差し替えて確かめる (`documents/adr/0001-verify-on-external-machines.md`)。
/// 商品と値段・トライアルの長さの型は、RevenueCat の SDK の型 (`Package`) をそのまま使う。
protocol PurchaseService {
    /// 利用者に出す商品を、出す順に返す。
    ///
    /// 商品を取得できない時 (通信できない・RevenueCat の SDK を初期化していない等) は error を投げる。出す商品が無い時は空の配列を返す。
    func packages() async throws -> [Package]

    /// `packages` のそれぞれについて、利用者がトライアル (導入の特典) を使えるかを返す。
    ///
    /// 確かめられなかった商品は、返り値に入れないか `.unknown` を入れる。
    func introEligibilityStatuses(packages: [Package]) async -> [Package: IntroEligibilityStatus]

    /// `package` を購入し、購入の後の状態を返す。
    ///
    /// 利用者が購入を取り消した時は error を投げず、変わっていない今の状態を返す。購入に失敗した時は error を投げる。
    /// 冪等ではない: 呼ぶたびに購入の確認を利用者に出す。
    func purchase(package: Package) async throws -> PurchaseState

    /// 利用者の App Store のアカウントの購入を復元し、復元の後の状態を返す。復元に失敗した時は error を投げる。
    ///
    /// App Store のサインインを利用者に求めることがあるため、利用者がボタンを押した時だけ呼ぶ
    /// (https://www.revenuecat.com/docs/getting-started/restoring-purchases )。
    func restore() async throws -> PurchaseState

    /// 利用者の今の購入の状態を返す。取得できない時は error を投げる。
    ///
    /// 端末に持っている状態を返すことがあり、その後に取り直した新しい状態は `stateUpdates()` に流れる。
    func state() async throws -> PurchaseState

    /// 購入の状態が変わるたびに、新しい状態を流す stream を返す。
    ///
    /// 受け取り始めた時点までに知っている状態があれば、初めにそれを流す。同じ状態を続けて流すことがある。
    /// 状態を知る手段が無い時 (RevenueCat の SDK を初期化していない時) は、何も流さずに終わる stream を返す。
    func stateUpdates() -> AsyncStream<PurchaseState>
}
