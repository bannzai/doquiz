import RevenueCat
import SwiftUI

/// 購入の画面に出す中身。
enum PurchaseContent {
    /// 商品と購入の状態を取得している。
    case loading
    /// 購入していない利用者に、取得した商品を出す。`introEligibilityStatuses` は商品ごとの、利用者がトライアルを使えるか。
    case packages([Package], introEligibilityStatuses: [Package: IntroEligibilityStatus])
    /// 商品か購入の状態を取得できなかった。値段を出さず、取得し直す導線を出す。
    case unavailable
    /// 利用者がトライアル中である。商品は出さない。
    case inTrial
    /// 利用者が購入済みである。商品は出さない。
    case purchased
}

/// 購入の状態 `purchaseState` の利用者に出す中身を返す。購入していない利用者には、商品 `packages` を出す中身を返す。
///
/// 購入していない利用者に出す商品が 1 つも無い時は、取得できなかった時の中身を返す (何も買えない画面を出さないため)。
func purchaseContent(
    purchaseState: PurchaseState,
    packages: [Package],
    introEligibilityStatuses: [Package: IntroEligibilityStatus]
) -> PurchaseContent {
    switch purchaseState {
    case .inTrial:
        .inTrial
    case .purchased:
        .purchased
    case .notPurchased:
        packages.isEmpty ? .unavailable : .packages(packages, introEligibilityStatuses: introEligibilityStatuses)
    }
}

/// `purchaseService` から購入の状態と商品を取得して、購入の画面に出す中身を返す。
///
/// 購入の状態か商品を取得できなかった時は、取得できなかった時の中身を返す (`.loading` は返さない)。
func loadPurchaseContent(purchaseService: any PurchaseService) async -> PurchaseContent {
    do {
        let purchaseState = try await purchaseService.state()
        guard purchaseState == .notPurchased else {
            return purchaseContent(purchaseState: purchaseState, packages: [], introEligibilityStatuses: [:])
        }
        let packages = try await purchaseService.packages()
        return purchaseContent(
            purchaseState: purchaseState,
            packages: packages,
            introEligibilityStatuses: await purchaseService.introEligibilityStatuses(packages: packages)
        )
    } catch {
        return .unavailable
    }
}

/// 購入か復元の操作の結果。
enum PurchaseOperationResult: Equatable {
    /// トライアル中か購入済みになった。
    case stateChanged(PurchaseState)
    /// 購入していないままだった (利用者が購入を取り消した・復元できる購入が無かった)。
    case unchanged
    /// 操作に失敗した。
    case failed
}

/// 購入か復元の操作 `operation` (操作の後の購入の状態を返す) を実行して、結果を返す。
///
/// `operation` が error を投げた時は、error を投げずに `.failed` を返す。
func purchaseOperationResult(operation: () async throws -> PurchaseState) async -> PurchaseOperationResult {
    do {
        let purchaseState = try await operation()
        return purchaseState == .notPurchased ? .unchanged : .stateChanged(purchaseState)
    } catch {
        return .unchanged
    }
}

/// 購入の結果 `result` の時に、購入のボタンの上に出す文を返す。
///
/// 購入できた時と、利用者が購入を取り消した時 (購入していないまま) は、出す文が無いため nil を返す。
func purchaseFailureMessage(result: PurchaseOperationResult) -> String? {
    switch result {
    case .stateChanged:
        nil
    case .unchanged:
        "購入できませんでした\n時間をおいて もう一度お試しください"
    case .failed:
        nil
    }
}

/// 復元の結果 `result` の時に、購入のボタンの上に出す文を返す。復元できた時は、出す文が無いため nil を返す。
func restoreFailureMessage(result: PurchaseOperationResult) -> String? {
    switch result {
    case .stateChanged, .unchanged:
        nil
    case .failed:
        "復元できませんでした\n時間をおいて もう一度お試しください"
    }
}

/// 購入の画面。月額・年額・買い切りの商品を選んで購入する入口と、購入を復元する入口を出す。
///
/// 値段・更新の間隔・トライアルの長さは、`purchaseService` から取得した商品の値だけを出す。取得できない時は値段を出さず、取得し直す導線を出す。
/// 見た目は `documents/design/mock-2026-11-18/Purchase.dc.html` に合わせる。
struct PurchaseView: View {
    /// 商品の取得・購入・復元に使う購入の境界。
    let purchaseService: any PurchaseService

