import XCTest

/// Audit-Fund (ponytail-audit, Save-Fehler in Workout-Editoren): `WorkoutSummaryView`s
/// diskrete Speicher-Aktionen (Edit-Mode verlassen, Satz/Uebung hinzufuegen/entfernen,
/// Gear zuweisen) nutzten `try? modelContext.save()` - ein Fehlschlag sah fuer den User
/// wie Erfolg aus. Quelltext-Pruefung (gleiches Muster wie `BodyDataEditorRollbackTests`),
/// weil `save()` keinen Test-Seam fuer einen echten `ModelContext.save()`-Fehlschlag hat.
final class WorkoutSummaryViewSaveErrorHandlingTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private var source: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("Workout/WorkoutSummaryView.swift"),
                encoding: .utf8
            )
        }
    }

    /// Modul-8-Audit: die ehemalige Ausnahme `deleteEntireSession()` (Scope-
    /// Grenze eines frueheren Tickets) wurde geschlossen - eine fehlgeschlagene
    /// Loeschung ist derselbe "stille Erfolg"-Fehler wie die anderen acht
    /// Stellen. Kein `try?` darf mehr uebrig sein.
    func testNoTryQuestionMarkSaveRemains() throws {
        let occurrences = try source.components(separatedBy: "try? modelContext.save()").count - 1
        XCTAssertEqual(occurrences, 0, "all discrete save sites, including deleteEntireSession(), must surface failures")
    }

    /// Die zehn umgestellten Save-Aufrufe: Edit-Mode-Exit (zwei Saves), onDisappear-Netz,
    /// removeExerciseFromSession, addExerciseToSession, addCustomExerciseToSession,
    /// assignGear, addSet, deleteEntireSession, deleteSets (Modul (e): Satz-Loeschen
    /// speicherte zuvor gar nicht).
    func testDiscreteSaveSitesUseDoCatchAndSurfaceAToast() throws {
        let occurrences = try source.components(separatedBy: "try modelContext.save()").count - 1
        XCTAssertEqual(occurrences, 10, "expected 10 non-optional try modelContext.save() call sites (2x edit-mode-exit, onDisappear, removeExercise, addExercise, addCustomExercise, assignGear, addSet, deleteEntireSession, deleteSets)")

        // +1 for the `private func showSaveErrorToast()` definition itself.
        let showToastOccurrences = try source.components(separatedBy: "showSaveErrorToast()").count - 1
        XCTAssertEqual(showToastOccurrences, 11, "every one of the 10 do/catch blocks must call showSaveErrorToast() in its catch, plus the one function definition")
    }

    /// Schlaegt der Save in `deleteEntireSession()` fehl, darf der optimistische
    /// `isDeleted = true`-Flip nicht stehen bleiben - sonst zeigt der Screen eine
    /// leere Flaeche, obwohl die Session nie wirklich geloescht wurde.
    func testDeleteEntireSessionResetsIsDeletedFlagOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func deleteEntireSession() {") else {
            return XCTFail("deleteEntireSession() not found at expected signature")
        }
        guard let catchRange = cleaned.range(of: "} catch {", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("deleteEntireSession() has no catch block")
        }
        guard let dismissRange = cleaned.range(of: "dismiss()", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("deleteEntireSession() never calls dismiss()")
        }
        XCTAssertLessThan(catchRange.lowerBound, dismissRange.lowerBound,
                          "the catch block must come before dismiss()")
        let catchBody = cleaned[catchRange.upperBound..<dismissRange.lowerBound]
        XCTAssertTrue(catchBody.contains("isDeleted = false"),
                     "catch block must reset isDeleted before returning, so a failed delete doesn't blank the screen")
        XCTAssertTrue(catchBody.contains("return"),
                     "catch block must return before reaching dismiss()")
    }

    /// Kein pauschales `modelContext.rollback()` - bereits mutierte Objekte bleiben
    /// pending im Context (kein Datenverlust durch einen "aufraeumenden" Rollback).
    func testNoBlanketContextRollbackIntroduced() throws {
        XCTAssertFalse(try source.contains("modelContext.rollback()"))
    }

    /// Verlaesst der User den History-Edit-Mode per Checkmark und einer der beiden
    /// Saves schlaegt fehl, darf `isEditingHistory.toggle()` NICHT erreicht werden -
    /// der User soll NICHT faelschlich sehen, dass "Fertig" erfolgreich war.
    ///
    /// Sucht auf dem KOMMENTAR-bereinigten Quelltext - sonst matcht die erklaerende
    /// Doku ueber `isEditingHistory.toggle()` selbst (gleiche Falle wie
    /// `BodyDataEditorRollbackTests.testSaveNeverUsesABlanketContextRollback`).
    func testEditModeExitStaysInEditModeOnSaveFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let actionStart = cleaned.range(of: "systemImage: isEditingHistory ? \"checkmark\" : \"pencil\"") else {
            return XCTFail("edit-mode-exit header action not found at expected signature")
        }
        guard let toggleCall = cleaned.range(of: "isEditingHistory.toggle()", range: actionStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("isEditingHistory.toggle() not found after the header action")
        }
        let actionBody = cleaned[actionStart.upperBound..<toggleCall.lowerBound]

        let catchCount = actionBody.components(separatedBy: "} catch {").count - 1
        XCTAssertEqual(catchCount, 2, "expected exactly 2 catch blocks (one per save) before isEditingHistory.toggle()")

        let returnCount = actionBody.components(separatedBy: "return").count - 1
        XCTAssertEqual(returnCount, 2, "each catch block must return before isEditingHistory.toggle(), so a failed save never looks like a successful 'Fertig'")
    }

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }
}
