import XCTest
@testable import FitnessAppCore

/// Smart-Onboarding-Epic Phase 2: reine Herleitungs-Tests fuer
/// `ExperienceTrackResolver`. Persistenz-/Backfill-Tests (SwiftData) leben in
/// `FitnessAppDataTests/ExperienceTrackBackfillTests.swift`.
final class ExperienceTrackTests: XCTestCase {

    // MARK: - track(for:priorExperience:) — Onboarding-Quiz-Antwort

    func testNeverTrainedIsStarter() {
        XCTAssertEqual(ExperienceTrackResolver.track(for: .neverTrained), .starter)
    }

    func testLongBreakAfterTrainingIsReturner() {
        XCTAssertEqual(ExperienceTrackResolver.track(for: .longBreakAfterTraining), .returner)
    }

    func testTrainingRegularlyIsExperienced() {
        XCTAssertEqual(ExperienceTrackResolver.track(for: .trainingRegularly), .experienced)
    }

    /// `.trainingIrregularly` ohne Folgefrage-Antwort (sollte am Quiz nicht
    /// vorkommen, aber der Parameter ist optional) faellt auf Starter zurueck.
    func testTrainingIrregularlyWithoutPriorExperienceIsStarter() {
        XCTAssertEqual(ExperienceTrackResolver.track(for: .trainingIrregularly), .starter)
    }

    func testTrainingIrregularlyWithUnderOneYearIsStarter() {
        XCTAssertEqual(
            ExperienceTrackResolver.track(for: .trainingIrregularly, priorExperience: .underOneYear),
            .starter
        )
    }

    func testTrainingIrregularlyWithOneToThreeYearsIsExperienced() {
        XCTAssertEqual(
            ExperienceTrackResolver.track(for: .trainingIrregularly, priorExperience: .oneToThreeYears),
            .experienced
        )
    }

    func testTrainingIrregularlyWithOverThreeYearsIsExperienced() {
        XCTAssertEqual(
            ExperienceTrackResolver.track(for: .trainingIrregularly, priorExperience: .overThreeYears),
            .experienced
        )
    }

    /// `priorExperience` wird bei den anderen drei Antworten ignoriert — das
    /// darf sich nicht veraendern, sonst widerspricht die Herleitung der
    /// Quiz-Fragenreihenfolge (Folgefrage B existiert nur bei irregular).
    func testPriorExperienceIsIgnoredOutsideTrainingIrregularly() {
        XCTAssertEqual(
            ExperienceTrackResolver.track(for: .neverTrained, priorExperience: .overThreeYears),
            .starter
        )
        XCTAssertEqual(
            ExperienceTrackResolver.track(for: .trainingRegularly, priorExperience: .underOneYear),
            .experienced
        )
    }

    // MARK: - trackFromHistory(...) — Bestandsnutzer-Backfill

    /// Keine Kraft-Session jemals -> zu wenig Signal, nie Starter erzwingen.
    func testHistoryWithNoStrengthSessionsIsExperienced() {
        XCTAssertEqual(
            ExperienceTrackResolver.trackFromHistory(
                gapDaysSinceLastStrengthSession: nil,
                priorStrengthSessionCount: 0
            ),
            .experienced
        )
    }

    /// Unter der ComebackAdvisor-Schwelle (`minimumPriorStrengthSessions`)
    /// fuer belastbare Historie -> Experienced, nicht Returner.
    func testHistoryBelowMinimumSessionCountIsExperienced() {
        XCTAssertEqual(
            ExperienceTrackResolver.trackFromHistory(
                gapDaysSinceLastStrengthSession: 400,
                priorStrengthSessionCount: ComebackAdvisor.minimumPriorStrengthSessions - 1
            ),
            .experienced
        )
    }

    /// Genug Historie, Luecke knapp UNTER der ComebackAdvisor-Schwelle ->
    /// weiterhin Experienced (keine eigene Kalibrierung erfunden).
    func testHistoryWithRecentStrengthSessionIsExperienced() {
        XCTAssertEqual(
            ExperienceTrackResolver.trackFromHistory(
                gapDaysSinceLastStrengthSession: ComebackAdvisor.minimumGapDays - 1,
                priorStrengthSessionCount: ComebackAdvisor.minimumPriorStrengthSessions
            ),
            .experienced
        )
    }

    /// Genug Historie, Luecke GENAU auf der ComebackAdvisor-Schwelle ->
    /// Returner (dieselbe Grenze wie `ComebackAdvisor.minimumGapDays`).
    func testHistoryWithGapAtThresholdIsReturner() {
        XCTAssertEqual(
            ExperienceTrackResolver.trackFromHistory(
                gapDaysSinceLastStrengthSession: ComebackAdvisor.minimumGapDays,
                priorStrengthSessionCount: ComebackAdvisor.minimumPriorStrengthSessions
            ),
            .returner
        )
    }

    func testHistoryWithLongGapIsReturner() {
        XCTAssertEqual(
            ExperienceTrackResolver.trackFromHistory(
                gapDaysSinceLastStrengthSession: 400,
                priorStrengthSessionCount: 10
            ),
            .returner
        )
    }
}
