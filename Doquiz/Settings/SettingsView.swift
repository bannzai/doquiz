import SwiftUI

/// 設定の画面。購入の画面への入口と、利用規約・プライバシーポリシー・特定商取引法に基づく表記を開く行、問い合わせのメールを書く行を出す。
/// ホーム (本を選ぶ画面) の左上の歯車から開く。
///
/// 購入の画面への入口は、購入の状態と無料の回数にかかわらず出す (owner の決定「購入の画面を出すのは、設定に導線一つ」
/// https://github.com/bannzai/doquiz/issues/20#issuecomment-6997715595 )。
struct SettingsView: View {
    /// 出している購入の画面。出していない間は nil。
    /// 入口を押すたびに購入の境界を 1 回だけ作って持ち、画面を出している間は同じものを使う (理由は本の一覧の同じ値に書く)。
    @State private var presentedPurchase: PresentedPurchase?
    /// 購入の画面で使う購入の境界の作り方。
    private var purchaseServiceSource = PurchaseServiceSource()

    var body: some View {
        List {
            Section {
                Button {
                    presentedPurchase = PresentedPurchase(id: UUID(), purchaseService: purchaseServiceSource.makePurchaseService())
                } label: {
                    settingsRowLabel(title: "購入のプランを見る", systemImage: "chevron.right")
                }
                .accessibilityIdentifier("settings_purchase_entrance")
            } header: {
                Text(verbatim: "購入")
            }
            Section {
                ForEach(LegalDocument.allCases, id: \.self) { legalDocument in
                    Link(destination: legalDocumentURL(legalDocument: legalDocument)) {
                        settingsRowLabel(title: legalDocumentTitle(legalDocument: legalDocument), systemImage: "arrow.up.right")
                    }
                    .accessibilityIdentifier(settingsLegalDocumentAccessibilityIdentifier(legalDocument: legalDocument))
                }
                Link(destination: specifiedCommercialTransactionActURL) {
                    settingsRowLabel(title: "特定商取引法に基づく表記", systemImage: "arrow.up.right")
                }
                .accessibilityIdentifier("settings_specified_commercial_transaction_act_link")
            } header: {
                Text(verbatim: "このアプリについて")
            } footer: {
                Text(verbatim: "お問い合わせは \(contactMailAddress) へのメールで受け付けています")
            }
        }
        .scrollContentBackground(.hidden)
        .background(doquizBackgroundColor)
        .navigationTitle(Text(verbatim: "設定"))
        .navigationBarTitleDisplayMode(.inline)
        // 出す購入の画面を item で渡す理由は、本の一覧の同じ sheet に書く。
        .sheet(item: $presentedPurchase) { presentedPurchase in
            PurchaseView(purchaseService: presentedPurchase.purchaseService)
        }
    }

    /// 設定の画面の 1 行の見た目。左に `title`、右に行を押すと何が起きるかを表す記号 `systemImage` を出す。
    private func settingsRowLabel(title: String, systemImage: String) -> some View {
        HStack {
            Text(verbatim: title)
                .foregroundStyle(doquizTextColor)
            Spacer()
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(doquizSecondaryTextColor)
                .accessibilityHidden(true)
        }
    }
}

/// 設定の画面で、文書 `legalDocument` を開く行の accessibility identifier を返す。
func settingsLegalDocumentAccessibilityIdentifier(legalDocument: LegalDocument) -> String {
    switch legalDocument {
    case .termsOfUse:
        "settings_terms_of_use_link"
    case .privacyPolicy:
        "settings_privacy_policy_link"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
