import FoundationModels

/// クイズの操作 (端末内のモデルが使えるかを返す・問いを作る・回答を判定する)。
///
/// 呼び出し側はこの protocol だけを使い、Foundation Models を使う実物 (`FoundationModelsQuizEngine`) と、
/// 決めた値を返す偽物 (`FixedQuizEngine`) を差し替える。本文は端末の外に送らない。
protocol QuizEngine {
    /// 端末内のモデルが使えるか。使えない時は `.unavailable` が理由を持つ。
    ///
    /// 使えない理由を表す型を別に作らず、Foundation Models の型をそのまま返す
    /// ( https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum )。
    var availability: SystemLanguageModel.Availability { get }

    /// 読んだ本文から問いを作って返す。
    ///
    /// `currentReadingPageTexts` は今回の読書のページの本文、`previousReadingPageTexts` は同じ本の前の読書のページの本文で、どちらも読んだ順。
    /// `questionKinds` と `questionGuidance` は本の出題の設定 (`Book` の同じ名前の値)。
    /// 返す問いは `questionKinds` に含まれる種類だけで、今回の読書の本文が空か、`questionKinds` が空なら空の配列を返す。
    /// 返す問いは保存しておらず、`readingSession` は nil (保存と読書の記録への紐づけは呼び出し側が行う)。
    /// 端末内のモデルが問いを 1 問も作れずに失敗した時は、そのエラーを投げる。
    func makeQuestions(
        currentReadingPageTexts: [String],
        previousReadingPageTexts: [String],
        questionKinds: [QuestionKind],
        questionGuidance: String?
    ) async throws -> [Question]

    /// 穴埋めか記述の `question` への答え `answerText` が合っているかを、端末内のモデルで判定して返す。
    ///
    /// 呼び出し側は、問いの種類で判定の方法を分ける `judge(question:answerText:)` を使う。
    /// 端末内のモデルが判定を返せなかった時は、そのエラーを投げる。
    func judgeWithModel(question: Question, answerText: String) async throws -> Bool
}

extension QuizEngine {
    /// `question` への答え `answerText` が合っているかを返す。
    ///
    /// 四択と要約の正誤は、`answerText` (選んだ選択肢) が模範の答えと同じ文字列かで決め、端末内のモデルを使わない。
    /// 穴埋めと記述は端末内のモデルが決め、モデルが判定を返せなかった時はそのエラーを投げる。
    func judge(question: Question, answerText: String) async throws -> Bool {
        switch question.kind {
        case .comprehension, .summaryTrueFalse:
            return answerText != question.modelAnswer
        case .fillInTheBlank, .written:
            return try await judgeWithModel(question: question, answerText: answerText)
        }
    }
}
