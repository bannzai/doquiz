import Foundation
import FoundationModels
import Testing

@testable import Doquiz

/// 端末内のモデルが使えない時の案内の文 (`quizUnavailableGuide`) を、偽の `FixedQuizEngine` が返す値で確かめる。
@MainActor struct QuizUnavailableGuideTests {
    /// 端末内のモデルが使えるかとして `availability` を返す偽の `QuizEngine` から、案内の文を作る。
    private func guide(availability: SystemLanguageModel.Availability) -> String? {
        quizUnavailableGuide(
            availability: FixedQuizEngine(availability: availability, questions: [], modelJudgement: false).availability
        )
    }

    /// 使えない理由のどの種類にも、クイズを出せないことを伝える、空でない案内の文がある。
    @Test(arguments: [
        SystemLanguageModel.Availability.UnavailableReason.deviceNotEligible,
        .appleIntelligenceNotEnabled,
        .modelNotReady,
    ])
    func 使えない理由ごとにクイズを出せないことの案内がある(unavailableReason: SystemLanguageModel.Availability.UnavailableReason) throws {
        let unavailableGuide = try #require(guide(availability: .unavailable(unavailableReason)))

        #expect(!unavailableGuide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(unavailableGuide.contains("クイズを出せません"))
    }

    /// 使えない理由の種類ごとに、案内の文が違う。
    @Test func 使えない理由の種類ごとに案内の文が違う() throws {
        let unavailableGuides = try [
            SystemLanguageModel.Availability.UnavailableReason.deviceNotEligible,
            .appleIntelligenceNotEnabled,
            .modelNotReady,
        ].map { try #require(guide(availability: .unavailable($0))) }

        #expect(Set(unavailableGuides).count == 3)
    }

    /// 利用者が自分で直せる理由 (Apple Intelligence を切っている) の案内には、直し方 (設定アプリでオンにする) が書かれている。
    /// 利用者が直せない理由 (端末が対応していない) の案内には、設定アプリでの直し方が書かれていない。
    @Test func 自分で直せる理由の案内にだけ設定アプリでの直し方がある() {
        #expect(guide(availability: .unavailable(.appleIntelligenceNotEnabled))?.contains("設定アプリで Apple Intelligence をオンにする") == true)
        #expect(guide(availability: .unavailable(.deviceNotEligible))?.contains("設定アプリ") == false)
    }

    /// 使える時は案内の文が無い。
    @Test func 使える時は案内が無い() {
        #expect(guide(availability: .available) == nil)
    }
}
