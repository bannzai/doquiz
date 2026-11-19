import FoundationModels
import Testing

@testable import Doquiz

/// 開発者メニューで選んだ確かめ方が、偽の `FixedQuizEngine` に返させる値に正しく対応することを確かめる。
@MainActor struct DeveloperMenuQuizAvailabilityTests {
    /// 実物で確かめる時は、偽物に返させる値が無い。
    @Test func 実物で確かめる時は偽物の値が無い() {
        #expect(developerMenuFakeQuizAvailability(developerMenuQuizAvailability: .real) == nil)
    }

    /// 使えることにする時は、偽物に「使える」を返させる。
    @Test func 使えることにする時は使えるを返させる() {
        #expect(developerMenuFakeQuizAvailability(developerMenuQuizAvailability: .available) == .available)
    }

    /// 使えないことにする時は、選んだ理由の「使えない」を偽物に返させる。
    @Test(arguments: [
        (DeveloperMenuQuizAvailability.deviceNotEligible, SystemLanguageModel.Availability.UnavailableReason.deviceNotEligible),
        (.appleIntelligenceNotEnabled, .appleIntelligenceNotEnabled),
        (.modelNotReady, .modelNotReady),
    ])
    func 使えないことにする時は選んだ理由の使えないを返させる(
        developerMenuQuizAvailability: DeveloperMenuQuizAvailability,
        unavailableReason: SystemLanguageModel.Availability.UnavailableReason
    ) {
        #expect(
            developerMenuFakeQuizAvailability(developerMenuQuizAvailability: developerMenuQuizAvailability)
                == .unavailable(unavailableReason)
        )
    }

    /// 開発者メニューのボタンの名前は、確かめ方ごとに違う (どれを選んだかを見分けられる)。
    @Test func ボタンの名前は確かめ方ごとに違う() {
        #expect(
            Set(DeveloperMenuQuizAvailability.allCases.map { developerMenuQuizAvailabilityTitle(developerMenuQuizAvailability: $0) }).count
                == DeveloperMenuQuizAvailability.allCases.count
        )
    }
}
