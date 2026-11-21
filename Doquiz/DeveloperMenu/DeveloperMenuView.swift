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
    /// 読書を偽の取り込みに切り替える操作、読書を終えた後のクイズを偽のクイズに切り替える操作、端末内のモデルが使えるかを偽の値に切り替える操作、
    /// 購入の画面を偽の購入に切り替える操作、無料で始めた読書の回数を切り替える操作を置く。
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
        /// 偽の取り込みを、画像を流し切った後に途中で止めるか。本の画面が読書を始める時に同じ値を読む。
        /// 既定を false にしているのは、切り替えていない時の偽の取り込みを「読書を終える」まで続けるため。
        @AppStorage(developerMenuInterruptsFakeReadingKey) private var interruptsFakeReading = false
        /// 読書を終えた後のクイズを、偽のクイズに切り替えている時の動き。本の画面がクイズを出す時に同じ値を読む。
        /// 値が無い時 (切り替えていない時) は、実物 (端末内のモデル) でクイズを作る。
        @AppStorage(developerMenuFakeQuizBehaviorKey) private var fakeQuizBehavior: DeveloperMenuFakeQuizBehavior?
        /// 端末内のモデルが使えるかの確かめ方。アプリの入口の画面 (`ContentView`) が同じ値を読む。
        /// 既定を `.real` にしているのは、切り替えていない開発用のビルドでは実物で確かめるため。
        @AppStorage(developerMenuQuizAvailabilityKey) private var quizAvailability = DeveloperMenuQuizAvailability.real
        /// 購入の画面を、偽の購入に切り替えている時の動き。本の一覧が購入の画面を出す時に同じ値を読む。
        /// 値が無い時 (切り替えていない時) は、実物 (RevenueCat の SDK) で購入する。
        @AppStorage(developerMenuFakePurchaseBehaviorKey) private var fakePurchaseBehavior: DeveloperMenuFakePurchaseBehavior?
        /// これまでに無料で始めた読書の回数。本の一覧と本の画面が同じ値を読む。
        /// 既定を 0 にしているのは、保存した値が無い利用者は、まだ無料の読書を 1 回も始めていないため (本の一覧と同じ)。
        @AppStorage(freeReadingStartCountKey) private var freeReadingStartCount = 0

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
                    Button {
                        interruptsFakeReading.toggle()
                    } label: {
                        Text(verbatim: "偽の取り込みを 途中で止めるかを切り替える")
                    }
                    .accessibilityIdentifier("developer_menu_toggle_interrupts_fake_reading")
                    HStack {
                        Text(verbatim: "偽の取り込みを途中で止める")
                        Spacer()
                        Text(verbatim: interruptsFakeReading ? "オン" : "オフ")
                            .accessibilityIdentifier("developer_menu_interrupts_fake_reading_state")
                    }
                } header: {
                    Text(verbatim: "読書")
                } footer: {
                    Text(verbatim: "オンの間は 画面共有の選択画面を出さずに 決まった本文のページが取り込まれる")
                }
                Section {
                    Button {
                        fakeQuizBehavior = nextDeveloperMenuFakeQuizBehavior(behavior: fakeQuizBehavior)
                    } label: {
                        Text(verbatim: "クイズを 実物と偽物の動きで順に切り替える")
                    }
                    .accessibilityIdentifier("developer_menu_cycle_fake_quiz_behavior")
                    HStack {
                        Text(verbatim: "クイズの動き")
                        Spacer()
                        Text(verbatim: developerMenuFakeQuizBehaviorLabel(behavior: fakeQuizBehavior))
                            .accessibilityIdentifier("developer_menu_fake_quiz_behavior_state")
                    }
                } header: {
                    Text(verbatim: "クイズ")
                } footer: {
                    Text(verbatim: "実物以外の間は 端末内のモデルを呼ばずに 決まった問いと判定が返る")
                }
                // 上の section の下に置いているのは、上の行の位置を変えず、既存の UI テストの画面の送り方を変えないため。
                Section {
                    ForEach(DeveloperMenuQuizAvailability.allCases, id: \.self) { selectableQuizAvailability in
                        Button {
                            quizAvailability = selectableQuizAvailability
                        } label: {
                            HStack {
                                Text(verbatim: developerMenuQuizAvailabilityTitle(developerMenuQuizAvailability: selectableQuizAvailability))
                                Spacer()
                                if quizAvailability == selectableQuizAvailability {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .accessibilityAddTraits(quizAvailability == selectableQuizAvailability ? .isSelected : [])
                        .accessibilityIdentifier("developer_menu_quiz_availability_\(selectableQuizAvailability.rawValue)")
                    }
                } header: {
                    Text(verbatim: "端末内のモデルが使えるか")
                } footer: {
                    Text(verbatim: "使えないことにすると 本の一覧と本の画面に案内が出て 読書を始められなくなる\n切り替えは 実機で設定を変えた時と同じく ホーム画面へ出て戻った時に効く (使えない間は 5 秒ごとにも確かめ直す)")
                }
                // 端末内のモデルの section の下に置いているのは、上の行の位置を変えず、既存の UI テストの画面の送り方を変えないため。
                Section {
                    Button {
                        fakePurchaseBehavior = nextDeveloperMenuFakePurchaseBehavior(behavior: fakePurchaseBehavior)
                    } label: {
                        Text(verbatim: "購入を 実物と偽物の動きで順に切り替える")
                    }
                    .accessibilityIdentifier("developer_menu_cycle_fake_purchase_behavior")
                    HStack {
                        Text(verbatim: "購入の動き")
                        Spacer()
                        Text(verbatim: developerMenuFakePurchaseBehaviorLabel(behavior: fakePurchaseBehavior))
                            .accessibilityIdentifier("developer_menu_fake_purchase_behavior_state")
                    }
                } header: {
                    Text(verbatim: "購入")
                } footer: {
                    Text(verbatim: "実物以外の間は RevenueCat と App Store を呼ばずに 決まった商品と購入の状態が返る")
                }
                // 購入の section の下に置いているのは、上の行の位置を変えず、既存の UI テストの画面の送り方を変えないため。
                Section {
                    Button {
                        freeReadingStartCount = nextDeveloperMenuFreeReadingStartCount(freeReadingStartCount: freeReadingStartCount)
                    } label: {
                        Text(verbatim: "無料で始めた読書の回数を 0 回 19 回 20 回の順に切り替える")
                    }
                    .accessibilityIdentifier("developer_menu_cycle_free_reading_start_count")
                    HStack {
                        Text(verbatim: "無料で始めた読書の回数")
                        Spacer()
                        Text(verbatim: "\(freeReadingStartCount) 回")
                            .accessibilityIdentifier("developer_menu_free_reading_start_count_state")
                    }
                } header: {
                    Text(verbatim: "無料の回数")
                } footer: {
                    Text(verbatim: "19 回にすると次の 1 回で使い切り 20 回にすると次の「読書を始める」で購入の画面が出る\n保存データを全部消しても この回数は戻らない")
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
