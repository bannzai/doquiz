import Foundation
import SwiftData

/// 問いの種類の、画面に出す名前を返す。
func questionKindLabel(questionKind: QuestionKind) -> String {
    switch questionKind {
    case .comprehension:
        "四択"
    case .summaryTrueFalse:
        "要約の正誤"
    case .fillInTheBlank:
        "穴埋め"
    case .written:
        "記述"
    }
}

/// 本の出題の設定 (出題する問いの種類と、出題への希望) を保存し、保存したかを返す。
///
/// 問いの種類は、選んだ順に関わらず `QuestionKind` の定義の順に並べて保存する。
/// 出題への希望は前後の空白と改行を除いて保存し、除いた結果が空の時は nil (書いていない) にする。
/// 問いの種類を 1 つも選んでいない時は、問いを 1 問も作れなくなるため、本を変えずに false を返す。
/// 保存先への書き込みに失敗した時は、SwiftData のエラーを投げる。
/// 同じ値で何回呼んでも、本の出題の設定は同じ内容になる。
func saveQuestionSettings(
    book: Book,
    questionKinds: Set<QuestionKind>,
    questionGuidance: String,
    modelContext: ModelContext
) throws -> Bool {
    let trimmedQuestionGuidance = questionGuidance.trimmingCharacters(in: .whitespacesAndNewlines)
    book.questionKinds = QuestionKind.allCases.reversed().filter { questionKinds.contains($0) }
    book.questionGuidance = questionGuidance
    try modelContext.save()
    return true
}
