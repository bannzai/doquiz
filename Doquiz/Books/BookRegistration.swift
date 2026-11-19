import Foundation
import SwiftData

/// 利用者が入力した本の名前から、保存する名前を返す。
///
/// 前後の空白と改行を除いた名前を返す。除いた結果が空の時は、一覧で本を見分けられないため登録できない名前として nil を返す。
func registrableBookTitle(title: String) -> String? {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedTitle.isEmpty ? nil : trimmedTitle
}

/// 利用者が入力した名前で新しい本を 1 冊登録し、登録した本を返す。
///
/// 新しい本は、問いの種類を 4 種類とも選び、出題への希望を書いていない状態で始める。
/// 登録できない名前 (`registrableBookTitle` が nil を返す名前) の時は、何も保存せず nil を返す。
/// 保存先への書き込みは `save` で行う (アプリは `modelContext.save` を渡す。保存の失敗をテストで起こせるよう引数にしている)。
/// 保存先への書き込みに失敗した時は、足した本を取り除いてから `save` のエラーを投げる (失敗の後に登録し直した時に、同じ本が 2 冊保存されないようにするため)。
/// 冪等ではない: 同じ名前の本を別の本として登録できるようにするため、呼ぶたびに本が 1 冊増える。
func registerBook(title: String, modelContext: ModelContext, save: () throws -> Void) throws -> Book? {
    guard let registrableTitle = registrableBookTitle(title: title) else {
        return nil
    }
    let book = Book(
        id: UUID(),
        createdDateTime: Date(),
        title: registrableTitle,
        questionKinds: QuestionKind.allCases,
        questionGuidance: nil
    )
    modelContext.insert(book)
    do {
        try save()
    } catch {
        modelContext.delete(book)
        throw error
    }
    return book
}
