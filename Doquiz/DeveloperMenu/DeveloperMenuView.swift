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

    /// 開発者メニュー。実機で本を読まないと作れない状態 (読書の記録や回答がある状態) を作る操作、保存データを全部消す操作、
    /// 読書を偽の取り込みに切り替える操作を置く。
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
        /// 読書を偽の取り込みと偽の本文の抽出に切り替えているか。本の画面が読書を始める時に同じ値を読む。
        /// 既定を false にしているのは、切り替えていない開発用のビルドでは実物を使うため。
        @AppStorage(developerMenuUsesFakeReadingKey) private var usesFakeReading = false

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
                        failureDescription = developerMenuFailureDescription(operation: {
                            try replaceDeveloperMenuSampleData(modelContext: modelContext)
                        })
                    } label: {
                        Text(verbatim: "見本のデータを入れる")
                    }
                    .accessibilityIdentifier("developer_menu_replace_sample_data")
                    Button(role: .destructive) {
                        failureDescription = developerMenuFailureDescription(operation: {
                            try deleteAllSavedData(modelContext: modelContext)
                        })
                    } label: {
                        Text(verbatim: "保存データを全部消す")
                    }
                    .accessibilityIdentifier("developer_menu_delete_all_saved_data")
                } header: {
                    Text(verbatim: "保存データの操作")
                }
                Section {
                    Button {
                        usesFakeReading.toggle()
                    } label: {
                        Text(verbatim: "読書の取り込みを 偽物と実物で切り替える")
                    }
                    .accessibilityIdentifier("developer_menu_toggle_fake_reading")
                    HStack {
                        Text(verbatim: "偽の取り込みを使う")
                        Spacer()
                        Text(verbatim: usesFakeReading ? "オン" : "オフ")
                            .accessibilityIdentifier("developer_menu_uses_fake_reading_state")
                    }
                } header: {
                    Text(verbatim: "読書")
                } footer: {
                    Text(verbatim: "オンの間は 画面共有の選択画面を出さずに 決まった本文のページが取り込まれる")
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
    }

    /// 開発者メニューの操作を実行し、画面に出す失敗の内容を返す。
    ///
    /// 操作がエラーを投げた時はそのエラーの内容を返し、成功した時は nil を返す。
    /// 画面は返り値をそのまま失敗の表示に入れるため、成功すると前の失敗の表示が消える。
    func developerMenuFailureDescription(operation: () throws -> Void) -> String? {
        do {
            try operation()
            return nil
        } catch {
            return String(describing: error)
        }
    }
#endif
