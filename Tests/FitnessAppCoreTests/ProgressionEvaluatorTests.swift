import XCTest
@testable import FitnessAppCore

/// Tests fuer DEL-052 + DEL-053 + DEL-057 Smart Auto-Progression.
///
/// DEL-057 hat die Semantik der RIR-Schwelle FLIPPED: `lastSet.rir >= threshold`
/// (= User hatte Reserven) triggert Progression. Niedriges RIR (nah am
/// Versagen) → Hold. Plus neues `targetSetCount`-Argument, das einen
/// unterschlagenen Satz verhindert.
final class ProgressionEvaluatorTests: XCTestCase {

    // MARK: - DEL-057 Bug-Fix #1: targetSetCount

    /// User loggt weniger Saetze als der Plan vorsieht → keine Progression,
    /// auch wenn alles auf Upper-Limit war. Verhindert False-Positive durch
    /// "Ich hab nur einen Crash-Set gemacht und der war easy".
    func testProgressionRequiresFullSetCount() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 2)
            // Nur 2 von 3 erwarteten Saetzen.
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .hold)
    }

    // MARK: - DEL-052/057 Double-Progression Basics

    /// Klassischer Progressions-Trigger: alle Saetze auf Upper Limit +
    /// genug Saetze + RIR im sicheren Bereich (>= 1 fuer Isolation).
    func testIncreaseWhenAllSetsHitUpperWithSafeRIR() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 1)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .increaseWeight(by: 2.5))
    }

    /// Ein Satz unter Upper Limit → HOLD.
    func testHoldWhenAtLeastOneSetMissedUpperLimit() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 1),
            ProgressionInputSet(setIndex: 1, reps: 11, rir: 0),
            ProgressionInputSet(setIndex: 2, reps: 10, rir: 0)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .hold)
    }

    /// User schafft die untere Rep-Grenze nicht UND ging zum Versagen
    /// (rir == 0) → Deload-Signal.
    func testDeloadWhenLowerLimitMissedAtFailure() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 8, rir: 0),
            ProgressionInputSet(setIndex: 1, reps: 6, rir: 0),
            ProgressionInputSet(setIndex: 2, reps: 5, rir: 0)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .deload(by: 2.5))
    }

    /// DEL-057 Bug-Fix #3: Wenn der User die untere Rep-Grenze verfehlt,
    /// aber NICHT am Versagen war (rir > 0, also "wollte nicht mehr"),
    /// darf KEIN Deload triggern — nur HOLD. Der User hat einfach
    /// abgebrochen, das Gewicht ist nicht objektiv zu schwer.
    func testHoldWhenLowerLimitMissedButUserStoppedVoluntarily() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 6, rir: 3),   // rir > 0!
            ProgressionInputSet(setIndex: 1, reps: 6, rir: 3),
            ProgressionInputSet(setIndex: 2, reps: 6, rir: 3)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .hold)
    }

    // MARK: - DEL-053/057 Compound vs. Isolation (flipped operator)

    /// Compound mit RIR 2 (genau auf Schwelle) → Progression. User hatte
    /// 2 Reps Reserve = sichere Form, hochladen ist OK.
    func testCompoundProgressesAtRIR2() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 10, rir: 2),
            ProgressionInputSet(setIndex: 1, reps: 10, rir: 2),
            ProgressionInputSet(setIndex: 2, reps: 10, rir: 2)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...10,
            targetSetCount: 3,
            isCompound: true,
            incrementStep: 5.0
        )
        XCTAssertEqual(action, .increaseWeight(by: 5.0))
    }

    /// Compound mit RIR 0 (= zum Versagen geprügelt) → HOLD. Form war
    /// nicht safe genug, naechstes Mal erst sauber durchziehen.
    func testCompoundHoldsAtRIR0BecauseFormUnsafe() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 10, rir: 0),
            ProgressionInputSet(setIndex: 1, reps: 10, rir: 0),
            ProgressionInputSet(setIndex: 2, reps: 10, rir: 0)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...10,
            targetSetCount: 3,
            isCompound: true,
            incrementStep: 5.0
        )
        XCTAssertEqual(action, .hold)
    }

    /// Isolation mit RIR 0 (zum Versagen) → HOLD. Auch fuer Isolation gilt
    /// jetzt: User soll erst die Last sauber bewaeltigen, BEVOR mehr drauf
    /// kommt.
    func testIsolationHoldsAtRIR0() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 0),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 0),
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 0)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .hold)
    }

    /// Isolation mit RIR 1 (genau auf Schwelle) → Progression.
    func testIsolationProgressesAtRIR1() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 1),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 1),
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 1)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 1.25
        )
        XCTAssertEqual(action, .increaseWeight(by: 1.25))
    }

    // MARK: - User Override

    /// User-Override "RIR >= 3" strictert die Schwelle. RIR 2 reicht nicht
    /// mehr → HOLD.
    func testUserOverrideStrictenedThreshold() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 2)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: true,
            incrementStep: 2.5,
            targetRIROverride: 3
        )
        XCTAssertEqual(action, .hold)
    }

    /// User-Override "RIR >= 0" relaxt die Schwelle. Selbst rir==0 reicht
    /// dann fuer Progression — User ist sich der Verletzungs-Gefahr bewusst
    /// und akzeptiert sie.
    func testUserOverrideRelaxedThreshold() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 0),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 0),
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 0)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 2.5,
            targetRIROverride: 0
        )
        XCTAssertEqual(action, .increaseWeight(by: 2.5))
    }

    // MARK: - Edge Cases

    /// Leere Set-Liste → HOLD (defensive, kein Crash).
    func testEmptySetsReturnsHold() {
        let action = ProgressionEvaluator.evaluate(
            loggedSets: [],
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .hold)
    }

    /// Auswertung sortiert via `setIndex` — egal in welcher Reihenfolge die
    /// Logs ankommen, der letzte Satz (hoechster Index) bestimmt den RIR.
    func testSortingByOrderIndex() {
        // Bewusst durcheinander angeliefert. Letzter Satz (index 2) hat
        // rir=2, der reicht fuer Isolation-Progression (>= 1).
        let sets = [
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 0),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 0)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            targetSetCount: 3,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .increaseWeight(by: 2.5))
    }
}

