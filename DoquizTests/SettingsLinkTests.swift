import Foundation
import Testing

@testable import Doquiz

/// 設定の画面の、特定商取引法に基づく表記の行と問い合わせの行が開く先を確かめる。
struct SettingsLinkTests {
    /// 特定商取引法に基づく表記の行は、公開済みの特定商取引法に基づく表記のページを開く。
    @Test func 特定商取引法に基づく表記の行は公開済みのページを開く() {
        #expect(specifiedCommercialTransactionActURL.absoluteString == "https://bannzai.github.io/doquiz/SpecifiedCommercialTransactionAct-ja.html")
    }

    /// 問い合わせの行は、公開の文書と紹介のページに載せているアドレスへのメールを書く画面を開く。
    @Test func 問い合わせの行は公開しているアドレスへのメールを書く画面を開く() {
        #expect(contactMailAddress == "bannzai.app@gmail.com")
        #expect(contactMailURL().absoluteString == "mailto:bannzai.app@gmail.com")
    }

    /// 設定の画面の利用規約とプライバシーポリシーの行は、購入の画面の入口と別の識別子を持つ (UI テストで画面ごとに探すため)。
    @Test func 設定の画面の文書の行は購入の画面の入口と別の識別子を持つ() {
        #expect(settingsLegalDocumentAccessibilityIdentifier(legalDocument: .termsOfUse) == "settings_terms_of_use_link")
        #expect(settingsLegalDocumentAccessibilityIdentifier(legalDocument: .privacyPolicy) == "settings_privacy_policy_link")
    }
}
