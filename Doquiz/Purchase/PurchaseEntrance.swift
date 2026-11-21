/// ホーム (本を選ぶ画面) に、購入の画面への入口を出すかを返す。`books` は登録済みの本。
///
/// 利用者が読書を始めたことがある時 (どれかの本に読書の記録が 1 件でもある時) に出す。
/// 読書を始めたかは保存済みの読書の記録から求め、別に保存しない。
func showsPurchaseEntrance(books: [Book]) -> Bool {
    books.contains { !$0.readingSessions.isEmpty }
}
