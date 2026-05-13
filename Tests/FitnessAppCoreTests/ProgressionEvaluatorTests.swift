import XCTest
@testable import FitnessAppCore

/// Tests fuer DEL-052 + DEL-053 Smart Auto-Progression.
final class ProgressionEvaluatorTests: XCTestCase {

    // MARK: - DEL-052 Double-Progression Basics

    /// Klassischer Progressions-Trigger: alle Saetze auf Upper Limit + RIR
    /// im erlaubten Bereich → increase.
    func testIncreaseWhenAllSetsHitUpperWithCleanRIR() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 1),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 1),
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 1)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .increaseWeight(by: 2.5))
    }

    /// Ein Satz unter Upper Limit → HOLD (User soll naechstes Mal alle Reps
    /// schaffen, BEVOR das Gewicht steigt).
    func testHoldWhenAtLeastOneSetMissedUpperLimit() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 1),
            ProgressionInputSet(setIndex: 1, reps: 11, rir: 0),
            ProgressionInputSet(setIndex: 2, reps: 10, rir: 0)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .hold)
    }

    /// User schafft die untere Rep-Grenze nicht UND ging trotzdem zum
    /// Versagen → Deload-Signal.
    func testDeloadWhenLowerLimitMissedAtFailure() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 8, rir: 0),
            ProgressionInputSet(setIndex: 1, reps: 6, rir: 0),
            ProgressionInputSet(setIndex: 2, reps: 5, rir: 0)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .deload(by: 2.5))
    }

    // MARK: - DEL-053 Compound vs. Isolation

    /// Compound mit RIR 2: laut Prose soll Progression triggern (Compound
    /// erlaubt bis RIR 3).
    func testCompoundProgressesAtRIR2() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 10, rir: 2),
            ProgressionInputSet(setIndex: 1, reps: 10, rir: 2),
            ProgressionInputSet(setIndex: 2, reps: 10, rir: 2)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...10,
            isCompound: true,
            incrementStep: 5.0
        )
        XCTAssertEqual(action, .increaseWeight(by: 5.0))
    }

    /// Compound mit RIR 4: zu viel Puffer, HOLD.
    func testCompoundHoldsWhenRIRTooHigh() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 10, rir: 4),
            ProgressionInputSet(setIndex: 1, reps: 10, rir: 4),
            ProgressionInputSet(setIndex: 2, reps: 10, rir: 4)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...10,
            isCompound: true,
            incrementStep: 5.0
        )
        XCTAssertEqual(action, .hold)
    }

    /// Isolation mit RIR 2: laut Prose-Beispiel "Da ging noch mehr!" → HOLD,
    /// User soll naechstes Mal naeher ans Versagen.
    func testIsolationHoldsAtRIR2() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 2)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .hold)
    }

    /// Isolation mit RIR 1: nah am Versagen, Progression triggert.
    func testIsolationProgressesAtRIR1() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 1),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 1),
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 1)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            isCompound: false,
            incrementStep: 1.25
        )
        XCTAssertEqual(action, .increaseWeight(by: 1.25))
    }

    // MARK: - User Override

    /// User-Override "RIR <= 2" zwingt Isolation strenger zu sein als der
    /// Default. RIR 2 erlaubt jetzt Progression auch bei Isolation.
    func testUserOverrideRelaxesIsolation() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 2),
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 2)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
            isCompound: false,
            incrementStep: 2.5,
            targetRIROverride: 2
        )
        XCTAssertEqual(action, .increaseWeight(by: 2.5))
    }

    /// User-Override "RIR <= 0" zwingt Compound naeher ans Versagen — RIR 2
    /// triggert keine Progression mehr.
    func testUserOverrideStrictensCompound() {
        let sets = [
            ProgressionInputSet(setIndex: 0, reps: 10, rir: 2),
            ProgressionInputSet(setIndex: 1, reps: 10, rir: 2),
            ProgressionInputSet(setIndex: 2, reps: 10, rir: 2)
        ]
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...10,
            isCompound: true,
            incrementStep: 5.0,
            targetRIROverride: 0
        )
        XCTAssertEqual(action, .hold)
    }

    // MARK: - Edge Cases

    /// Leere Set-Liste → HOLD (defensive, kein Crash).
    func testEmptySetsReturnsHold() {
        let action = ProgressionEvaluator.evaluate(
            loggedSets: [],
            targetRepsRange: 8...12,
            isCompound: false,
            incrementStep: 2.5
        )
        XCTAssertEqual(action, .hold)
    }

    /// Auswertung sortiert via `setIndex` — egal in welcher Reihenfolge die
    /// Logs ankommen, der letzte Satz (hoechster Index) bestimmt den RIR.
    func testSortingByOrderIndex() {
        // Bewusst durcheinander angeliefert.
        let sets = [
            ProgressionInputSet(setIndex: 2, reps: 12, rir: 1),
            ProgressionInputSet(setIndex: 0, reps: 12, rir: 0),
            ProgressionInputSet(setIndex: 1, reps: 12, rir: 0)
        ]
        // Letzter Satz (index 2) hatte RIR 1 — Isolation darf da progressen.
        let action = ProgressionEvaluator.evaluate(
            loggedSets: sets,
            targetRepsRange: 8...12,
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
