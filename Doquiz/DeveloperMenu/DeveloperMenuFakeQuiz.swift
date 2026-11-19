#if DEBUG
    import Foundation
    import FoundationModels

    /// 開発者メニューの「偽のクイズ」の切り替えを保存する、UserDefaults のキー。値が無い時は、実物 (端末内のモデル) でクイズを作る。
    let developerMenuFakeQuizBehaviorKey = "developerMenuFakeQuizBehavior"

    /// 開発者メニューで選ぶ、偽のクイズの動き。定義の順を、開発者メニューで切り替える順に使う。
    ///
    /// `@AppStorage` が main actor の外からも値を読み書きできるよう、main actor に属さない型にしている。
    nonisolated enum DeveloperMenuFakeQuizBehavior: String, CaseIterable {
        /// 4 種類の問いを 1 問ずつ返す。
        case returnsQuestions
        /// 問いを 1 問も返さない。
        case returnsNoQuestions
        /// 端末内のモデルが使えないことにする。
        case modelUnavailable
        /// 問いを作る処理が失敗する。
        case failsToMakeQuestions
        /// 穴埋めの問いを 1 問返し、その判定が失敗する。
        case failsToJudge
    }

    /// 開発者メニューに出す、今のクイズの動きの名前を返す。偽のクイズに切り替えていない時 (nil) は実物の名前を返す。
    func developerMenuFakeQuizBehaviorLabel(behavior: DeveloperMenuFakeQuizBehavior?) -> String {
        switch behavior {
        case nil:
            "実物"
        case .returnsQuestions:
            "問いを返す"
        case .returnsNoQuestions:
            "問いを返さない"
        case .modelUnavailable:
            "モデルが使えない"
        case .failsToMakeQuestions:
            "作るのに失敗する"
        case .failsToJudge:
            "判定に失敗する"
        }
    }

    /// 開発者メニューの切り替えを 1 回押した後のクイズの動きを返す。実物 → `DeveloperMenuFakeQuizBehavior` の定義の順 → 実物、と一巡する。
    func nextDeveloperMenuFakeQuizBehavior(behavior: DeveloperMenuFakeQuizBehavior?) -> DeveloperMenuFakeQuizBehavior? {
        guard let behavior else {
            return DeveloperMenuFakeQuizBehavior.allCases.first
        }
        return DeveloperMenuFakeQuizBehavior.allCases.drop { $0 != behavior }.dropFirst().first
    }

    /// 偽のクイズが、問いを作る処理と判定を失敗させる時に投げる error。
    struct DeveloperMenuFakeQuizFailure: Error {}

    /// 偽のクイズが `returnsQuestions` の時に、問いを返すまで待つ時間。
    ///
    /// 3 秒にした理由: 問いを作っている間の画面を、UI テストがスクリーンショットに撮れる長さにするため (実物は端末内のモデルを問いの数だけ呼ぶ間、同じ画面が出る)。
    let developerMenuFakeQuizPreparationDuration = Duration.seconds(3)

    /// 開発者メニューで選んだ動きをする、偽の `QuizEngine`。端末内のモデルを呼ばない。
    ///
    /// 端末内のモデルは GitHub Actions の iOS Simulator で動くか確かめていないため、クイズの画面を Simulator と UI テストで確かめるのに使う
    /// (`documents/adr/0001-verify-on-external-machines.md`)。問いの文は、偽の読書の本文 (`developerMenuFakeReadingPageText`) に合わせてこのファイルのために書いた。
    struct DeveloperMenuFakeQuizEngine: QuizEngine {
        /// 開発者メニューで選んだ動き。
        let behavior: DeveloperMenuFakeQuizBehavior

        /// `behavior` が `modelUnavailable` の時だけ、使えない (端末が対応していない) を返す。
        var availability: SystemLanguageModel.Availability {
            behavior == .modelUnavailable ? .unavailable(.deviceNotEligible) : .available
        }

        /// 引数を読まずに、`behavior` で決まる問いを返す。
        ///
        /// 冪等ではない: 呼ぶたびに問いの `id` と作った日時が変わる (前に返した問いが保存済みでも、別の問いとして保存できるようにするため)。
        /// `returnsQuestions` の時は `developerMenuFakeQuizPreparationDuration` だけ待ってから返し、待っている間に取り消された時は `CancellationError` を投げる。
        /// `failsToMakeQuestions` の時は `DeveloperMenuFakeQuizFailure` を投げる。
        func makeQuestions(
            currentReadingPageTexts: [String],
            previousReadingPageTexts: [String],
            questionKinds: [QuestionKind],
            questionGuidance: String?
        ) async throws -> [Question] {
            switch behavior {
            case .returnsQuestions:
                try await Task.sleep(for: developerMenuFakeQuizPreparationDuration)
                return QuestionKind.allCases.map { makeDeveloperMenuFakeQuestion(questionKind: $0) }
            case .returnsNoQuestions, .modelUnavailable:
                return []
            case .failsToMakeQuestions:
                throw DeveloperMenuFakeQuizFailure()
            case .failsToJudge:
                return [makeDeveloperMenuFakeQuestion(questionKind: .fillInTheBlank)]
            }
        }

        /// 答えが模範の答えと同じ文字列かを返す (合っている判定と合っていない判定の両方の画面を、答えの入力で出し分けられるようにするため)。
        /// `behavior` が `failsToJudge` の時は `DeveloperMenuFakeQuizFailure` を投げる。
        func judgeWithModel(question: Question, answerText: String) async throws -> Bool {
            guard behavior != .failsToJudge else {
                throw DeveloperMenuFakeQuizFailure()
            }
            return answerText == question.modelAnswer
        }
    }

    /// 偽のクイズが返す、種類 `questionKind` の、保存していない問い (`readingSession` は nil) を作る。
    ///
    /// 冪等ではない: 呼ぶたびに問いの `id` と作った日時が変わる。
    private func makeDeveloperMenuFakeQuestion(questionKind: QuestionKind) -> Question {
        switch questionKind {
        case .comprehension:
            Question(
                id: UUID(),
                createdDateTime: Date(),
                kind: questionKind,
                text: "灯台守が毎朝 日誌に書きとめたものは何か",
                choices: ["波の高さ", "霧の濃さ", "船の数", "風の向き"],
                modelAnswer: "霧の濃さ",
                evidenceQuote: developerMenuFakeReadingPageText,
                readingSession: nil
            )
        case .summaryTrueFalse:
            Question(
                id: UUID(),
                createdDateTime: Date(),
                kind: questionKind,
                text: "要約「灯台守は毎晩 霧の濃さを日誌に書きとめた」は本文と合っているか",
                choices: summaryTrueFalseChoices,
                modelAnswer: "誤り",
                evidenceQuote: developerMenuFakeReadingPageText,
                readingSession: nil
            )
        case .fillInTheBlank:
            Question(
                id: UUID(),
                createdDateTime: Date(),
                kind: questionKind,
                text: "灯台守は毎朝 ＿＿の濃さを日誌に書きとめた",
                choices: [],
                modelAnswer: "霧",
                evidenceQuote: developerMenuFakeReadingPageText,
                readingSession: nil
            )
        case .written:
            Question(
                id: UUID(),
                createdDateTime: Date(),
                kind: questionKind,
                text: "灯台守は毎朝 何をしていたか",
                choices: [],
                modelAnswer: "霧の濃さを日誌に書きとめていた",
                evidenceQuote: developerMenuFakeReadingPageText,
                readingSession: nil
            )
        }
    }
#endif
