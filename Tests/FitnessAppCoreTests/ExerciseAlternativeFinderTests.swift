import XCTest
@testable import FitnessAppCore

/// UI-Ticket ("Plan Bauen Schritt 3: Template-Layout und Übungsalternativen").
final class ExerciseAlternativeFinderTests: XCTestCase {

    // MARK: - alternatives(for:equipmentPool:maxExperience:)

    func testAlternativesExcludesTheOriginalExerciseItself() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Bankdrücken", equipmentPool: [.barbell, .dumbbell, .machine], maxExperience: .advanced
        )
        XCTAssertFalse(result.contains { $0.name == "Bankdrücken" })
    }

    func testAlternativesOnlyIncludesTheSameMuscleGroup() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Bankdrücken",
            equipmentPool: [.barbell, .dumbbell, .machine, .bodyweight, .cable, .kettlebell],
            maxExperience: .advanced
        )
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.primaryMuscle == .chest })
    }

    func testAlternativesOnlyIncludesEquipmentFromTheGivenPool() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Bankdrücken", equipmentPool: [.dumbbell], maxExperience: .advanced
        )
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.equipment == .dumbbell })
        XCTAssertTrue(result.contains { $0.name == "Bankdrücken (KH)" })
    }

    func testAlternativesRespectsTheMaximumExperienceLevel() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Plank", equipmentPool: [.bodyweight], maxExperience: .beginner
        )
        XCTAssertTrue(result.contains { $0.name == "Crunches (BW)" })
        XCTAssertFalse(
            result.contains { $0.name == "Dragon Flag" },
            "Dragon Flag ist .advanced, darf bei maxExperience .beginner nicht erscheinen"
        )
    }

    func testAlternativesReturnsEmptyForACardioExercise() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Easy Run", equipmentPool: [.bodyweight], maxExperience: .advanced
        )
        XCTAssertTrue(result.isEmpty, "Cardio-Uebungen duerfen keine Kraft-Alternativen vorschlagen (Trainingsart bleibt gewahrt)")
    }

    func testAlternativesReturnsEmptyForAnUnknownExerciseName() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Ganz Erfundene Testuebung", equipmentPool: [.barbell, .dumbbell], maxExperience: .advanced
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testAlternativesRespectsTheLimit() {
        let result = ExerciseAlternativeFinder.alternatives(
            for: "Bankdrücken",
            equipmentPool: [.barbell, .dumbbell, .machine, .bodyweight, .cable, .kettlebell],
            maxExperience: .advanced,
            limit: 2
        )
        XCTAssertLessThanOrEqual(result.count, 2)
    }

    // MARK: - adjustedSpec(replacing:with:)

    func testAdjustedSpecKeepsOriginalVolumeWhenTimeBasedMatches() {
        let original = ExerciseSpec(name: "Bankdrücken", sets: 4, repsMin: 6, repsMax: 8, restSeconds: 120)
        let target = ExerciseLibraryData.byName["Bankdrücken (KH)"]!

        let adjusted = ExerciseAlternativeFinder.adjustedSpec(replacing: original, with: target)

        XCTAssertEqual(adjusted.name, "Bankdrücken (KH)")
        XCTAssertEqual(adjusted.sets, 4)
        XCTAssertEqual(adjusted.repsMin, 6)
        XCTAssertEqual(adjusted.repsMax, 8)
        XCTAssertEqual(adjusted.restSeconds, 120)
    }

    /// UI-Ticket Punkt 3: Wiederholungen der Original-Uebung duerfen nicht
    /// blind als Sekunden fuer eine neu zeitbasierte Ersatz-Uebung
    /// uebernommen werden.
    func testAdjustedSpecResetsRepsRangeWhenSwitchingFromRepsToTimeBased() {
        let original = ExerciseSpec(name: "Crunches (BW)", sets: 3, repsMin: 15, repsMax: 20, restSeconds: 60)
        let target = ExerciseLibraryData.byName["Plank"]!

        let adjusted = ExerciseAlternativeFinder.adjustedSpec(replacing: original, with: target)

        XCTAssertEqual(adjusted.name, "Plank")
        XCTAssertNotEqual(adjusted.repsMin, 15, "15-20 Wiederholungen duerfen nicht als 15-20 Sekunden Haltezeit uebernommen werden")
        XCTAssertEqual(adjusted.sets, 3, "Saetze bleiben unabhaengig vom Uebungstyp gueltig")
        XCTAssertEqual(adjusted.restSeconds, 60, "Pause bleibt unabhaengig vom Uebungstyp gueltig")
    }

    func testAdjustedSpecResetsSecondsRangeWhenSwitchingFromTimeBasedToReps() {
        let original = ExerciseSpec(name: "Plank", sets: 3, repsMin: 45, repsMax: 45, restSeconds: 60)
        let target = ExerciseLibraryData.byName["Crunches (BW)"]!

        let adjusted = ExerciseAlternativeFinder.adjustedSpec(replacing: original, with: target)

        XCTAssertEqual(adjusted.name, "Crunches (BW)")
        XCTAssertNotEqual(adjusted.repsMax, 45, "45 Sekunden Haltezeit duerfen nicht als 45 Wiederholungen uebernommen werden")
    }

    func testAdjustedSpecPreservesSetsAndRestEvenAcrossATypeChange() {
        let original = ExerciseSpec(name: "Crunches (BW)", sets: 4, repsMin: 12, repsMax: 15, restSeconds: 75)
        let target = ExerciseLibraryData.byName["Plank"]!

        let adjusted = ExerciseAlternativeFinder.adjustedSpec(replacing: original, with: target)

        XCTAssertEqual(adjusted.sets, 4)
        XCTAssertEqual(adjusted.restSeconds, 75)
    }
}
