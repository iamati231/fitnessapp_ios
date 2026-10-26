#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest

/// ponytail-audit (2026-10-26, zweiter Repo-Audit): `ExerciseLibraryEditorSheet.save()`s
/// Edit-Pfad mutierte `existing.name`/`.primaryMuscle`/`.equipment`/`.isSystemCompound`
/// direkt auf dem lebenden Template, BEVOR `context.save()` lief - bei einem fehlgeschlagenen
/// Save blieben diese vier Felder trotz "Speichern fehlgeschlagen" auf dem Objekt stehen.
/// Gleicher Fund und gleicher Fix wie `CardioGoalEditorView.save()` (Commit 8bdb416, siehe
/// `CardioGoalEditorPersistenceTests.testFailedSaveSnapshotsAndRestoresAllSevenMutatedProfileFields`)
/// - `save()` ist `private` ohne testbare Laufzeit-Oberflaeche, daher Quelltext-Pruefung,
/// gleiches Muster wie dort.
@available(iOS 17.0, macOS 14.0, *)
final class ExerciseLibraryEditorSheetPersistenceTests: XCTestCase {

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var editorSource: String {
        get throws { try readSource("Sources/FitnessAppUI/Settings/ExerciseLibraryEditorSheet.swift") }
    }

    private static let rollbackFields: [(snapshotSuffix: String, propertyName: String)] = [
        ("Name", "name"),
        ("Muscle", "primaryMuscle"),
        ("Equipment", "equipment"),
        ("IsCompound", "isSystemCompound"),
    ]

    func testFailedSaveSnapshotsAndRestoresAllFourEditedTemplateFields() throws {
        let source = try editorSource
        guard let saveStart = source.range(of: "private func save() {") else {
            return XCTFail("save() not found at the expected signature")
        }
        guard let editMutationStart = source.range(of: "existing.name = trimmedName", range: saveStart.lowerBound..<source.endIndex) else {
            return XCTFail("the edit-path mutation block was not found where expected")
        }
        guard let catchStart = source.range(of: "} catch {", range: saveStart.lowerBound..<source.endIndex) else {
            return XCTFail("save()'s catch block was not found")
        }
        guard let errorMessageAssignment = source.range(of: "saveErrorMessage = String(localized: \"day.editor.save.failed\"", range: catchStart.upperBound..<source.endIndex) else {
            return XCTFail("save()'s error-message assignment was not found")
        }

        let beforeMutation = String(source[saveStart.lowerBound..<editMutationStart.lowerBound])
        let catchBody = String(source[catchStart.upperBound..<errorMessageAssignment.lowerBound])

        for field in Self.rollbackFields {
            XCTAssertTrue(
                beforeMutation.contains("original\(field.snapshotSuffix) = existing.\(field.propertyName)"),
                "save() must snapshot existing.\(field.propertyName) BEFORE the edit-path mutation, so a failed save can restore it"
            )
            XCTAssertTrue(
                catchBody.contains("existing.\(field.propertyName) = original\(field.snapshotSuffix)"),
                "a failed save's catch block must restore existing.\(field.propertyName) from its snapshot before the error message is set"
            )
        }
    }

    /// Gleiche Begruendung wie `CardioGoalEditorPersistenceTests.
    /// testSaveNeverUsesABlanketContextRollback`: `modelContext.rollback()` wuerde auch
    /// andere, unabhaengige, noch ausstehende Aenderungen im geteilten Context verwerfen.
    func testSaveNeverUsesABlanketContextRollback() throws {
        let source = try editorSource
        guard let saveStart = source.range(of: "private func save() {") else {
            return XCTFail("save() not found at the expected signature")
        }
        XCTAssertFalse(
            source[saveStart.lowerBound...].contains("modelContext.rollback()"),
            "save() must restore fields individually, never via a blanket modelContext.rollback() that could discard unrelated pending changes"
        )
    }

    /// Die Create-Path-Rueckabwicklung (frisch eingefuegtes Template loeschen) muss trotz
    /// der neuen Edit-Path-Wiederherstellung unveraendert bleiben.
    func testFailedSaveStillRollsBackAFreshlyInsertedTemplateOnTheCreatePath() throws {
        let source = try editorSource
        guard let catchStart = source.range(of: "} catch {") else {
            return XCTFail("save()'s catch block was not found")
        }
        XCTAssertTrue(
            source[catchStart.upperBound...].contains("modelContext.delete(insertedTemplate)"),
            "the create path's rollback (deleting the freshly inserted template) must still happen on a failed save"
        )
    }
}
#endif
