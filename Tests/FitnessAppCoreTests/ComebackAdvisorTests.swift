import XCTest
@testable import FitnessAppCore

/// DEL-235: Diese Regeln greifen in die Arbeitsgewichte des Nutzers ein. Ein
/// Fehler hier ist entweder Bevormundung (reduziert, wo niemand es wollte)
/// oder ein Dauerzustand (kommt nie wieder hoch).
final class ComebackAdvisorTests: XCTestCase {

    // MARK: Schwelle

    func testDefaultThresholdIsFourteenDays() {
        XCTAssertEqual(ComebackAdvisor.gapThresholdDays(medianGapOfLastSessions: nil), 14)
        XCTAssertEqual(ComebackAdvisor.minimumGapDays, 14)
    }

    /// Wer taeglich trainiert, soll nicht schon nach vier Tagen reduziert
    /// bekommen — die Untergrenze gewinnt.
    func testFrequentTrainerStillGetsFourteenDayFloor() {
        XCTAssertEqual(ComebackAdvisor.gapThresholdDays(medianGapOfLastSessions: 1.5), 14)
        XCTAssertEqual(ComebackAdvisor.gapThresholdDays(medianGapOfLastSessions: 3), 14)
    }

    /// Wer ohnehin nur alle zwei Wochen trainiert, hat bei 20 Tagen keinen
    /// Bruch in der Gewohnheit.
    func testInfrequentTrainerGetsHigherThreshold() {
        XCTAssertEqual(ComebackAdvisor.gapThresholdDays(medianGapOfLastSessions: 8), 20)
        XCTAssertEqual(ComebackAdvisor.gapThresholdDays(medianGapOfLastSessions: 14), 35)
    }

    func testZeroOrNegativeMedianFallsBackToFloor() {
        XCTAssertEqual(ComebackAdvisor.gapThresholdDays(medianGapOfLastSessions: 0), 14)
        XCTAssertEqual(ComebackAdvisor.gapThresholdDays(medianGapOfLastSessions: -5), 14)
    }

    // MARK: Auslöser

    func testShortGapNeverSuggests() {
        for gap in [0, 5, 10, 13] {
            XCTAssertFalse(
                ComebackAdvisor.shouldSuggest(gapDays: gap, medianGap: 2, priorStrengthSessionCount: 12),
                "\(gap) Tage duerfen nichts ausloesen"
            )
        }
    }

    func testLongGapWithHistorySuggests() {
        XCTAssertTrue(
            ComebackAdvisor.shouldSuggest(gapDays: 21, medianGap: 2, priorStrengthSessionCount: 10)
        )
    }

    /// Ein echter Anfaenger braucht keinen Wiedereinstieg, sondern einen
    /// Einstieg — es gibt keine Last, von der man reduzieren koennte.
    ///
    /// DEL-240: Die Zahl kommt aus der GESAMTEN Historie. Vorher wurden die
    /// 28 Tage vor der Pause gezaehlt, was "Anfaenger" mit "hatte letzten
    /// Monat wenig Zeit" verwechselte.
    func testNoSuggestionWithoutPriorRegularity() {
        XCTAssertFalse(
            ComebackAdvisor.shouldSuggest(gapDays: 40, medianGap: nil, priorStrengthSessionCount: 2)
        )
        XCTAssertTrue(
            ComebackAdvisor.shouldSuggest(gapDays: 40, medianGap: nil, priorStrengthSessionCount: 3),
            "genau 3 Sessions reichen"
        )
    }

    /// DEL-240-Regression: der real gemeldete Fall. Eine Kraft-Session am 9.,
    /// danach nur Laeufe, heute der 29. — 20 Tage Luecke. Die Frage MUSS
    /// kommen, sobald ueberhaupt eine trainierte Historie existiert. Die alte
    /// Regel (28-Tage-Fenster vor der Pause) hat sie verschluckt.
    func testTwentyDayGapAfterQuietMonthStillSuggests() {
        XCTAssertTrue(ComebackAdvisor.shouldSuggest(
            gapDays: 20,
            medianGap: nil,          // nur eine Kraft-Session im letzten Monat
            priorStrengthSessionCount: 12   // aber 12 in der Historie
        ))
    }

