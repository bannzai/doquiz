#if DEBUG
    /// 開発者メニューで、無料で始めた読書の回数を切り替えた次の回数を返す。`freeReadingStartCount` は今の回数。
    ///
    /// 0 回 → 19 回 → 20 回 → 0 回 の順に回す。19 回は次の 1 回で使い切る境界、20 回は使い切った後で、
    /// どちらも 20 回の読書を実際に始めずに作るため。この 3 つ以外の回数の時は 0 回に戻す。
    func nextDeveloperMenuFreeReadingStartCount(freeReadingStartCount: Int) -> Int {
        switch freeReadingStartCount {
        case 0:
            freeReadingStartLimit - 1
        case freeReadingStartLimit - 1:
            freeReadingStartLimit
        case freeReadingStartLimit:
            freeReadingStartLimit + 1
        default:
            0
        }
    }
#endif
