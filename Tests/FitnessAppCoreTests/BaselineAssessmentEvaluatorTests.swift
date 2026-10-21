import XCTest
@testable import FitnessAppCore

/// Deckt die Core-Pflichttests aus dem Start-Check-Epic ab, soweit sie ohne
/// SwiftData/UI pruefbar sind (1, 3, 4, 5, 6, 7). Persistenz-Roundtrip (2)
/// und Backward-Compatibility (8) leben in `FitnessAppDataTests`;
/// Lokalisierung/Build (9) ist kein Unit-Test.
final class BaselineAssessmentEvaluatorTests: XCTestCase {

    private func makeAssessment(
        safetyStatus: SafetyStatus = .clear,
        pushUp: PushUpAssessment? = nil,
        chairSquat: ChairSquatAssessment? = nil,
        pull: PullAssessment? = nil,
        plank: PlankAssessment? = nil,
        cardio: CardioBaseline? = nil,
        pushSelfAssessment: SelfAssessmentAnswer? = nil,
        legsSelfAssessment: SelfAssessmentAnswer? = nil,
        pullSelfAssessment: SelfAssessmentAnswer? = nil
    ) -> BaselineAssessment {
        BaselineAssessment(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            source: .guidedTest,
            safetyStatus: safetyStatus,
            pushUp: pushUp,
            chairSquat: chairSquat,
            pull: pull,
            plank: plank,
            cardio: cardio,
            pushSelfAssessment: pushSelfAssessment,
            legsSelfAssessment: legsSelfAssessment,
            pullSelfAssessment: pullSelfAssessment
        )
    }

    // MARK: Test 1 — Leere/teilweise Baseline ergibt unknown, kein Crash

    func testCompletelyEmptyAssessmentYieldsAllUnknown() {
        let bands = BaselineAssessmentEvaluator.evaluate(makeAssessment())
        XCTAssertEqual(bands.push, .unknown)
        XCTAssertEqual(bands.legs, .unknown)
        XCTAssertEqual(bands.pull, .unknown)
        XCTAssertEqual(bands.core, .unknown)
        XCTAssertEqual(bands.cardio, .unknown)
    }

    func testPartiallyFilledAssessmentOnlyBandsTheFilledFamilies() {
        let assessment = makeAssessment(pushUp: PushUpAssessment(variant: .standard, cleanReps: 20))
        let bands = BaselineAssessmentEvaluator.evaluate(assessment)
        XCTAssertEqual(bands.push, .high)
        XCTAssertEqual(bands.legs, .unknown)
        XCTAssertEqual(bands.pull, .unknown)
        XCTAssertEqual(bands.core, .unknown)
        XCTAssertEqual(bands.cardio, .unknown)
    }

    // MARK: Test 3 — Schmerz/Unsicher sperrt den Test, konservative Empfehlung

    func testFlaggedSafetyStatusForcesVeryLowEverywhereRegardlessOfTestData() {
        // Selbst mit (hypothetisch vorhandenen) starken Testwerten darf ein
        // geflaggter Sicherheitsstatus niemals durchscheinen.
        let assessment = makeAssessment(
            safetyStatus: .flagged,
            pushUp: PushUpAssessment(variant: .standard, cleanReps: 30),
            chairSquat: ChairSquatAssessment(cleanReps: 20, durationSeconds: 30),
            pull: PullAssessment(variant: .pullUp, cleanReps: 10),
            plank: PlankAssessment(seconds: 60),
            cardio: CardioBaseline(answer: .runsRegularly)
        )
        let bands = BaselineAssessmentEvaluator.evaluate(assessment)
        XCTAssertEqual(bands.push, .veryLow)
        XCTAssertEqual(bands.legs, .veryLow)
        XCTAssertEqual(bands.pull, .veryLow)
        XCTAssertEqual(bands.core, .veryLow)
        XCTAssertEqual(bands.cardio, .veryLow)
    }

    // MARK: Test 4 — Ein niedriger Push-Score veraendert nur Push

    func testLowPushUpScoreDoesNotAffectOtherFamilies() {
        let assessment = makeAssessment(
            pushUp: PushUpAssessment(variant: .noCleanRep, cleanReps: 0),
            chairSquat: ChairSquatAssessment(cleanReps: 20, durationSeconds: 30),
            pull: PullAssessment(variant: .pullUp, cleanReps: 10),
            plank: PlankAssessment(seconds: 55)
        )
        let bands = BaselineAssessmentEvaluator.evaluate(assessment)
        XCTAssertEqual(bands.push, .veryLow)
        XCTAssertEqual(bands.legs, .high, "Beine duerfen vom schlechten Push-Wert nicht herabgezogen werden")
        XCTAssertEqual(bands.pull, .high, "Pull duerfen vom schlechten Push-Wert nicht herabgezogen werden")
        XCTAssertEqual(bands.core, .high, "Core duerfen vom schlechten Push-Wert nicht herabgezogen werden")
    }

    /// Umgekehrte Richtung: ein niedriger Klimmzugwert senkt nicht den
    /// gesamten Plan (Epic, woertlich).
    func testLowPullScoreDoesNotAffectPushOrLegs() {
        let assessment = makeAssessment(
            pushUp: PushUpAssessment(variant: .standard, cleanReps: 25),
            chairSquat: ChairSquatAssessment(cleanReps: 18, durationSeconds: 30),
            pull: PullAssessment(variant: .pullUp, cleanReps: 0)
        )
        let bands = BaselineAssessmentEvaluator.evaluate(assessment)
        XCTAssertEqual(bands.pull, .veryLow)
        XCTAssertEqual(bands.push, .high)
        XCTAssertEqual(bands.legs, .high)
    }

