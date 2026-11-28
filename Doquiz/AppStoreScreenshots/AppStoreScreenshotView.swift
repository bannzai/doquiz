#if DEBUG
    import SwiftData
    import SwiftUI

    /// App Store のスクリーンショット 1 枚の画面。起動の引数で選んだ `page` を、アプリの画面の代わりに出す。
    ///
    /// アプリの画面は本物の画面の部品をそのまま使い、中身は開発者メニューの見本のデータ (`replaceDeveloperMenuSampleData`) にする。
    /// 見本は、この画面だけが使うメモリ内の保存先に入れるため、端末の保存データに触れない。
    /// キャッチコピーと並びの順は `documents/DIRECTION.md`「決めたこと」の 2026-11-28 の行。中身は紹介のページ (`docs/index.html`) と掲載文 (`fastlane/metadata/ja/`) に書いてある事実だけにする。
    struct AppStoreScreenshotView: View {
        /// 出すスクリーンショット。
        let page: AppStoreScreenshotPage
        /// 見本のデータを入れた、メモリ内の保存先。
        private let modelContainer: ModelContainer
        /// 見本の本のうち、読書の記録と 4 種類の問いがある本。
        private let sampleBook: Book
        /// `sampleBook` の最初の読書の問い。クイズに出る順。
        private let sampleQuestions: [Question]

        /// 見本のデータを入れた保存先を作る。
        ///
        /// 保存先の作成と見本の保存は SwiftData のエラーを投げうるため、手で書いている。開発用のビルドの撮影にしか使わないため、失敗した時はアプリを止める。
        init(page: AppStoreScreenshotPage) {
            self.page = page
            do {
                modelContainer = try makeModelContainer(isStoredInMemoryOnly: true)
                try replaceDeveloperMenuSampleData(modelContext: modelContainer.mainContext)
                // 見本の本のうち、4 種類の問いがあるのは、最初に登録した本 (潮見町の灯台日誌)。
                guard
                    let book = try modelContainer.mainContext.fetch(
                        FetchDescriptor<Book>(sortBy: [SortDescriptor(\.createdDateTime)])
                    ).first,
                    let firstReadingSession = book.readingSessions.min(by: { $0.startedDateTime < $1.startedDateTime })
                else {
                    fatalError("見本のデータに本か読書の記録がありません")
                }
                sampleBook = book
                sampleQuestions = historyQuestions(readingSession: firstReadingSession)
            } catch {
                fatalError("見本のデータを用意できませんでした: \(error)")
            }
        }

        var body: some View {
            Group {
                switch page {
                case .quiz:
                    AppStoreScreenshotCanvas(title: "読み終えたら\nすぐにクイズ", subtitle: "読んだ範囲から理解を確かめる問いが届く") {
                        AppStoreScreenshotDevice {
                            quizQuestionView(questionKind: .comprehension)
                        }
                    }
                case .reading:
                    AppStoreScreenshotCanvas(title: "いつもの読書アプリで\n読むだけ", subtitle: "ハイライトもメモも要らない") {
                        AppStoreScreenshotDevice {
                            ReadingView(
                                book: sampleBook,
                                // 読んだ時間が 0 分に見えないよう、少し前に始めた読書にする。保存先には入れない。
                                // 23 分は、読んでいる途中に見える長さとして、見本の終えた読書の長さ (`DeveloperMenuSampleData.swift` の 600 秒から 4,200 秒までの 60 分) より短くした。10 秒は、撮影までに分の表示が繰り上がって見た目が変わらないよう、分の切れ目から離すための余り。
                                readingSession: ReadingSession(
                                    id: UUID(),
                                    startedDateTime: Date().addingTimeInterval(-23 * 60 - 10),
                                    endedDateTime: nil,
                                    book: nil
                                ),
                                endReading: {}
                            )
                        }
                    }
                case .questionKinds:
                    AppStoreScreenshotCanvas(title: "問いは 4 種類\n本ごとに選べる", subtitle: "四択・要約の正誤・穴埋め・記述") {
                        AppStoreScreenshotDevice {
                            QuestionSettingsView(book: sampleBook)
                        }
                    }
                case .evidence:
                    // 答えた後の画面は、UI テストが選択肢を押して出す (`DoquizUITests/AppStoreScreenshotTests.swift`)。
                    AppStoreScreenshotCanvas(title: "答えると\n根拠の本文が出る", subtitle: "本文と見比べて確かめられる") {
                        AppStoreScreenshotDevice {
                            quizQuestionView(questionKind: .summaryTrueFalse)
                        }
                    }
                case .privacy:
                    AppStoreScreenshotCanvas(title: "本文を\nサーバーに送らない", subtitle: "画像を残さずクイズも端末の中で作る") {
                        AppStoreScreenshotPrivacyCards()
                    }
                case .history:
                    AppStoreScreenshotCanvas(title: "履歴で\n答え直せる", subtitle: "本ごとに読書の記録と問いを見直す") {
                        AppStoreScreenshotDevice {
                            HistoryView(
                                book: sampleBook,
                                makeQuizEngine: { appStoreScreenshotQuizEngine },
                                close: {},
                                leaveDeletedBook: {}
                            )
                        }
                    }
                }
            }
            .modelContainer(modelContainer)
            // アプリの画面と同じく、端末の外観に関わらず明るい外観で出す (`ContentView` と同じ理由)。
            .preferredColorScheme(.light)
            .tint(doquizAccentColor)
        }

        /// 見本の問いのうち `questionKind` の問いに、読み終えた後のクイズと同じく答える画面。
        ///
        /// 判定は選択式なら模範の答えとの比較で決まり、端末内のモデルを呼ばない。穴埋めと記述には使わない。
        private func quizQuestionView(questionKind: QuestionKind) -> some View {
            guard let questionIndex = sampleQuestions.firstIndex(where: { $0.kind == questionKind }) else {
                fatalError("見本のデータに \(questionKind) の問いがありません")
            }
            return QuizQuestionView(
                question: sampleQuestions[questionIndex],
                position: (index: questionIndex, count: sampleQuestions.count),
                quizEngine: appStoreScreenshotQuizEngine,
                nextButtonTitle: "次の問いへ",
                goNext: {},
                // 離れるボタンは答える前に出さない (canLeaveBeforeAnswering が false) ため写らないが、`QuizView` と同じ文言にしておく。
                leaveButtonTitle: "本の画面に戻る",
                leave: {},
                canLeaveBeforeAnswering: false
            )
        }
    }

    /// スクリーンショットの画面が使う、端末内のモデルを呼ばないクイズの生成器。
    ///
    /// 撮影では問いを作り直さず、見本のデータの問いに答えるだけのため、作る問いは空にする。判定は選択式の問いだけに使うため、モデルの判定の値は使われない。
    private let appStoreScreenshotQuizEngine = FixedQuizEngine(availability: .available, questions: [], modelJudgement: true)

    /// 本文の扱いの 3 つの約束を並べた絵。文は紹介のページ (`docs/index.html`) の「本文をサーバーに送りません」の節と同じ。
    ///
    /// 余白・文字の大きさ・角の丸みの値は、3 枚の面が画像の中に収まり、文が途中で折れ過ぎないよう、CI で撮った画像 (run 46085769046) を目で見て決めた。
    struct AppStoreScreenshotPrivacyCards: View {
        var body: some View {
            VStack(spacing: 14) {
                privacyCard(
                    systemImage: "text.viewfinder",
                    title: "画面の画像は保存しない",
                    description: "取り込んだ画面は本文の抽出にだけ使い、保存するのは抽出した本文だけです。"
                )
                privacyCard(
                    systemImage: "iphone",
                    title: "クイズは端末の中で作る",
                    description: "問いの作成と判定は端末内のモデルで行い、本文を外部の AI サービスに送りません。"
                )
                privacyCard(
                    systemImage: "person.crop.circle.badge.xmark",
                    title: "アカウントは要らない",
                    description: "登録もログインもなく、本文・問い・回答はこの端末に保存します。"
                )
            }
            .padding(.horizontal, 28)
        }

        /// 約束 1 つ分の面。左に `systemImage` の印、右に `title` と `description` を出す。
        private func privacyCard(systemImage: String, title: String, description: String) -> some View {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(doquizAccentColor)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: title)
                        .font(.title3.bold())
                        .foregroundStyle(doquizTextColor)
                    Text(verbatim: description)
                        .font(.subheadline)
                        .foregroundStyle(doquizSecondaryTextColor)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(doquizBackgroundColor, in: RoundedRectangle(cornerRadius: 16))
        }
    }
#endif
