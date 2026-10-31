import XCTest

/// Audit-Fund (zweiter Repo-Audit dieser Session): `TrainingLocationEquipmentEditorView.save()`
/// mutierte `profile.environment`/`profile.equipmentProfile` direkt auf das bereits lebende
/// `@Bindable var profile`, und `confirmEquipmentProfileComplete()` (bedingt aufgerufen) zusaetzlich
/// `profile.equipmentProfileConfirmedComplete`/`profile.equipmentPreferences` - bevor `modelContext.
/// save()` lief. Bei einem fehlgeschlagenen Save wurde KEINES der vier Felder zurueckgerollt.
/// Identischer Bug/Fix wie `CardioGoalEditorView.save()` (Commit 8bdb416) - `save()` ist eine
/// `private` SwiftUI-Methode ohne Test-Seam fuer einen echten `ModelContext.save()`-Fehlschlag,
/// daher Quelltext-Pruefung (gleiches Muster wie `BodyDataEditorRollbackTests`).
final class TrainingLocationEquipmentEditorRollbackTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private var source: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("Settings/TrainingLocationEquipmentEditorView.swift"),
                encoding: .utf8
            )
        }
    }

    func testFailedSaveSnapshotsAndRestoresAllFourMutatedProfileFields() throws {
        let source = try source
        guard let saveStart = source.range(of: "private func save() {") else {
            return XCTFail("save() not found at the expected signature")
        }
        guard let mutationStart = source.range(of: "profile.environment = draftEnvironment") else {
            return XCTFail("the mutation line was not found")
        }
        guard let catchStart = source.range(of: "} catch {", range: saveStart.lowerBound..<source.endIndex) else {
            return XCTFail("save()'s catch block was not found")
        }
        guard let errorMessageAssignment = source.range(
            of: "saveErrorMessage = String(localized: \"day.editor.save.failed\"",
            range: catchStart.upperBound..<source.endIndex
        ) else {
            return XCTFail("save()'s error-message assignment was not found")
        }

        let beforeMutation = source[saveStart.lowerBound..<mutationStart.lowerBound]
        let catchBody = source[catchStart.upperBound..<errorMessageAssignment.lowerBound]

        for (snapshotName, propertyName) in [
            ("originalEnvironment", "environment"),
            ("originalEquipmentProfile", "equipmentProfile"),
            ("originalEquipmentProfileConfirmedComplete", "equipmentProfileConfirmedComplete"),
            ("originalEquipmentPreferences", "equipmentPreferences"),
        ] {
            XCTAssertTrue(
                beforeMutation.contains("let \(snapshotName) = profile.\(propertyName)"),
                "save() must snapshot profile.\(propertyName) BEFORE the mutating block, so a failed save can restore it"
            )
            XCTAssertTrue(
                catchBody.contains("profile.\(propertyName) = \(snapshotName)"),
                "a failed save's catch block must restore profile.\(propertyName) from its snapshot before the error message is set"
            )
        }
    }

    /// `confirmEquipmentProfileComplete()` (called from inside `save()` when `equipmentTouched`)
    /// itself mutates `equipmentProfile`/`equipmentProfileConfirmedComplete`/`equipmentPreferences`
    /// (see `UserBodyProfile.confirmEquipmentProfileComplete()`) - the snapshot above must be taken
    /// before ANY of `save()`'s mutations, not just the two directly-visible assignment lines.
    func testSnapshotIsTakenBeforeConfirmEquipmentProfileCompleteCanRun() throws {
        let source = try source
        guard let saveStart = source.range(of: "private func save() {") else {
            return XCTFail("save() not found at the expected signature")
        }
        guard let snapshotLine = source.range(
            of: "let originalEquipmentProfileConfirmedComplete = profile.equipmentProfileConfirmedComplete",
            range: saveStart.lowerBound..<source.endIndex
        ) else {
            return XCTFail("the equipmentProfileConfirmedComplete snapshot was not found")
        }
        guard let confirmCall = source.range(
            of: "profile.confirmEquipmentProfileComplete()",
            range: saveStart.lowerBound..<source.endIndex
        ) else {
            return XCTFail("the confirmEquipmentProfileComplete() call was not found")
        }
        XCTAssertTrue(
            snapshotLine.upperBound < confirmCall.lowerBound,
            "the equipmentProfileConfirmedComplete snapshot must be taken before confirmEquipmentProfileComplete() can mutate it"
        )
    }

    /// Wie beim bereits etablierten Fix: kein pauschales `modelContext.rollback()` im Fehlerzweig
    /// (wuerde andere, unabhaengige Aenderungen im geteilten Context mitverwerfen). Kommentare
    /// werden vor der Pruefung entfernt, da der erklaerende Kommentar selbst den String nennt.
    func testSaveNeverUsesABlanketContextRollback() throws {
        let source = try source
        guard let saveStart = source.range(of: "private func save() {") else {
            return XCTFail("save() not found at the expected signature")
        }
        guard let catchStart = source.range(of: "} catch {", range: saveStart.lowerBound..<source.endIndex) else {
            return XCTFail("save()'s catch block was not found")
        }
        guard let catchEnd = source.range(of: "\n    }", range: catchStart.upperBound..<source.endIndex) else {
            return XCTFail("save()'s catch block end was not found")
        }
        let catchCode = source[catchStart.upperBound..<catchEnd.lowerBound]
            .split(separator: "\n")
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
        XCTAssertFalse(
            catchCode.contains("modelContext.rollback()"),
            "save() must restore the four fields individually, never via a blanket modelContext.rollback() that could discard unrelated pending changes"
        )
    }
}
