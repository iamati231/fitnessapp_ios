import XCTest
@testable import FitnessAppCore

/// DEL-066: Tests fuer die Section-Sichtbarkeit im ExerciseEditorView.
/// Snapshot-Tests sind ohne SnapshotTesting/ViewInspector-Dependency nicht
/// moeglich — wir testen stattdessen die zentrale pure-Logik, die die View
/// als Single-Source-of-Truth konsumiert.
final class ExerciseEditorSectionsTests: XCTestCase {

    // MARK: - Strength (default)

    func testStrengthExerciseShowsAllStrengthSections() {
        let v = ExerciseEditorSections.evaluate(isCardio: false, isTimeBased: false)
        XCTAssertTrue(v.setsAndReps,        "Strength braucht Saetze/Wdh-Section")
        XCTAssertTrue(v.pauseAndIntensity,  "Strength braucht Pause + RIR")
        XCTAssertTrue(v.targetRIR,          "Strength braucht RIR-Stepper")
        XCTAssertTrue(v.suggestedWeight,    "Strength braucht Suggested-Weight-Feld")
        XCTAssertTrue(v.smartProgression,   "Strength braucht Smart-Progression-Section")
        XCTAssertFalse(v.cardioTargets,     "Strength hat KEINE Cardio-Targets")
    }

    // MARK: - Cardio

    func testCardioExerciseHidesAllStrengthSections() {
        let v = ExerciseEditorSections.evaluate(isCardio: true, isTimeBased: false)
        XCTAssertTrue(v.cardioTargets,      "Cardio MUSS Distanz/Dauer-Section zeigen")
        XCTAssertFalse(v.setsAndReps,       "Cardio hat KEINE Saetze/Wdh")
        XCTAssertFalse(v.pauseAndIntensity, "Cardio hat KEINE Pause/RIR-Section")
        XCTAssertFalse(v.targetRIR,         "Cardio hat KEIN RIR-Tracking")
        XCTAssertFalse(v.suggestedWeight,   "Cardio hat KEIN Gewicht-Tracking")
        XCTAssertFalse(v.smartProgression,  "Cardio wird vom Smart-Progression-Algorithmus geskippt")
    }

    // MARK: - Time-Based

    func testTimeBasedExerciseShowsPauseButHidesRIRAndWeight() {
        let v = ExerciseEditorSections.evaluate(isCardio: false, isTimeBased: true)
        XCTAssertTrue(v.setsAndReps,        "TimeBased zeigt Saetze (mit Sek.-Range)")
        XCTAssertTrue(v.pauseAndIntensity,  "TimeBased zeigt die Pause-Section (Pause zw. Plank-Saetzen)")
        XCTAssertFalse(v.targetRIR,         "TimeBased hat KEINEN RIR-Stepper — Plank misst Sekunden")
        XCTAssertFalse(v.suggestedWeight,   "TimeBased hat KEIN kg-Tracking")
        XCTAssertFalse(v.smartProgression,  "TimeBased wird nicht progressed wie Strength")
        XCTAssertFalse(v.cardioTargets,     "TimeBased ist nicht Cardio")
    }

    // MARK: - Edge: beide Flags true (sollte UI-side verhindert sein)

    /// Wenn beide Flags reinkommen, gewinnt Cardio im Display — matched die
    /// SetRow-Switch-Reihenfolge (Cardio → TimeBased → Strength).
    func testBothFlagsTrueResolvesAsCardio() {
        let v = ExerciseEditorSections.evaluate(isCardio: true, isTimeBased: true)
        XCTAssertTrue(v.cardioTargets)
        XCTAssertFalse(v.pauseAndIntensity)
        XCTAssertFalse(v.setsAndReps)
    }
}
