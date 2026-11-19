#if DEBUG
    import Testing
    @testable import Doquiz

    /// テストの中で、開発者メニューの操作にわざと投げさせるエラー。
    private enum SampleOperationError: Error {
        /// 保存に失敗したことを表す。
        case savingFailed
    }

    /// 開発者メニューが、操作の失敗を画面に出す内容に変える処理を確かめる。
    struct DeveloperMenuFailureDescriptionTests {
        /// 操作がエラーを投げた時に、そのエラーの内容が画面に出す内容として返ることを確かめる。
        @Test func 操作が失敗するとエラーの内容を返す() {
            #expect(
                developerMenuFailureDescription(operation: { throw SampleOperationError.savingFailed })
                    == "savingFailed"
            )
        }

        /// 操作が成功した時に nil が返り、画面に出ていた前の失敗の表示が消える値になることを確かめる。
        @Test func 操作が成功すると失敗の内容は無い() {
            #expect(developerMenuFailureDescription(operation: {}) == nil)
        }

        /// 操作が成功した時に、渡した操作が 1 回だけ実行されていることを確かめる。
        @Test func 渡した操作を1回だけ実行する() {
            var executedCount = 0

            _ = developerMenuFailureDescription(operation: { executedCount += 1 })

            #expect(executedCount == 1)
        }
    }
#endif