// MARK: - ProgressionStep mapper

final class ProgressionStepTests: XCTestCase {
    func testClosestToStandardValues() {
        XCTAssertEqual(ProgressionStep(closestTo: 1.25), .quarter)
        XCTAssertEqual(ProgressionStep(closestTo: 2.5),  .half)
        XCTAssertEqual(ProgressionStep(closestTo: 5.0),  .full)
    }

    func testClosestToOutOfBandMapsToNearest() {
        XCTAssertEqual(ProgressionStep(closestTo: 1.0),  .quarter)
        XCTAssertEqual(ProgressionStep(closestTo: 3.0),  .half)
        XCTAssertEqual(ProgressionStep(closestTo: 10.0), .full)
    }
}

// MARK: - DEL-057 SessionFeeling

final class SessionFeelingTests: XCTestCase {
    func testHardAndDestroyedVetoProgression() {
        XCTAssertTrue(SessionFeeling.hard.vetoesProgression)
        XCTAssertTrue(SessionFeeling.destroyed.vetoesProgression)
    }

    func testGreatGoodOkayDontVeto() {
        XCTAssertFalse(SessionFeeling.great.vetoesProgression)
        XCTAssertFalse(SessionFeeling.good.vetoesProgression)
        XCTAssertFalse(SessionFeeling.okay.vetoesProgression)
    }

    func testRawValuesAre1Through5() {
        XCTAssertEqual(SessionFeeling.great.rawValue, 1)
        XCTAssertEqual(SessionFeeling.good.rawValue, 2)
        XCTAssertEqual(SessionFeeling.okay.rawValue, 3)
        XCTAssertEqual(SessionFeeling.hard.rawValue, 4)
        XCTAssertEqual(SessionFeeling.destroyed.rawValue, 5)
    }
}
