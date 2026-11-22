import Testing

@testable import Doquiz

/// 開発者メニューの、無料で始めた読書の回数の切り替えの順を確かめる。
struct DeveloperMenuFreeReadingTests {
    /// 0 回 → 19 回 → 20 回 → 0 回 の順に切り替わり、それ以外の回数 (1 回・21 回) からは 0 回に戻る。
    @Test(arguments: [(0, 19), (19, 20), (20, 0), (1, 0), (21, 0)])
    func 無料で始めた読書の回数は0回19回20回の順に切り替わる(freeReadingStartCount: Int, expectedNextCount: Int) {
        #expect(nextDeveloperMenuFreeReadingStartCount(freeReadingStartCount: freeReadingStartCount) == expectedNextCount)
    }
}