    /// 画面を閉じる操作。
    @Environment(\.dismiss) private var dismiss
    /// 画面に出している中身。
    @State private var content = PurchaseContent.loading
    /// 利用者が選んでいる商品。商品を出していない間は nil。
    @State private var selectedPackage: Package?
    /// 購入か復元の処理の途中か。途中の間は、購入と復元のボタンを押せなくする。
    @State private var isProcessing = false
    /// 購入か復元がうまくいかなかった時に出す文。出さない時は nil。
    @State private var failureMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                switch content {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("purchase_loading")
                case .packages(let packages, let introEligibilityStatuses):
                    packagesContent(packages: packages, introEligibilityStatuses: introEligibilityStatuses)
                case .unavailable:
                    unavailableContent
                case .inTrial:
                    // 更新されるとは書かない。トライアルの途中で更新を止めた利用者も、期間が終わるまではトライアル中のままのため。
                    stateContent(title: "トライアル中です", guide: "いまは無料で試している期間です")
                case .purchased:
                    stateContent(title: "購入済みです", guide: "ご購入ありがとうございます")
                }
            }
            .background(doquizBackgroundColor)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: "閉じる")
                    }
                    .tint(doquizAccentColor)
                    .accessibilityIdentifier("purchase_close_button")
                }
            }
        }
        .task {
            await load()
        }
    }

    /// 購入していない利用者に出す中身。見出し・商品の行・購入のボタン・復元の入口を出す。
    private func packagesContent(packages: [Package], introEligibilityStatuses: [Package: IntroEligibilityStatus]) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(verbatim: "読んだ直後に確かめる")
                        .font(.title.bold())
                        .foregroundStyle(doquizTextColor)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "読んだ範囲からクイズを作ります")
                        Text(verbatim: "本文をサーバーに送りません")
                        Text(verbatim: "履歴でいつでも答え直せます")
                    }
                    .font(.subheadline)
                    .foregroundStyle(doquizTextColor)
                    VStack(spacing: 10) {
                        ForEach(packages, id: \.identifier) { package in
                            Button {
                                selectedPackage = package
                            } label: {
                                packageRow(
                                    package: package,
                                    introEligibilityStatus: introEligibilityStatuses[package],
                                    isSelected: package == selectedPackage
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("purchase_package_row")
                            .accessibilityAddTraits(package == selectedPackage ? .isSelected : [])
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            if let selectedPackage {
                purchaseActions(package: selectedPackage, introEligibilityStatus: introEligibilityStatuses[selectedPackage])
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    /// 商品 1 つ分の、選べる行。名前・説明・値段を出し、選んでいる行は枠と地の色を変える。
    private func packageRow(package: Package, introEligibilityStatus: IntroEligibilityStatus?, isSelected: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: purchasePlanName(package: package))
                    .font(.headline)
                    .foregroundStyle(doquizTextColor)
                Text(verbatim: purchasePlanDescription(package: package, introEligibilityStatus: introEligibilityStatus))
                    .font(.footnote)
                    .foregroundStyle(doquizSecondaryTextColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(verbatim: package.storeProduct.localizedPriceString)
                .font(.title3.bold())
                .foregroundStyle(doquizTextColor)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? doquizAccentColor.opacity(0.08) : doquizBackgroundColor, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? doquizAccentColor : doquizBorderColor, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 選んでいる商品 `package` の購入のボタンと、自動で更新されることの説明と、復元の入口。
    private func purchaseActions(package: Package, introEligibilityStatus: IntroEligibilityStatus?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let failureMessage {
                Text(verbatim: failureMessage)
                    .font(.footnote)
                    .foregroundStyle(doquizIncorrectColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("purchase_failure_message")
            }
            Button {
                Task {
                    await purchase(package: package)
                }
            } label: {
                Text(verbatim: purchaseButtonTitle(package: package, introEligibilityStatus: introEligibilityStatus))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(doquizAccentColor, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isProcessing)
            .accessibilityIdentifier("purchase_button")
            if let renewalNote = purchaseRenewalNote(package: package, introEligibilityStatus: introEligibilityStatus) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: renewalNote)
                        .accessibilityIdentifier("purchase_renewal_note")
                    Text(verbatim: "いつでも解約できます")
                }
                .font(.caption)
                .foregroundStyle(doquizSecondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
            }
            restoreButton
        }
    }

    /// 購入を復元する入口。
    private var restoreButton: some View {
        Button {
            Task {
                await restore()
            }
        } label: {
            Text(verbatim: "購入を復元する")
                .font(.footnote)
                .foregroundStyle(doquizAccentColor)
                .frame(minHeight: 44)
        }
        .disabled(isProcessing)
        .accessibilityIdentifier("purchase_restore_button")
    }

    /// 商品か購入の状態を取得できなかった時の中身。値段を出さず、取得し直す入口と復元の入口を出す。
    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(verbatim: "いまは購入できません")
                .font(.title.bold())
                .foregroundStyle(doquizTextColor)
            Text(verbatim: "商品の情報を取得できませんでした\n通信の状態を確かめて もう一度お試しください")
                .font(.subheadline)
                .foregroundStyle(doquizSecondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("purchase_unavailable_guide")
            if let failureMessage {
                Text(verbatim: failureMessage)
                    .font(.footnote)
                    .foregroundStyle(doquizIncorrectColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("purchase_failure_message")
            }
            Button {
                Task {
                    await load()
                }
            } label: {
                Text(verbatim: "もう一度取得する")
                    .font(.headline)
                    .foregroundStyle(doquizAccentColor)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizAccentColor, lineWidth: 1.5))
            }
            .disabled(isProcessing)
            .accessibilityIdentifier("purchase_retry_button")
            restoreButton
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
    }

    /// トライアル中か購入済みの利用者に出す中身。状態の見出し `title` と説明 `guide` を出し、商品は出さない。
    private func stateContent(title: String, guide: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title)
                .font(.title.bold())
                .foregroundStyle(doquizTextColor)
                .accessibilityIdentifier("purchase_state_title")
            Text(verbatim: guide)
                .font(.subheadline)
                .foregroundStyle(doquizSecondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
    }

    /// 購入の状態と商品を取得し直して、画面の中身を入れ替える。商品を出す時は、並びの最初の商品を選んだ状態にする。
    private func load() async {
        content = .loading
        failureMessage = nil
        content = await loadPurchaseContent(purchaseService: purchaseService)
        if case .packages(let packages, _) = content {
            selectedPackage = packages.first
        } else {
            selectedPackage = nil
        }
    }

    /// `package` を購入し、購入できた時は画面の中身を購入の後の状態に入れ替える。
    ///
    /// 利用者が取り消した時 (状態が購入していないまま) は、画面を変えない。失敗した時は、失敗したことを出す。
    private func purchase(package: Package) async {
        isProcessing = true
        failureMessage = nil
        defer { isProcessing = false }
        let result = await purchaseOperationResult { try await purchaseService.purchase(package: package) }
        failureMessage = purchaseFailureMessage(result: result)
        showStateContent(result: result)
    }

    /// 購入を復元し、復元できた時は画面の中身を復元の後の状態に入れ替える。
    ///
    /// 復元できる購入が無かった時と失敗した時は、その旨を出す。
    private func restore() async {
        isProcessing = true
        failureMessage = nil
        defer { isProcessing = false }
        let result = await purchaseOperationResult { try await purchaseService.restore() }
        failureMessage = restoreFailureMessage(result: result)
        showStateContent(result: result)
    }

    /// 購入か復元の結果 `result` がトライアル中か購入済みになった時だけ、画面の中身をその状態の中身に入れ替える。
    private func showStateContent(result: PurchaseOperationResult) {
        guard case .stateChanged(let purchaseState) = result else {
            return
        }
        content = purchaseContent(purchaseState: purchaseState, packages: [], introEligibilityStatuses: [:])
    }
}

#if DEBUG
    #Preview("商品を出す") {
        PurchaseView(purchaseService: makeDeveloperMenuFakePurchaseService(behavior: .returnsPackages))
    }

    #Preview("商品を取得できない") {
        PurchaseView(purchaseService: makeDeveloperMenuFakePurchaseService(behavior: .failsToGetPackages))
    }
#endif
