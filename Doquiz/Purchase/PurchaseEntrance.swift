/// ホーム (本を選ぶ画面) に、購入の画面への入口と無料で始められる読書の残りを出すかを返す。
///
/// 利用者が読書を始めたことがあり、最後に確かめた購入の状態 `purchaseState` がトライアル中でも購入済みでもない時に出す。
/// - 読書を始めたことがあるかは、どれかの本 (`books` は登録済みの本) に読書の記録が 1 件でもあるか、無料で始めた読書の回数
///   `freeReadingStartCount` が 1 以上かで決め、別に保存しない (読書の記録を全部消した後も、無料の回数を使ったことがあれば出す)
/// - トライアル中と購入済みの利用者には出さない (無料の回数が関係せず、購入の画面へ案内する理由も無いため。購入の画面へは設定の画面から行ける)
/// - 購入の状態をまだ確かめていない時 (`purchaseState` が nil) は出さない (購入済みの利用者に、確かめ終わるまでの間だけ入口を出さないため)。
///   確かめて取得できなかった時は、呼び出す側が購入していないとして渡す (`countsAsFreeReadingStart` と同じ扱い)
func showsPurchaseEntrance(books: [Book], freeReadingStartCount: Int, purchaseState: PurchaseState?) -> Bool {
    return books.contains { !$0.readingSessions.isEmpty }
}
