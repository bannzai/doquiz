import Foundation
import Testing

@testable import Doquiz

/// 購入の画面から開く法務の文書の、入口の名前と公開ページの URL を確かめる。
struct LegalDocumentTests {
    /// 入口は利用規約とプライバシーポリシーの 2 つで、この順に並ぶ。
    @Test func 入口は利用規約とプライバシーポリシーの順に2つある() {
        #expect(LegalDocument.allCases == [.termsOfUse, .privacyPolicy])
    }

    /// 利用規約の入口は「利用規約」の名前で、公開済みの利用規約のページを開く。
    @Test func 利用規約の入口は公開済みの利用規約のページを開く() {
        #expect(legalDocumentTitle(legalDocument: .termsOfUse) == "利用規約")
        #expect(legalDocumentURL(legalDocument: .termsOfUse).absoluteString == "https://bannzai.github.io/doquiz/Terms-ja.html")
    }

    /// プライバシーポリシーの入口は「プライバシーポリシー」の名前で、公開済みのプライバシーポリシーのページを開く。
    @Test func プライバシーポリシーの入口は公開済みのプライバシーポリシーのページを開く() {
        #expect(legalDocumentTitle(legalDocument: .privacyPolicy) == "プライバシーポリシー")
        #expect(
            legalDocumentURL(legalDocument: .privacyPolicy).absoluteString == "https://bannzai.github.io/doquiz/PrivacyPolicy-ja.html"
        )
    }
}
