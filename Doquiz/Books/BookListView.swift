import SwiftData
import SwiftUI

/// 読む本を選ぶ画面。登録済みの本の一覧と、新しい本を登録する入口と、設定の画面への入口を出す。アプリを開いた直後に出る。
/// 購入もトライアルもしていない利用者が読書を始めた後は、購入の画面の入口と、無料で始められる読書の残りも出す。
/// 端末内のモデルが使えない間は、クイズを出せないことと理由の案内を一覧の上に出す。
///
/// 本を選んだ時に本の画面へ進むため、`NavigationStack` の中に置く。
struct BookListView: View {
    /// 登録済みの本。登録が新しい順に並べる。
    @Query(sort: \Book.createdDateTime, order: .reverse) private var books: [Book]
    /// 端末内のモデルが使えない時の案内の文。使える時は nil。
    @Environment(\.quizUnavailableGuide) private var quizUnavailableGuide
    /// これまでに無料で始めた読書の回数。本の画面が読書を始めた時に増やす。
    /// 既定を 0 にしているのは、保存した値が無い利用者は、まだ無料の読書を 1 回も始めていないため。
    @AppStorage(freeReadingStartCountKey) private var freeReadingStartCount = 0
    /// 最後に確かめた購入の状態。まだ確かめ終えていない間と、確かめて取得できなかった時は nil。
    @State private var purchaseState: PurchaseState?
    /// 購入の画面を閉じた回数。閉じるたびに購入の状態を確かめ直すために数える。
    @State private var purchaseSheetDismissCount = 0
    /// ホームから最後に出した購入の画面が使った購入の境界と、その境界を作った時の作り方の種類 (`PurchaseServiceSource.kindID`)。
    /// 購入の画面を閉じた後に購入の状態を確かめ直す時は、作り方が変わっていなければこの境界を使う
    /// (購入の画面で購入した結果を、購入した境界から読むため。偽の購入は、境界ごとに購入の状態を覚えている)。
    @State private var purchaseSheetPurchaseService: (kindID: String, purchaseService: any PurchaseService)?
    /// 本を登録する画面を出しているか。
    @State private var isRegisteringBook = false
    /// 出している購入の画面。出していない間は nil。
    /// 入口を押すたびに購入の境界を 1 回だけ作って持ち、画面を出している間は同じものを使う
    /// (出している間に一覧が描き直されても、偽の購入が覚えている状態と、状態の変化を流している stream を作り直さないため)。
    @State private var presentedPurchase: PresentedPurchase?
    /// 購入の画面と、購入の状態を確かめる時に使う購入の境界の作り方。
    private let purchaseServiceSource = PurchaseServiceSource()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "何を読みますか")
                            .font(.largeTitle.bold())
                            .foregroundStyle(doquizTextColor)
                        Text(verbatim: "読む本を選ぶと読書を始められます")
                            .font(.subheadline)
                            .foregroundStyle(doquizSecondaryTextColor)
                    }
                    if let quizUnavailableGuide {
                        QuizUnavailableGuidePanel(guide: quizUnavailableGuide)
                    }
                    if books.isEmpty {
                        Text(verbatim: "まだ本がありません\n最初に読む本を登録しましょう")
                            .font(.body)
                            .foregroundStyle(doquizSecondaryTextColor)
                            .accessibilityIdentifier("book_list_empty_guide")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(books) { book in
                                NavigationLink(value: book) {
                                    bookRow(book: book)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("book_list_row")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            Button {
                isRegisteringBook = true
            } label: {
                Text(verbatim: books.isEmpty ? "最初の本を登録する" : "新しい本を登録する")
                    .font(.headline)
                    .foregroundStyle(doquizAccentColor)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizAccentColor, lineWidth: 1.5))
            }
            .accessibilityIdentifier("book_registration_entrance")
            .padding(.horizontal, 20)
            if showsPurchaseEntrance(books: books, purchaseState: purchaseState) {
                Text(verbatim: freeReadingRemainingText(freeReadingStartCount: freeReadingStartCount))
                    .font(.footnote)
                    .foregroundStyle(doquizSecondaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .accessibilityIdentifier("free_reading_remaining")
                Button {
                    let purchaseService = purchaseServiceSource.makePurchaseService()
                    purchaseSheetPurchaseService = (kindID: purchaseServiceSource.kindID, purchaseService: purchaseService)
                    presentedPurchase = PresentedPurchase(id: UUID(), purchaseService: purchaseService)
                } label: {
                    Text(verbatim: "購入のプランを見る")
                        .font(.subheadline)
                        .foregroundStyle(doquizAccentColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("purchase_entrance")
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            } else {
                // 入口を出さない間も、登録のボタンの下を、入口を足す前と同じだけ空ける。
                Spacer()
                    .frame(height: 24)
            }
        }
        .background(doquizBackgroundColor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text(verbatim: "設定"))
                .accessibilityIdentifier("settings_entrance")
            }
        }
        .navigationDestination(for: Book.self) { book in
            BookView(book: book)
        }
        .sheet(isPresented: $isRegisteringBook) {
            BookRegistrationView()
        }
        // 出す購入の画面を item で渡す。sheet の中身が、入口を押した時に作った購入の境界を必ず受け取るようにするため
        // (`isPresented` と別の `@State` に境界を持つ形は、初めて出す時に sheet の中身が境界を読めず、購入の画面が出なかった。
        // CI の run 44721692598 で、購入の UI テスト 4 件が入口を押した直後に落ちた)。
        .sheet(
            item: $presentedPurchase,
            onDismiss: {
                purchaseSheetDismissCount += 1
            },
            content: { presentedPurchase in
                PurchaseView(purchaseService: presentedPurchase.purchaseService)
            }
        )
        // この画面が出るたび (本の画面・設定の画面・開発者メニューから戻った時を含む) と、購入の画面を閉じた時と、
        // 開発者メニューで偽の購入の動きを変えた時に、購入の状態を確かめ直す。購入はほかの画面でも済むため、出ている間ずっと同じ値を使わない。
        .task(id: purchaseStateCheckID) {
            // 取得できない時は nil にして、入口と残りの回数を出さない (購入しているかが分からない利用者に、購入していない前提の表示を出さないため)。
            let checkedPurchaseState = try? await purchaseServiceForStateCheck().state()
            // 確かめている間に次の確かめ直しが始まった時は、古い結果で上書きしない。
            guard !Task.isCancelled else {
                return
            }
            purchaseState = checkedPurchaseState
        }
    }

    /// 購入の状態を確かめる時に使う購入の境界を返す。ホームから出した購入の画面の境界があり、作り方が変わっていなければそれを返し、
    /// それ以外は新しく作る。
    private func purchaseServiceForStateCheck() -> any PurchaseService {
        guard
            let purchaseSheetPurchaseService,
            reusesPurchaseSheetPurchaseService(purchaseSheetKindID: purchaseSheetPurchaseService.kindID, currentKindID: purchaseServiceSource.kindID)
        else {
            return purchaseServiceSource.makePurchaseService()
        }
        return purchaseSheetPurchaseService.purchaseService
    }

    /// 購入の状態を確かめ直す時を表す値。購入の画面を閉じた時と、開発者メニューで偽の購入の動きを変えた時に変わる。
    private var purchaseStateCheckID: String {
        "\(purchaseSheetDismissCount)-\(purchaseServiceSource.kindID)"
    }

    /// 一覧の本 1 冊分の行。本の名前と、読書の回数・最後に読んだ時期を出す。
    private func bookRow(book: Book) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: book.title)
                .font(.headline)
                .foregroundStyle(doquizTextColor)
                .multilineTextAlignment(.leading)
            Text(verbatim: bookReadingSummary(book: book, currentDateTime: Date()))
                .font(.subheadline)
                .foregroundStyle(doquizSecondaryTextColor)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(doquizBorderColor, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        BookListView()
    }
    .modelContainer(for: Book.self, inMemory: true)
}
