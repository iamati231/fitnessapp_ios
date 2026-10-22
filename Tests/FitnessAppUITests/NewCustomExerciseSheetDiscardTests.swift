#if canImport(SwiftUI)
import XCTest
import FitnessAppCore
@testable import FitnessAppUI

/// Task 8 (docs/superpowers/sdd/2026-10-22-ui-consistency): `NewCustomExerciseSheet`
/// bekam sein `isDirty`+`discardChangesConfirmation` bereits in Task 7 (siehe
/// `fix: align 3 sheets with the DeltiqHeader sheet-dismiss standard`), als
/// Nebenprodukt der Umstellung auf `DeltiqHeader` -- dafuer existierte bisher
/// aber kein eigener Test. `NewCustomExerciseSheet.isDirty` ist `private`
/// (gleiches Muster wie `MeasurementView.isDirty`/`ExerciseLibraryEditorSheet.
/// isDirty` -- nur die jeweilige Snapshot-/Vergleichsbasis wird `internal`
/// gemacht, nicht `isDirty` selbst), deshalb reproduziert dieser Test die
/// EXAKTE Formel aus der aktuellen Produktionsdatei (Zeilen 67-72) gegen reine
/// Werte -- derselbe Ansatz wie `MeasurementDoubleTapGuardTests` fuer dasselbe
/// Problem (kein lebender SwiftUI-Graph fuer @State-Mutationen in diesem
/// Test-Setup, siehe `EditorDiscardSnapshotTests`-Dateikopf).
@available(iOS 17.0, macOS 14.0, *)
final class NewCustomExerciseSheetDiscardTests: XCTestCase {

    /// Reproduziert `NewCustomExerciseSheet.isDirty`.
    private func isDirtyFormula(
        trimmedName: String,
        initialTrimmedName: String,
        primaryMuscle: MuscleGroup,
        equipment: Equipment,
        isCompound: Bool
    ) -> Bool {
        trimmedName != initialTrimmedName
            || primaryMuscle != .chest
            || equipment != .bodyweight
            || isCompound != false
    }

    func testUnchangedDefaultsAreNotDirty() {
        // (b) aus dem Brief: frisch geoeffnet (vorausgefuellter Suchtext
        // unveraendert, alle Metadaten-Defaults unveraendert) -> nicht dirty,
        // der Chevron darf sofort schliessen.
        XCTAssertFalse(isDirtyFormula(
            trimmedName: "Kreuzheben", initialTrimmedName: "Kreuzheben",
            primaryMuscle: .chest, equipment: .bodyweight, isCompound: false
        ))
    }

    func testEmptyPrefillUnchangedIsNotDirty() {
        XCTAssertFalse(isDirtyFormula(
            trimmedName: "", initialTrimmedName: "",
            primaryMuscle: .chest, equipment: .bodyweight, isCompound: false
        ))
    }

    func testChangedNameIsDirty() {
        // (a) aus dem Brief: ausgefuellte/geaenderte Felder -> dirty, der
        // Chevron muss `discardChangesConfirmation` zeigen statt sofort zu
        // schliessen.
        XCTAssertTrue(isDirtyFormula(
            trimmedName: "Kreuzheben Sumo", initialTrimmedName: "Kreuzheben",
            primaryMuscle: .chest, equipment: .bodyweight, isCompound: false
        ))
    }

    func testChangedMuscleAloneIsDirty() {
        XCTAssertTrue(isDirtyFormula(
            trimmedName: "Kreuzheben", initialTrimmedName: "Kreuzheben",
            primaryMuscle: .back, equipment: .bodyweight, isCompound: false
        ))
    }

    func testChangedEquipmentAloneIsDirty() {
        XCTAssertTrue(isDirtyFormula(
            trimmedName: "Kreuzheben", initialTrimmedName: "Kreuzheben",
            primaryMuscle: .chest, equipment: .barbell, isCompound: false
        ))
    }

    func testChangedCompoundAloneIsDirty() {
        XCTAssertTrue(isDirtyFormula(
            trimmedName: "Kreuzheben", initialTrimmedName: "Kreuzheben",
            primaryMuscle: .chest, equipment: .bodyweight, isCompound: true
        ))
    }
}
#endif
