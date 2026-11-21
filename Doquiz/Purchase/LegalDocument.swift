import Foundation

/// 購入の画面から開く、公開済みの法務の文書。文書の中身はアプリに持たず、公開ページを開く。
enum LegalDocument: CaseIterable {
    /// 利用規約。
    case termsOfUse
    /// プライバシーポリシー。
    case privacyPolicy
}

/// 文書 `legalDocument` の入口に出す名前を返す。
func legalDocumentTitle(legalDocument: LegalDocument) -> String {
    switch legalDocument {
    case .termsOfUse:
        "利用規約"
    case .privacyPolicy:
        "プライバシーポリシー"
    }
}

/// 文書 `legalDocument` の公開ページの URL を返す。
///
/// 公開ページは `docs/` を GitHub Pages で出したもので、`docs/Terms-ja.md` と `docs/PrivacyPolicy-ja.md` に当たる。
func legalDocumentURL(legalDocument: LegalDocument) -> URL {
    switch legalDocument {
    case .termsOfUse:
        URL(string: "https://bannzai.github.io/doquiz/Terms-en.html")!
    case .privacyPolicy:
        URL(string: "https://bannzai.github.io/doquiz/PrivacyPolicy-en.html")!
    }
}

/// 文書 `legalDocument` の入口の accessibility identifier を返す。
func legalDocumentAccessibilityIdentifier(legalDocument: LegalDocument) -> String {
    switch legalDocument {
    case .termsOfUse:
        "purchase_terms_of_use_link"
    case .privacyPolicy:
        "purchase_privacy_policy_link"
    }
}
