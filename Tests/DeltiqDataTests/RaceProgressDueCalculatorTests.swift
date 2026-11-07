#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md,
/// Abschnitt 3/6).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class RaceProgressDueCalculatorTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeProfile(cardioCoachingEnabled: Bool = true, cardioCoachingEnabledAt: Date? = Date(timeIntervalSince1970: 1_700_000_000)) -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: cardioCoachingEnabled, cardioGoal: .halfMarathon
        )
        profile.cardioCoachingEnabledAt = cardioCoachingEnabledAt
        context.insert(profile)
        return profile
    }

    // Testfall 1: neue Laufeinheit loest Aktualisierung aus.
    func testNewActivitySinceLastAnalysisMakesItDue() {
        let lastAnalyzed = Date(timeIntervalSince1970: 1_700_000_000)
        let newRun = lastAnalyzed.addingTimeInterval(86400)
        let state = RaceProgressDueCalculator.state(
            lastAnalyzedAt: lastAnalyzed, lastAnalyzedConfigurationFingerprint: "fp",
            currentConfigurationFingerprint: "fp", latestLoggedTrainingDate: newRun,
            now: newRun.addingTimeInterval(3600)
        )
        guard case .due(let reasons) = state else { return XCTFail("expected due, got \(state)") }
        XCTAssertTrue(reasons.contains(.newActivitySinceLastAnalysis))
    }

    // Testfall 2: mehrere neue Einheiten erzeugen keine doppelten Analysen -
    // derselbe Zustand wird wiederholt als EIN einzelner Grund gemeldet, egal
    // wie viele Einheiten seither geloggt wurden (nur das spaeteste Datum zaehlt).
    func testMultipleNewRunsOnSameDayDoNotDuplicateDueReasons() {
        let lastAnalyzed = Date(timeIntervalSince1970: 1_700_000_000)
        let latestOfSeveralRuns = lastAnalyzed.addingTimeInterval(86400)
        let state = RaceProgressDueCalculator.state(
            lastAnalyzedAt: lastAnalyzed, lastAnalyzedConfigurationFingerprint: "fp",
            currentConfigurationFingerprint: "fp", latestLoggedTrainingDate: latestOfSeveralRuns,
            now: latestOfSeveralRuns.addingTimeInterval(3600)
        )
        guard case .due(let reasons) = state else { return XCTFail("expected due") }
        XCTAssertEqual(reasons.filter { $0 == .newActivitySinceLastAnalysis }.count, 1)
    }

    /// Nach einer durchgefuehrten Analyse (`recordAnalysisCompleted`) muss
    /// ein erneuter `state(...)`-Aufruf mit unveraendertem
    /// `latestLoggedTrainingDate` NICHT mehr faellig sein - ein
    /// "Doppeltap"/mehrfacher App-Start darf keine zweite Analyse ausloesen.
    func testRecordAnalysisCompletedIsIdempotentAgainstConcurrentDueChecks() throws {
        let profile = makeProfile()
        try context.save()
        let runDate = Date(timeIntervalSince1970: 1_700_100_000)

        RaceProgressDueCalculator.recordAnalysisCompleted(for: profile, configurationFingerprint: "fp", now: runDate.addingTimeInterval(3600), in: context)

        let state = RaceProgressDueCalculator.state(
            lastAnalyzedAt: profile.raceProgressLastAnalyzedAt,
            lastAnalyzedConfigurationFingerprint: profile.raceProgressLastAnalyzedConfigurationFingerprint,
            currentConfigurationFingerprint: "fp", latestLoggedTrainingDate: runDate,
            now: runDate.addingTimeInterval(7200)
        )
        guard case .notYetDue = state else { return XCTFail("expected notYetDue after recording, got \(state)") }
    }

    // Testfall 8: Zielwechsel macht eine erneute Analyse faellig, unabhaengig
    // von Zeit/neuen Einheiten.
    func testConfigurationChangeMakesItDueRegardlessOfTiming() {
        let state = RaceProgressDueCalculator.state(
            lastAnalyzedAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastAnalyzedConfigurationFingerprint: "halfMarathon#raceDateA",
            currentConfigurationFingerprint: "marathon#raceDateA",
            latestLoggedTrainingDate: nil, now: Date(timeIntervalSince1970: 1_700_000_001)
        )
        guard case .due(let reasons) = state else { return XCTFail("expected due") }
        XCTAssertEqual(reasons, [.configurationChanged])
    }

    func testNeverAnalyzedIsAlwaysDue() {
        let state = RaceProgressDueCalculator.state(
            lastAnalyzedAt: nil, lastAnalyzedConfigurationFingerprint: nil,
            currentConfigurationFingerprint: "fp", latestLoggedTrainingDate: nil, now: Date()
        )
        XCTAssertEqual(state, .due(reasons: [.neverAnalyzed]))
    }

    func testPeriodicIntervalElapsedFiresAfter14Days() {
        let lastAnalyzed = Date(timeIntervalSince1970: 1_700_000_000)
        let fourteenDaysLater = lastAnalyzed.addingTimeInterval(14 * 86400)
        let state = RaceProgressDueCalculator.state(
            lastAnalyzedAt: lastAnalyzed, lastAnalyzedConfigurationFingerprint: "fp",
            currentConfigurationFingerprint: "fp", latestLoggedTrainingDate: nil, now: fourteenDaysLater
        )
        guard case .due(let reasons) = state else { return XCTFail("expected due") }
        XCTAssertTrue(reasons.contains(.periodicIntervalElapsed))
    }

    func testNotYetDueWhenNothingChangedAndIntervalNotElapsed() {
        let lastAnalyzed = Date(timeIntervalSince1970: 1_700_000_000)
        let state = RaceProgressDueCalculator.state(
            lastAnalyzedAt: lastAnalyzed, lastAnalyzedConfigurationFingerprint: "fp",
            currentConfigurationFingerprint: "fp", latestLoggedTrainingDate: nil,
            now: lastAnalyzed.addingTimeInterval(86400)
        )
        guard case .notYetDue = state else { return XCTFail("expected notYetDue, got \(state)") }
    }

    // MARK: - Migration (Testfall 20)

    func testEstablishObservationAnchorNeverBackdatesForExistingCoachingUser() throws {
        // Bestandsnutzer: Coach war schon aktiv, aber dieses Feld existierte
        // beim Erstellen des Profils noch nicht -> nil.
        let profile = makeProfile(cardioCoachingEnabled: true, cardioCoachingEnabledAt: nil)
        try context.save()

        let migrationRunTime = Date(timeIntervalSince1970: 1_700_500_000)
        RaceProgressDueCalculator.establishObservationAnchorIfNeeded(for: profile, now: migrationRunTime, in: context)

        XCTAssertEqual(profile.cardioCoachingEnabledAt, migrationRunTime, "muss auf den Zeitpunkt DIESES Aufrufs gesetzt werden, nie auf ein erfundenes vergangenes Datum")
    }

    func testEstablishObservationAnchorDoesNothingWhenAlreadySet() throws {
        let originalAnchor = Date(timeIntervalSince1970: 1_600_000_000)
        let profile = makeProfile(cardioCoachingEnabled: true, cardioCoachingEnabledAt: originalAnchor)
        try context.save()

        RaceProgressDueCalculator.establishObservationAnchorIfNeeded(for: profile, now: Date(timeIntervalSince1970: 1_700_500_000), in: context)

        XCTAssertEqual(profile.cardioCoachingEnabledAt, originalAnchor, "ein bereits bekannter Beobachtungsbeginn darf nie ueberschrieben werden")
    }

    func testEstablishObservationAnchorDoesNothingWhenCoachingIsDisabled() throws {
        let profile = makeProfile(cardioCoachingEnabled: false, cardioCoachingEnabledAt: nil)
        try context.save()

        RaceProgressDueCalculator.establishObservationAnchorIfNeeded(for: profile, now: Date(), in: context)

        XCTAssertNil(profile.cardioCoachingEnabledAt, "ohne aktiven Coach gibt es keinen Beobachtungszeitraum zu etablieren")
    }
}
#endif
