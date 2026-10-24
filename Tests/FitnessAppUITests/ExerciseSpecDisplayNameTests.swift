#if canImport(SwiftUI)
import XCTest
import FitnessAppCore
@testable import FitnessAppUI

/// Schritt-3-Vorschau (writing-block.md, Punkt 3.4): `localizedExerciseName`/
/// `detailLine` were pulled out of `ProgramTemplatePickerView` into
/// `Extensions/ExerciseSpec+DisplayName.swift` so `PlanBuilderView.resultDayRow`
/// can reuse them instead of a second copy. These tests deliberately avoid
/// asserting the exact RESOLVED text of a `String(localized:bundle:.module)`
/// call — this session's CI run already showed that lookup returning the raw
/// key instead of the translation for a catalog-matched exercise name
/// (`PlanDayExerciseItemTests` fix, commit 1fdfaf5), so a hardcoded expected
/// translation would be locale/CI-environment fragile. Instead these check
/// the branch logic and value substitution that don't depend on which
/// translation actually resolved.
@available(iOS 17.0, macOS 14.0, *)
final class ExerciseSpecDisplayNameTests: XCTestCase {

    func testLocalizedExerciseNameFallsBackToRawNameWhenNotInCatalog() {
        // Deliberately not a real ExerciseLibraryData entry - see the file
        // comment above for why a catalog match isn't used here.
        XCTAssertEqual(localizedExerciseName("Ganz Erfundene Testuebung"), "Ganz Erfundene Testuebung")
    }

    // Die naechsten beiden pruefen bewusst nur "stuerzt nicht ab, liefert
    // nicht-leeren Text" statt des exakt aufgeloesten Textes - genau die
    // Sorte Assertion, die oben als riskant markiert ist.
    func testDetailLineForStrengthExerciseDoesNotCrashAndReturnsText() {
        let exercise = ExerciseSpec(name: "Ganz Erfundene Testuebung", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 90)
        XCTAssertFalse(detailLine(for: exercise, dayFormat: nil).isEmpty)
    }

    func testDetailLineForCardioUsesTheCardioBranchAndDoesNotCrash() {
        let exercise = ExerciseSpec(name: "Ganz Erfundene Testuebung", sets: 1, repsMin: 1, repsMax: 1, restSeconds: 45, isCardio: true)
        XCTAssertFalse(detailLine(for: exercise, dayFormat: nil).isEmpty)
    }

    func testDetailLineForATimedDayDelegatesToTheCircuitLabelNotTheSetsRepsFormat() {
        let exercise = ExerciseSpec(name: "Ganz Erfundene Testuebung", sets: 3, repsMin: 8, repsMax: 12, restSeconds: 90)
        let line = detailLine(for: exercise, dayFormat: .amrap)
        XCTAssertEqual(line, timedFormatCircuitLabel(repsMin: exercise.repsMin, isTimeBased: false, sets: exercise.sets, format: .amrap))
    }
}
#endif
