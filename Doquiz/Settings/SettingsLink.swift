import Foundation

/// 特定商取引法に基づく表記の公開ページの URL。設定の画面から開く。
///
/// 公開ページは `docs/` を GitHub Pages で出したもので、`docs/SpecifiedCommercialTransactionAct-ja.md` に当たる
/// (利用規約とプライバシーポリシーの URL は `legalDocumentURL` が持つ)。
let specifiedCommercialTransactionActURL = URL(string: "https://bannzai.github.io/doquiz/SpecifiedCommercialTransactionAct.html")!

/// 問い合わせ先のメールアドレス。公開の 3 つの文書と紹介のページ (`docs/index.html`) に載せているアドレスと同じ。
let contactMailAddress = "bannzai.app@gmail.com"

/// 問い合わせのメールを書く画面を開く URL を返す。宛先は `contactMailAddress`。
func contactMailURL() -> URL {
    URL(string: "mailto:\(contactMailAddress)")!
}
