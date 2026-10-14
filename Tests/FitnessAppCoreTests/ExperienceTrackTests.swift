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

    /// Plan-Katalog-Audit Befund 5: der fruehere pauschale Tage-Bonus
    /// (`max(0, daysPerWeek - 3)`) ist entfernt — Tage-Anzahl allein
    /// beeinflusst `templateScoreBonus` nicht mehr, unabhaengig davon wie
    /// viele Tage ein nicht-advanced-getaggtes Template hat. Der bestehende
    /// Basis-Score-Term "exakte Tage" (+1 in `PlanMatchmaker.rankPlans`)
    /// deckt die Tages-Praeferenz bereits ab.
    func testNonAdvancedTemplateGetsNoBonusRegardlessOfDays() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .intermediate, preferredDays: 5, environment: .gym)
        let fullBody = template("full_body") // 3 Tage, [.beginner, .intermediate]
        XCTAssertEqual(ExperienceTrack.experienced.templateScoreBonus(template: fullBody, answers: answers), 0,
                       "full_body traegt kein .advanced-Tag, also kein Bonus unabhaengig von der Tagesanzahl")
    }

    /// Fix "Szenario 8" (PLAN_MATCHING_AND_EQUIPMENT_COMBINED.md): ein
    /// Template, das `.intermediate` BEREITS traegt (auch wenn zusaetzlich
    /// `.advanced` dabeisteht), bekommt KEINEN Bonus mehr — der Basis-Score-
    /// Term "Level" (+2) hat es dafuer schon vollstaendig kreditiert. Die
    /// vorige Fassung gab hier faelschlich trotzdem +1, wodurch z.B.
    /// `crossfit_weighted` (`[.beginner, .intermediate, .advanced]`) jedem
    /// Erfahrenen einen unbegruendeten Vorsprung vor inhaltlich passenderen,
    /// nur `.intermediate`/`.advanced`-getaggten Kraft-Splits bekam.
    func testTemplateAlreadyTaggedWithUsersLevelGetsNoAdvancedBonus() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .intermediate, preferredDays: 6, environment: .gym)
        let upperLower = template("upper_lower")           // [.intermediate, .advanced]
        let broSplit = template("bro_split")               // [.intermediate, .advanced]
        let crossfitWeighted = template("crossfit_weighted") // [.beginner, .intermediate, .advanced]
        XCTAssertEqual(ExperienceTrack.experienced.templateScoreBonus(template: upperLower, answers: answers), 0,
                       "traegt bereits .intermediate, Level-Term ist schon +2")
        XCTAssertEqual(ExperienceTrack.experienced.templateScoreBonus(template: broSplit, answers: answers), 0)
        XCTAssertEqual(ExperienceTrack.experienced.templateScoreBonus(template: crossfitWeighted, answers: answers), 0,
                       "Szenario-8-Regression: durfte frueher faelschlich +1 bekommen")
    }

    /// Ein REIN `.advanced`-getaggtes Template (ohne `.intermediate`/
    /// `.beginner`) bekommt weiterhin den Ausgleichs-Bonus — ohne ihn wuerde
    /// es beim Level-Term leer ausgehen, weil Erfahrene ueber
    /// `asExperienceLevel` nie auf `.advanced` mappen.
    func testPurelyAdvancedTemplateStillGetsCompensatingBonus() {
        let answers = QuizAnswers(goal: .hypertrophy, experience: .intermediate, preferredDays: 6, environment: .gym)
        let arnoldSplit = template("arnold_split") // [.advanced] exklusiv
        XCTAssertEqual(ExperienceTrack.experienced.templateScoreBonus(template: arnoldSplit, answers: answers), 1,
                       "Ohne .intermediate/.beginner im Tag bleibt der Level-Term sonst leer")
    }
}