    /// Nach einer Ablehnung nicht nachbohren — erst eine deutlich laengere
    /// Pause fragt erneut.
    func testSuppressionBlocksUntilLongerGap() {
        XCTAssertFalse(ComebackAdvisor.shouldSuggest(
            gapDays: 20, medianGap: 2, priorStrengthSessionCount: 10, suppressedUntilGapDays: 20
        ))
        XCTAssertFalse(ComebackAdvisor.shouldSuggest(
            gapDays: 18, medianGap: 2, priorStrengthSessionCount: 10, suppressedUntilGapDays: 20
        ))
        XCTAssertTrue(ComebackAdvisor.shouldSuggest(
            gapDays: 45, medianGap: 2, priorStrengthSessionCount: 10, suppressedUntilGapDays: 20
        ))
    }

    // MARK: Verordnung

    func testNoPrescriptionBelowThreshold() {
        XCTAssertEqual(ComebackAdvisor.prescription(forGapDays: 13), .none)
        XCTAssertEqual(ComebackAdvisor.prescription(forGapDays: 0), .none)
    }

    /// Der wichtigste Einzelwert: im haeufigsten Bucket muss ueberhaupt etwas
    /// passieren, sonst ist das Feature dort wirkungslos.
    func testTwoWeekGapProducesVisibleReduction() {
        let p = ComebackAdvisor.prescription(forGapDays: 16)
        XCTAssertEqual(p.compoundFactor, 0.95, accuracy: 0.0001)
        // 100 kg -> 95 kg ist auf jedem Raster darstellbar.
        XCTAssertLessThanOrEqual(100 * p.compoundFactor, 95.0)
    }

    /// Isolation darf nie staerker reduziert werden als Compound.
    func testIsolationIsNeverReducedMoreThanCompound() {
        for gap in [14, 20, 21, 29, 30, 59, 60, 89, 90, 179, 200, 400] {
            let p = ComebackAdvisor.prescription(forGapDays: gap)
            XCTAssertGreaterThanOrEqual(
                p.isolationFactor, p.compoundFactor,
                "bei \(gap) Tagen ist Isolation staerker reduziert als Compound"
            )
        }
    }

    /// Laengere Pause darf nie zu WENIGER Reduktion fuehren (bis zur
    /// Retest-Grenze).
    func testReductionIsMonotonicUpToRetest() {
        var previous = 1.01
        for gap in [14, 21, 30, 60, 90] {
            let p = ComebackAdvisor.prescription(forGapDays: gap)
            XCTAssertLessThan(p.compoundFactor, previous, "bei \(gap) Tagen nicht monoton")
            previous = p.compoundFactor
        }
    }

    /// Ab einem halben Jahr kein geschaetzter Faktor, sondern ein Wiedertest —
    /// die alte Last ist keine belastbare Referenz mehr.
    func testVeryLongGapAsksForRetestInsteadOfGuessing() {
        let p = ComebackAdvisor.prescription(forGapDays: 200)
        XCTAssertTrue(p.needsRetest)
        XCTAssertEqual(p.compoundFactor, 1.0, accuracy: 0.0001)
        XCTAssertEqual(p.isolationFactor, 1.0, accuracy: 0.0001)
    }

    // MARK: - DEL-241 Isolation milder

    /// Der abgeleitete Isolations-Faktor MUSS die Verordnungs-Tabelle
    /// reproduzieren — sonst laufen Tabelle und Ableiter auseinander und der
    /// Nutzer bekommt je nach Pfad andere Zahlen.
    func testIsolationFactorMatchesPrescriptionTable() {
        for gap in [14, 20, 21, 29, 30, 59, 60, 89, 90, 179] {
            let p = ComebackAdvisor.prescription(forGapDays: gap)
            XCTAssertEqual(
                ComebackAdvisor.isolationFactor(forCompoundFactor: p.compoundFactor),
                p.isolationFactor,
                accuracy: 0.0001,
                "bei \(gap) Tagen weicht der Ableiter von der Tabelle ab"
            )
        }
    }

