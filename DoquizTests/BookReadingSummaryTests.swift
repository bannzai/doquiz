import Foundation
import SwiftData
import Testing
@testable import Doquiz

/// 本の読書の回数と最後に読んだ時期の文を、端末に書き込まないメモリ内の保存先で確かめる。
struct BookReadingSummaryTests {
    /// 本と読書の記録を足す context。
    private let modelContext: ModelContext
    /// 文を求める時の「今」として渡す日時。
    private let currentDateTime = Date(timeIntervalSince1970: 1_800_000_000)

    /// テストごとに、メモリ内の保存先を新しく作る。
    init() throws {
        modelContext = ModelContext(try makeModelContainer(isStoredInMemoryOnly: true))
    }

    /// 本 1 冊と、`currentDateTime` から `secondsBeforeCurrentDateTime` の各秒数だけ前に始めた読書の記録を足して保存し、足した本を返す。
    private func insertBook(secondsBeforeCurrentDateTime: [TimeInterval]) throws -> Book {
        let book = Book(
            id: UUID(),
            createdDateTime: Date(timeIntervalSince1970: 1_700_000_000),
            title: "潮見町の灯台日誌",
            questionKinds: [.written],
            questionGuidance: nil
        )
        modelContext.insert(book)
        for seconds in secondsBeforeCurrentDateTime {
            modelContext.insert(
                ReadingSession(
                    id: UUID(),
                    startedDateTime: currentDateTime.addingTimeInterval(-seconds),
                    endedDateTime: nil,
                    book: book
                )
            )
        }
        try modelContext.save()
        return book
    }

    /// 読書の記録が無い本は「まだ読んでいません」になることを確かめる。
    @Test func 読書の記録が無い本はまだ読んでいないと出す() throws {
        #expect(
            bookReadingSummary(book: try insertBook(secondsBeforeCurrentDateTime: []), currentDateTime: currentDateTime)
                == "まだ読んでいません"
        )
    }

    /// 読書の記録が 1 件で、1 日前に始めた本は「読書 1 回 ・ 最後に読んだのは昨日」になることを確かめる。
    @Test func 昨日1回読んだ本は回数と昨日を出す() throws {
        #expect(
            bookReadingSummary(
                book: try insertBook(secondsBeforeCurrentDateTime: [86_400]),
                currentDateTime: currentDateTime
            ) == "読書 1 回 ・ 最後に読んだのは昨日"
        )
    }

    /// 読書の記録が 3 件ある本は、件数が 3 回で、時期はいちばん新しい読書 (1 日前) の言い方になり、古い読書 (10 日前・30 日前) の言い方にならないことを確かめる。
    @Test func 複数回読んだ本は回数といちばん新しい読書の時期を出す() throws {
        #expect(
            bookReadingSummary(
                book: try insertBook(secondsBeforeCurrentDateTime: [864_000, 86_400, 2_592_000]),
                currentDateTime: currentDateTime
            ) == "読書 3 回 ・ 最後に読んだのは昨日"
        )
    }
}
