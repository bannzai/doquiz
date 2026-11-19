#if DEBUG
    import Testing
    @testable import Doquiz

    /// 開発者メニューの、読書を終えた後のクイズの動きの切り替えを確かめる。
    @MainActor struct DeveloperMenuFakeQuizTests {
        /// 切り替えを押すたびに、実物 → 問いを返す → 問いを返さない → モデルが使えない → 作るのに失敗する → 判定に失敗する → 実物、の順に一巡する。
        @Test func 切り替えは実物から5つの偽の動きを順に回って実物に戻る() {
            #expect(nextDeveloperMenuFakeQuizBehavior(behavior: nil) == .returnsQuestions)
            #expect(nextDeveloperMenuFakeQuizBehavior(behavior: .returnsQuestions) == .returnsNoQuestions)
            #expect(nextDeveloperMenuFakeQuizBehavior(behavior: .returnsNoQuestions) == .modelUnavailable)
            #expect(nextDeveloperMenuFakeQuizBehavior(behavior: .modelUnavailable) == .failsToMakeQuestions)
            #expect(nextDeveloperMenuFakeQuizBehavior(behavior: .failsToMakeQuestions) == .failsToJudge)
            #expect(nextDeveloperMenuFakeQuizBehavior(behavior: .failsToJudge) == nil)
        }

        /// 開発者メニューに出す動きの名前は、切り替えていない時が「実物」で、偽の動きごとに違う名前になる。
        @Test func 動きの名前は実物と5つの偽の動きで全部違う() {
            #expect(developerMenuFakeQuizBehaviorLabel(behavior: nil) == "実物")
            #expect(developerMenuFakeQuizBehaviorLabel(behavior: .returnsQuestions) == "問いを返す")
            #expect(developerMenuFakeQuizBehaviorLabel(behavior: .returnsNoQuestions) == "問いを返さない")
            #expect(developerMenuFakeQuizBehaviorLabel(behavior: .modelUnavailable) == "モデルが使えない")
            #expect(developerMenuFakeQuizBehaviorLabel(behavior: .failsToMakeQuestions) == "作るのに失敗する")
            #expect(developerMenuFakeQuizBehaviorLabel(behavior: .failsToJudge) == "判定に失敗する")
        }
    }
#endif