    /// Auch fuer eine frei gewaehlte Stufe: Verbund minus 15 % bedeutet
    /// Isolation minus 10 %.
    func testIsolationGetsFivePointsLessForCustomChoice() {
        XCTAssertEqual(ComebackAdvisor.isolationFactor(forCompoundFactor: 0.85), 0.90, accuracy: 0.0001)
        XCTAssertEqual(ComebackAdvisor.isolationFactor(forCompoundFactor: 0.70), 0.75, accuracy: 0.0001)
    }

    /// Bei minus 5 % bleibt Isolation unangetastet — weniger als eine Scheibe
    /// waere nicht darstellbar.
    func testSmallestReductionLeavesIsolationAlone() {
        XCTAssertEqual(ComebackAdvisor.isolationFactor(forCompoundFactor: 0.95), 1.0, accuracy: 0.0001)
        XCTAssertEqual(ComebackAdvisor.isolationFactor(forCompoundFactor: 1.0), 1.0, accuracy: 0.0001)
    }

    func testFactorPicksTheRightAxisPerExercise() {
        XCTAssertEqual(
            ComebackAdvisor.factor(forCompoundFactor: 0.85, isCompound: true), 0.85, accuracy: 0.0001
        )
        XCTAssertEqual(
            ComebackAdvisor.factor(forCompoundFactor: 0.85, isCompound: false), 0.90, accuracy: 0.0001
        )
    }

    /// Isolation darf nie STAERKER reduziert werden als Verbund.
    func testIsolationIsNeverReducedMoreThanCompoundForAnyChoice() {
        for reduction in ComebackAdvisor.selectableReductions {
            let compound = 1.0 - reduction
            XCTAssertGreaterThanOrEqual(
                ComebackAdvisor.isolationFactor(forCompoundFactor: compound), compound,
                "bei -\(Int(reduction * 100)) % ist Isolation staerker reduziert"
            )
        }
    }

    // MARK: - DEL-241 Ablehnung

    /// Der gemeldete Fall: abgelehnt bei 20 Tagen. Am naechsten Tag darf NICHT
    /// erneut gefragt werden — die alte Regel (gapDays <= declined) hat genau
    /// das getan, weil die Luecke waechst.
    func testDeclineIsNotReAskedTheNextDay() {
        XCTAssertTrue(ComebackAdvisor.isSuppressed(gapDays: 20, declinedAtGapDays: 20))
        XCTAssertTrue(ComebackAdvisor.isSuppressed(gapDays: 21 - 1, declinedAtGapDays: 20))
        // 14...20 ist eine Stufe: innerhalb bleibt es unterdrueckt.
        XCTAssertTrue(ComebackAdvisor.isSuppressed(gapDays: 16, declinedAtGapDays: 20))
    }

    /// Erreicht die Pause eine STAERKERE Stufe, wird erneut gefragt.
    func testStrongerBucketReArmsTheQuestion() {
        // 20 Tage = -5 %, 21 Tage = -10 % -> neue Aussage, also fragen.
        XCTAssertFalse(ComebackAdvisor.isSuppressed(gapDays: 21, declinedAtGapDays: 20))
        XCTAssertFalse(ComebackAdvisor.isSuppressed(gapDays: 60, declinedAtGapDays: 20))
    }

    /// Der Wiedertest-Hinweis ist eine andere Aussage als ein Faktor und darf
    /// eine frueher abgelehnte Reduktion ueberstimmen.
    func testRetestAdviceOverridesAnEarlierDecline() {
        XCTAssertFalse(ComebackAdvisor.isSuppressed(gapDays: 200, declinedAtGapDays: 100))
    }

