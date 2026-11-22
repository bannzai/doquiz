/// ホーム (本を選ぶ画面) に、購入の画面への入口と無料で始められる読書の残りを出すかを返す。
///
/// 利用者が読書を始めたことがあり、最後に確かめた購入の状態 `purchaseState` が購入していない時に出す。
/// - 読書を始めたことがあるかは、どれかの本 (`books` は登録済みの本) に読書の記録が 1 件でもあるかで決め、別に保存しない
///   (`documents/DIRECTION.md`「決めたこと」の 2026-11-20 の行。読書の記録を全部消した後は、次の読書を始めるまで出ない)
/// - トライアル中と購入済みの利用者には出さない (無料の回数が関係せず、購入の画面へ案内する理由も無いため。購入の画面へは設定の画面から行ける)
/// - 購入の状態をまだ確かめていない時と、確かめて取得できなかった時 (`purchaseState` が nil) は出さない
///   (購入しているかが分からない利用者に、購入していない前提の入口と残りの回数を出さないため)
func showsPurchaseEntrance(books: [Book], purchaseState: PurchaseState?) -> Bool {
    purchaseState == .notPurchased && books.contains { !$0.readingSessions.isEmpty }
}
