#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqUI
import DeltiqData
import DeltiqCore

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class RaceProgressCardModelTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeProfile(cardioCoachingEnabled: Bool = true) -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: cardioCoachingEnabled, cardioGoal: .halfMarathon
        )
        context.insert(profile)
        return profile
    }

    func testMakeReturnsNilWhenCoachingDisabled() {
        let profile = makeProfile(cardioCoachingEnabled: false)
        XCTAssertNil(RaceProgressCardModel.make(for: profile, allSessions: []))
    }

    func testMakeReturnsNonNilForEnabledCoachEvenWithNoHistoryAtAll() {
        let profile = makeProfile()
        let model = RaceProgressCardModel.make(for: profile, allSessions: [])
        // Keine Historie - trotzdem ein Modell, mit einem ehrlichen
        // insufficientData/leeren Zustand statt eines nil (Ticket-Testfall 6).
        XCTAssertNotNil(model)
    }

    // Testfall 22: Schutz vor stale Werten.
    func testCurrentWeeklyVolumeNeverUsesStaleOnboardingSnapshot() {
        let week1 = CardioVolumeOverTimePoint(
            weekStart: Date(timeIntervalSince1970: 1_700_000_000), runningDistanceKm: 10, runningSessionCount: 2,
            longestRunKm: 7, averagePaceMinutesPerKm: 6, averageHeartRateBpm: nil,
            crossTrainingSessionCount: 0, ambiguousCardioSessionCount: 0, strengthSessionCount: 2
        )
        let week2 = CardioVolumeOverTimePoint(
            weekStart: Date(timeIntervalSince1970: 1_700_604_800), runningDistanceKm: 20, runningSessionCount: 3,
            longestRunKm: 12, averagePaceMinutesPerKm: 5.8, averageHeartRateBpm: nil,
            crossTrainingSessionCount: 0, ambiguousCardioSessionCount: 0, strengthSessionCount: 2
        )
        let result = RaceProgressCardModel.currentWeeklyVolume(from: [week1, week2])
        XCTAssertEqual(result, 15, "muss das Mittel der echten letzten Wochen sein (10+20)/2, nie ein anderswo gepflegter Wert")
    }

    func testCurrentWeeklyVolumeIsNilWhenNoRecentWeekHasRunningVolume() {
        let zeroWeek = CardioVolumeOverTimePoint(
            weekStart: Date(), runningDistanceKm: 0, runningSessionCount: 0, longestRunKm: nil,
            averagePaceMinutesPerKm: nil, averageHeartRateBpm: nil, crossTrainingSessionCount: 0,
            ambiguousCardioSessionCount: 0, strengthSessionCount: 3
        )
        XCTAssertNil(RaceProgressCardModel.currentWeeklyVolume(from: [zeroWeek]))
    }

    func testConfigurationFingerprintChangesWithGoalOrRaceDate() {
        let raceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let a = RaceProgressCardModel.makeConfigurationFingerprint(goal: .halfMarathon, raceDate: raceDate)
        let b = RaceProgressCardModel.makeConfigurationFingerprint(goal: .marathon, raceDate: raceDate)
        let c = RaceProgressCardModel.makeConfigurationFingerprint(goal: .halfMarathon, raceDate: nil)
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// `dismiss(profile:)` darf ausschliesslich den Dismiss-Fingerprint
    /// setzen - kein Plan-/Profil-Ziel anfassen.
    func testDismissOnlySetsTheDismissedFingerprint() {
        let profile = makeProfile()
        guard let model = RaceProgressCardModel.make(for: profile, allSessions: []) else {
            return XCTFail("expected model")
        }
        let originalGoal = profile.cardioGoal

        model.dismiss(profile: profile)

        XCTAssertEqual(profile.raceProgressDismissedFingerprint, model.dismissalFingerprint)
        XCTAssertEqual(profile.cardioGoal, originalGoal)
    }
}
#endif