    /// Und die Kombination in shouldSuggest.
    func testSuggestRespectsBucketBasedSuppression() {
        XCTAssertFalse(ComebackAdvisor.shouldSuggest(
            gapDays: 18, medianGap: 2, priorStrengthSessionCount: 10, suppressedUntilGapDays: 20
        ))
        XCTAssertTrue(ComebackAdvisor.shouldSuggest(
            gapDays: 25, medianGap: 2, priorStrengthSessionCount: 10, suppressedUntilGapDays: 20
        ))
    }

    // MARK: - DEL-239 Rasterung und Auswahl

    func testReductionSnapsDownToIncrement() {
        XCTAssertEqual(ComebackAdvisor.reducedWeight(current: 100, factor: 0.85, increment: 2.5), 85.0, accuracy: 0.0001)
        XCTAssertEqual(ComebackAdvisor.reducedWeight(current: 100, factor: 0.95, increment: 2.5), 95.0, accuracy: 0.0001)
        // 62,5 * 0,85 = 53,125 -> ABWAERTS auf 52,5, nicht auf 53,75.
        XCTAssertEqual(ComebackAdvisor.reducedWeight(current: 62.5, factor: 0.85, increment: 2.5), 52.5, accuracy: 0.0001)
        XCTAssertEqual(ComebackAdvisor.reducedWeight(current: 20, factor: 0.90, increment: 1.25), 17.5, accuracy: 0.0001)
    }

    /// "Keine Reduktion" ist eine legitime Wahl und darf nicht in eine
    /// Pseudo-Aenderung umkippen.
    func testFactorAtOrAboveOneLeavesWeightAlone() {
        XCTAssertEqual(ComebackAdvisor.reducedWeight(current: 100, factor: 1.0, increment: 2.5), 100.0)
        XCTAssertEqual(ComebackAdvisor.reducedWeight(current: 100, factor: 1.5, increment: 2.5), 100.0)
    }

    /// Relativer Boden: nie unter die Haelfte des Ausgangsgewichts. Ein
    /// absoluter Boden (wie die 2,5 kg in startDeload) macht aus leichter
    /// Kurzhantel-Arbeit im Extremfall eine Halbierung und greift bei 200 kg nie.
    func testRelativeFloorAtHalfTheWeight() {
        XCTAssertEqual(ComebackAdvisor.reducedWeight(current: 100, factor: 0.2, increment: 2.5), 50.0, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(ComebackAdvisor.reducedWeight(current: 10, factor: 0.3, increment: 2.5), 5.0)
    }

    func testNeverBelowOneIncrement() {
        XCTAssertGreaterThanOrEqual(ComebackAdvisor.reducedWeight(current: 2.5, factor: 0.5, increment: 2.5), 2.5)
    }

    func testDegenerateInputsAreSafe() {
        XCTAssertEqual(ComebackAdvisor.reducedWeight(current: 0, factor: 0.85, increment: 2.5), 0)
        XCTAssertEqual(ComebackAdvisor.reducedWeight(current: 100, factor: 0.85, increment: 0), 100.0)
    }

    func testSelectableReductionsAreFivePercentSteps() {
        XCTAssertEqual(ComebackAdvisor.selectableReductions, [0.05, 0.10, 0.15, 0.20, 0.25, 0.30])
        XCTAssertTrue(ComebackAdvisor.selectableReductions.allSatisfy { $0 > 0 && $0 < 1 })
    }

    /// Jede Empfehlung muss eine WAEHLBARE Stufe sein — sonst kann der Picker
    /// in der Rueckfrage nicht auf der Empfehlung vorbelegt werden.
    func testEveryRecommendationIsSelectable() {
        for gap in [16, 25, 35, 70, 120] {
            let reduction = 1.0 - ComebackAdvisor.prescription(forGapDays: gap).compoundFactor
            XCTAssertTrue(
                ComebackAdvisor.selectableReductions.contains { abs($0 - reduction) < 0.0001 },
                "Empfehlung fuer \(gap) Tage ist keine waehlbare Stufe"
            )
        }
    }

}
