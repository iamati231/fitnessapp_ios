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

    // MARK: - asExperienceLevel — Fix "doppeltes Onboarding"

    func testStarterAndReturnerMapToBeginner() {
        XCTAssertEqual(ExperienceTrack.starter.asExperienceLevel, .beginner)
        XCTAssertEqual(ExperienceTrack.returner.asExperienceLevel, .beginner)
    }

    func testExperiencedMapsToIntermediateNotAdvanced() {
        XCTAssertEqual(ExperienceTrack.experienced.asExperienceLevel, .intermediate)
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

    // MARK: - templateScoreBonus — UX-Fix "Empfehlung wirkt immer gleich"

    private func template(_ id: String) -> ProgramTemplate {
        guard let found = ProgramTemplates.all.first(where: { $0.id == id }) else {
            fatalError("Template \(id) not found — ProgramTemplates.all changed?")
        }
        return found
    }

    func testStarterAndReturnerNeverGetABonus() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .beginner, preferredDays: 5, environment: .gym)
        let splitPlan = template("bro_split") // 5 Tage, .advanced-getaggt — wuerde fuer Erfahrene bonifiziert
        XCTAssertEqual(ExperienceTrack.starter.templateScoreBonus(template: splitPlan, answers: answers), 0)
        XCTAssertEqual(ExperienceTrack.returner.templateScoreBonus(template: splitPlan, answers: answers), 0)
    }

    func testExperiencedGetsNoBonusWithoutGoalMatch() {
        let answers = QuizAnswers(goal: .weightLoss, experience: .intermediate, preferredDays: 5, environment: .gym)
        let splitPlan = template("bro_split") // targetGoals: [.hypertrophy], trifft .weightLoss nicht
        XCTAssertEqual(ExperienceTrack.experienced.templateScoreBonus(template: splitPlan, answers: answers), 0,
                       "Kein Bonus ohne Ziel-Match — sonst waere es ein blinder Experten-Boost")
    }

    /// 3-Tage-Plaene bekommen auch bei Ziel-Match keinen Frequenz-Bonus —
    /// das ist die Grenze zwischen Ganzkoerper/Grundlagen und echtem Split
    /// in dieser Bibliothek; bei 2-3 Tagen darf Ganzkoerper fuer Erfahrene
    /// weiterhin plausibel bleiben (Epic-Vorgabe).
    func testNoFrequencyBonusAtThreeDaysOrFewer() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .intermediate, preferredDays: 3, environment: .gym)
        let fullBody = template("full_body") // 3 Tage, targetGoals enthaelt .hypertrophy
        XCTAssertEqual(ExperienceTrack.experienced.templateScoreBonus(template: fullBody, answers: answers), 0)
    }

    /// Frequenz-/Split-Bonus skaliert mit Tagen oberhalb 3 — ein 5-Tage-Split
    /// bekommt mehr als ein 4-Tage-Split.
    func testFrequencyBonusScalesWithDaysAboveThree() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .intermediate, preferredDays: 5, environment: .gym)
        let upperLower = template("upper_lower")   // 4 Tage, [.intermediate, .advanced]
        let broSplit = template("bro_split")       // 5 Tage, [.intermediate, .advanced]
        let upperLowerBonus = ExperienceTrack.experienced.templateScoreBonus(template: upperLower, answers: answers)
        let broSplitBonus = ExperienceTrack.experienced.templateScoreBonus(template: broSplit, answers: answers)
        XCTAssertEqual(upperLowerBonus, 2, "4 Tage: +1 Frequenz, +1 .advanced-Tag")
        XCTAssertEqual(broSplitBonus, 3, "5 Tage: +2 Frequenz, +1 .advanced-Tag")
        XCTAssertGreaterThan(broSplitBonus, upperLowerBonus)
    }

    /// Ein rein `.advanced`-getaggtes Template bekommt den Tag-Bonus
    /// zusaetzlich zum Frequenz-Bonus — ohne ihn wuerde Arnold Split beim
    /// Basis-Score-Term "Level" leer ausgehen (Erfahrene mappen auf
    /// `.intermediate`, nie `.advanced`, siehe `asExperienceLevel`).
    func testAdvancedTagAddsBonusOnTopOfFrequency() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .intermediate, preferredDays: 6, environment: .gym)
        let arnoldSplit = template("arnold_split") // 6 Tage, [.advanced] exklusiv
        XCTAssertEqual(ExperienceTrack.experienced.templateScoreBonus(template: arnoldSplit, answers: answers), 4,
                       "6 Tage: +3 Frequenz, +1 .advanced-Tag")
    }
}