    // MARK: Test 5 — Hohe Werte stufen nicht automatisch zum Experten hoch

    /// `BaselineBands`/`BaselineBand` haben strukturell kein ExperienceTrack-
    /// Feld und der Evaluator nimmt keins entgegen — ein hohes Ergebnis kann
    /// also gar nicht auf `ExperienceTrack` einwirken. Dieser Test
    /// dokumentiert das Verhalten end-to-end ueber die oeffentliche API.
    func testHighResultsAcrossAllFamiliesStayWithinBaselineBandsType() {
        let assessment = makeAssessment(
            pushUp: PushUpAssessment(variant: .standard, cleanReps: 40),
            chairSquat: ChairSquatAssessment(cleanReps: 25, durationSeconds: 30),
            pull: PullAssessment(variant: .pullUp, cleanReps: 15),
            plank: PlankAssessment(seconds: 60),
            cardio: CardioBaseline(answer: .runsRegularly)
        )
        let bands = BaselineAssessmentEvaluator.evaluate(assessment)
        XCTAssertEqual(bands.push, .high)
        XCTAssertEqual(bands.legs, .high)
        XCTAssertEqual(bands.pull, .high)
        XCTAssertEqual(bands.core, .high)
        XCTAssertEqual(bands.cardio, .high)
        // `BaselineBands` ist der komplette Rueckgabetyp von `evaluate` — er
        // traegt per Deklaration kein `experienceTrack`-Feld (siehe
        // BaselineBand.swift). Es gibt keinen Code-Pfad, ueber den ein
        // Testergebnis einen Track setzen koennte.
    }

    // MARK: Test 6 — Keine automatische Erhoehung der Startlast

    /// `PullAssessment.loadKg`/`.rir` fliessen nur in die Band-Herleitung
    /// ein (relatives Signal), NIE in eine zurueckgegebene Last — der
    /// Rueckgabetyp `BaselineBand` ist eine reine Kategorie ohne
    /// Gewichtsfeld. Dieser Test belegt, dass unterschiedliche `loadKg`-
    /// Werte bei gleichem RIR zum GLEICHEN Band fuehren (das Gewicht selbst
    /// hat keinen Einfluss).
    func testLatPulldownBandDependsOnlyOnRirNeverOnTheLoadItself() {
        let lightLoad = makeAssessment(pull: PullAssessment(variant: .latPulldown, cleanReps: 10, loadKg: 20, rir: 2))
        let heavyLoad = makeAssessment(pull: PullAssessment(variant: .latPulldown, cleanReps: 10, loadKg: 80, rir: 2))
        let lightBand = BaselineAssessmentEvaluator.evaluate(lightLoad).pull
        let heavyBand = BaselineAssessmentEvaluator.evaluate(heavyLoad).pull
        XCTAssertEqual(lightBand, heavyBand, "Das Gewicht selbst darf das Band nicht beeinflussen, nur RIR")
        XCTAssertEqual(lightBand, .moderate)
    }

    func testLatPulldownWithoutRirIsUnknownNotGuessed() {
        let assessment = makeAssessment(pull: PullAssessment(variant: .latPulldown, cleanReps: 10, loadKg: 40, rir: nil))
        XCTAssertEqual(BaselineAssessmentEvaluator.evaluate(assessment).pull, .unknown)
    }

    // MARK: Selbsteinschaetzung als Fallback

    func testSelfAssessmentIsUsedOnlyWhenNoGuidedTestExists() {
        let selfOnly = makeAssessment(pushSelfAssessment: .easy)
        XCTAssertEqual(BaselineAssessmentEvaluator.evaluate(selfOnly).push, .high)

        // Liegt zusaetzlich ein echter Test vor, hat der Test Vorrang.
        let bothPresent = makeAssessment(
            pushUp: PushUpAssessment(variant: .noCleanRep, cleanReps: 0),
            pushSelfAssessment: .easy
        )
        XCTAssertEqual(BaselineAssessmentEvaluator.evaluate(bothPresent).push, .veryLow)
    }

    func testSkippedSelfAssessmentIsUnknownNotVeryLow() {
        let assessment = makeAssessment(legsSelfAssessment: .skipped)
        XCTAssertEqual(BaselineAssessmentEvaluator.evaluate(assessment).legs, .unknown)
    }

    // MARK: Grenzwerte (dokumentieren die CoachConstants-Schwellen)

    func testPushUpBandThresholds() {
        XCTAssertEqual(band(pushUpReps: 0), .veryLow)
        XCTAssertEqual(band(pushUpReps: 4), .low)
        XCTAssertEqual(band(pushUpReps: 5), .moderate)
        XCTAssertEqual(band(pushUpReps: 14), .moderate)
        XCTAssertEqual(band(pushUpReps: 15), .high)
    }

    private func band(pushUpReps: Int) -> BaselineBand {
        BaselineAssessmentEvaluator.evaluate(
            makeAssessment(pushUp: PushUpAssessment(variant: .standard, cleanReps: pushUpReps))
        ).push
    }

    func testPlankCapAtSixtySecondsStillBandsAsHigh() {
        let assessment = makeAssessment(plank: PlankAssessment(seconds: 60))
        XCTAssertEqual(BaselineAssessmentEvaluator.evaluate(assessment).core, .high)
    }
}
