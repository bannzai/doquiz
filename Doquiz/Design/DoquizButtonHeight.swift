import CoreGraphics

// 文字のラベルを持つ操作のボタンの高さ。同じ役割のボタンは、どの画面でも同じ高さにする (`documents/DIRECTION.md`「決めたこと」の 2026-11-29 の行)。
// toolbar・確認の alert・設定の一覧の行のように iOS が高さを決めるボタンと、選択肢・本の行・問いの種類のように選ぶための行は、この高さを使わない。

/// 画面の幅いっぱいに置き、塗りか枠で囲む操作のボタン (「読書を始める」「読書を終える」「同意して始める」「出題の設定を変える」「この本と読書の記録を消す」等) の最小の高さ。
///
/// 以前の 54pt を owner が小さいと指摘したため (https://github.com/bannzai/doquiz/issues/107 )、文字の上下の余白が見て分かるほど増える 60pt にした。
/// 値は、UI テストが撮った変更の前と後の画像を並べて決めた。
let doquizLargeButtonMinHeight: CGFloat = 60

/// 塗りも枠も無い、文字だけの操作のボタン (「やめる」「この本の履歴を見る」「購入のプランを見る」「購入を復元する」等) の最小の高さ。
///
/// 以前の 44pt (Apple の Human Interface Guidelines の押せる範囲の最小) を owner が小さいと指摘したため (https://github.com/bannzai/doquiz/issues/107 )、
/// 押せる範囲を広げつつ、本の画面・同意の説明・購入の画面の下の段に並べても枠のあるボタンより目立たない 48pt にした。
let doquizTextButtonMinHeight: CGFloat = 48
