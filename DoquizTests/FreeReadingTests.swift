import Testing

@testable import Doquiz

/// 無料で始められる読書の回数の判定と、ホームに出す残りの文を確かめる。
struct FreeReadingTests {
    /// 購入していない利用者は、無料で始めた回数が 0 回から 19 回の間は読書を始められ、その読書を無料の回数に数える。
    @Test(arguments: [0, 1, 19])
    func 購入していない時は20回目までは始められて数える(freeReadingStartCount: Int) throws {
        #expect(try countsAsFreeReadingStart(purchaseState: .notPurchased, freeReadingStartCount: freeReadingStartCount))
    }

    /// 購入していない利用者は、無料で 20 回始めた後 (21 回目) から先は読書を始められない。
    @Test(arguments: [20, 21, 100])
    func 購入していない時は21回目から始められない(freeReadingStartCount: Int) {
        #expect(throws: FreeReadingsUsedUpError.self) {
            try countsAsFreeReadingStart(purchaseState: .notPurchased, freeReadingStartCount: freeReadingStartCount)
        }
    }

    /// トライアル中と購入済みの利用者は、無料の回数を使っていても使い切っていても読書を始められ、その読書を数えない。
    @Test(arguments: [PurchaseState.inTrial, .purchased], [0, 19, 20, 21])
    func トライアル中と購入済みの時は回数にかかわらず始められて数えない(purchaseState: PurchaseState, freeReadingStartCount: Int) throws {
        #expect(try countsAsFreeReadingStart(purchaseState: purchaseState, freeReadingStartCount: freeReadingStartCount) == false)
    }

    /// 残りの回数は、20 回から無料で始めた回数を引いた数で、使い切った後は 0 回になる。
    @Test(arguments: [(0, 20), (1, 19), (19, 1), (20, 0), (21, 0)])
    func 残りの回数は20回から始めた回数を引いた数で0回より減らない(freeReadingStartCount: Int, expectedRemainingCount: Int) {
        #expect(remainingFreeReadingStartCount(freeReadingStartCount: freeReadingStartCount) == expectedRemainingCount)
    }

    /// 購入の状態を確かめ直す時は、前に出した購入の画面の境界を、作り方の種類が同じ時だけ使い回し、
    /// 開発者メニューで偽の購入の動きを変えた後 (種類が違う時) は使い回さない。
    @Test(arguments: [
        ("real", "real", true),
        ("returnsPackages", "returnsPackages", true),
        ("returnsPackages", "inTrial", false),
        ("returnsPackages", "real", false),
    ])
    func 購入の画面の境界は作り方の種類が同じ時だけ使い回す(purchaseSheetKindID: String, currentKindID: String, expectedReuses: Bool) {
        #expect(reusesPurchaseSheetPurchaseService(purchaseSheetKindID: purchaseSheetKindID, currentKindID: currentKindID) == expectedReuses)
    }

    /// ホームに出す残りの文は、残りがある間は残りの回数を、使い切った後は使い切ったことを伝える。
    @Test(arguments: [
        (0, "無料で始められる読書 あと 20 回"),
        (19, "無料で始められる読書 あと 1 回"),
        (20, "無料で始められる読書を使い切りました"),
        (21, "無料で始められる読書を使い切りました"),
    ])
    func ホームに出す残りの文は残りの回数を伝える(freeReadingStartCount: Int, expectedText: String) {
        #expect(freeReadingRemainingText(freeReadingStartCount: freeReadingStartCount) == expectedText)
    }
}
