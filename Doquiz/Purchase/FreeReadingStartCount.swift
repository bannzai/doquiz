import Observation

/// これまでに無料で始めた読書の回数と、その保存先。アプリの入口で 1 つだけ作り、画面には environment で渡す。
///
/// 画面ごとに保存先から読み直さず 1 か所に持つのは、本の画面で回数を増やした時に、ホームの残りの回数と開発者メニューの表示を同じ値で描き直すため。
@Observable
final class FreeReadingStartCount {
    /// 保存先から読んだ回数。読み出せなかった時は nil (回数が分からない間は、0 回として扱わない)。
    private(set) var count: Int?
    /// 回数の保存先。
    private let store: FreeReadingStartCountStore

    /// 保存先 `store` から回数を読んで作る。読み出せなかった時は回数を nil にする (読み出しに失敗しても、アプリは起動できるようにするため)。
    init(store: FreeReadingStartCountStore) {
        self.store = store
        count = try? store.load()
    }

    /// 回数を返す。起動した時に読み出せていなかった時は、保存先からもう一度読み出す。読み出せない時は保存先の error を投げる。
    func loadedCount() throws -> Int {
        if let count {
            return count
        }
        let loadedCount = try store.load()
        count = loadedCount
        return loadedCount
    }

    /// 回数を 1 増やして保存する。保存できない時は error を投げ、回数を変えない。回数が分からない時は `FreeReadingStartCountUnavailableError` を投げる。
    ///
    /// 冪等ではない: 呼ぶたびに回数が 1 増える。
    func increment() throws {
        guard let count else {
            throw FreeReadingStartCountUnavailableError()
        }
        try store.save(count + 1)
        self.count = count + 1
    }

    /// 回数を `newCount` にして保存する。開発者メニューで境界の状態を作るために使う。保存できない時は error を投げ、回数を変えない。
    func replace(newCount: Int) throws {
        try store.save(newCount)
        count = newCount
    }
}

/// 無料で始めた読書の回数を保存先から読み出せず、回数が分からないことを表す error。
struct FreeReadingStartCountUnavailableError: Error {}
