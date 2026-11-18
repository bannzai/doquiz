#if DEBUG
    import SwiftData
    import SwiftUI

    /// 開発者メニューを開くボタン。画面の toolbar に置く。開発用のビルド (DEBUG) だけに入る。
    struct DeveloperMenuEntrance: View {
        var body: some View {
            NavigationLink {
                DeveloperMenuView()
            } label: {
                Image(systemName: "wrench.and.screwdriver")
            }
            .accessibilityLabel(Text(verbatim: "開発者メニュー"))
            .accessibilityIdentifier("developer_menu_entrance")
        }
    }

    /// 開発者メニュー。実機で本を読まないと作れない状態 (読書の記録や回答がある状態) を作る操作と、保存データを全部消す操作を置く。
    ///
    /// 開発用のビルド (DEBUG) だけに入り、公開用のビルドには入らない。
    /// 操作の結果を画面と UI テストから確かめられるよう、5 つの型の保存データの件数を出す。
    struct DeveloperMenuView: View {
        /// 保存データの操作に使う、アプリの保存先の context。
        @Environment(\.modelContext) private var modelContext
        /// 保存されている本。件数の表示に使う。
        @Query private var books: [Book]
        /// 保存されている読書の記録。件数の表示に使う。
        @Query private var readingSessions: [ReadingSession]
        /// 保存されているページ。件数の表示に使う。
        @Query private var capturedPages: [CapturedPage]
        /// 保存されている問い。件数の表示に使う。
        @Query private var questions: [Question]
        /// 保存されている回答。件数の表示に使う。
        @Query private var answers: [Answer]
        /// 最後に実行した操作が失敗した時のエラーの内容。失敗していなければ nil。
        @State private var failureDescription: String?

        var body: some View {
            List {
                Section {
                    countRow(title: "本", count: books.count, accessibilityIdentifier: "developer_menu_book_count")
                    countRow(
                        title: "読書の記録",
                        count: readingSessions.count,
                        accessibilityIdentifier: "developer_menu_reading_session_count"
                    )
                    countRow(
                        title: "ページ",
                        count: capturedPages.count,
                        accessibilityIdentifier: "developer_menu_captured_page_count"
                    )
                    countRow(
                        title: "問い",
                        count: questions.count,
                        accessibilityIdentifier: "developer_menu_question_count"
                    )
                    countRow(title: "回答", count: answers.count, accessibilityIdentifier: "developer_menu_answer_count")
                } header: {
                    Text(verbatim: "保存データの件数")
                }
                Section {
                    Button {
                        perform(operation: { try replaceDeveloperMenuSampleData(modelContext: modelContext) })
                    } label: {
                        Text(verbatim: "見本のデータを入れる")
                    }
                    .accessibilityIdentifier("developer_menu_replace_sample_data")
                    Button(role: .destructive) {
                        perform(operation: { try deleteAllSavedData(modelContext: modelContext) })
                    } label: {
                        Text(verbatim: "保存データを全部消す")
                    }
                    .accessibilityIdentifier("developer_menu_delete_all_saved_data")
                } header: {
                    Text(verbatim: "保存データの操作")
                }
                if let failureDescription {
                    Section {
                        Text(verbatim: failureDescription)
                            .accessibilityIdentifier("developer_menu_failure_description")
                    } header: {
                        Text(verbatim: "失敗した操作のエラー")
                    }
                }
            }
            .navigationTitle(Text(verbatim: "開発者メニュー"))
        }

        /// 保存データの件数の 1 行。
        private func countRow(title: String, count: Int, accessibilityIdentifier: String) -> some View {
            HStack {
                Text(verbatim: title)
                Spacer()
                Text(verbatim: String(count))
                    .accessibilityIdentifier(accessibilityIdentifier)
            }
        }

        /// 保存データの操作を実行し、失敗した時はエラーの内容を画面に出す。成功した時は前の失敗の表示を消す。
        private func perform(operation: () throws -> Void) {
            do {
                try operation()
                failureDescription = nil
            } catch {
                failureDescription = String(describing: error)
            }
        }
    }
#endif
