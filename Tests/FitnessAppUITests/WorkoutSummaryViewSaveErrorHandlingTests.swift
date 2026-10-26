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
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private var source: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("Workout/WorkoutSummaryView.swift"),
                encoding: .utf8
            )
        }
    }

    /// Scope-Grenze (Ticket): NUR die genannten diskreten Aktionen wurden umgestellt -
    /// `deleteEntireSession()` ist bewusst unveraendert geblieben (nicht im Audit-Scope,
    /// "offene Session" bezieht sich nicht auf eine bereits abgeschlossene History-Session).
    /// Genau EIN `try?` darf also noch uebrig sein.
    func testExactlyOneTryQuestionMarkSaveRemains() throws {
        let occurrences = try source.components(separatedBy: "try? modelContext.save()").count - 1
        XCTAssertEqual(occurrences, 1, "only deleteEntireSession() should still use try? - all other discrete save sites must surface failures")
    }

    /// Die sieben umgestellten Save-Aufrufe: Edit-Mode-Exit (zwei Saves), onDisappear-Netz,
    /// removeExerciseFromSession, addExerciseToSession, addCustomExerciseToSession,
    /// assignGear, addSet.
    func testDiscreteSaveSitesUseDoCatchAndSurfaceAToast() throws {
        let occurrences = try source.components(separatedBy: "try modelContext.save()").count - 1
        XCTAssertEqual(occurrences, 8, "expected 8 non-optional try modelContext.save() call sites (2x edit-mode-exit, onDisappear, removeExercise, addExercise, addCustomExercise, assignGear, addSet)")

        // +1 for the `private func showSaveErrorToast()` definition itself.
        let showToastOccurrences = try source.components(separatedBy: "showSaveErrorToast()").count - 1
        XCTAssertEqual(showToastOccurrences, 9, "every one of the 8 do/catch blocks must call showSaveErrorToast() in its catch, plus the one function definition")
    }

    /// Kein pauschales `modelContext.rollback()` - bereits mutierte Objekte bleiben
    /// pending im Context (kein Datenverlust durch einen "aufraeumenden" Rollback).
    func testNoBlanketContextRollbackIntroduced() throws {
        XCTAssertFalse(try source.contains("modelContext.rollback()"))
    }

    /// Verlaesst der User den History-Edit-Mode per Checkmark und einer der beiden
    /// Saves schlaegt fehl, darf `isEditingHistory.toggle()` NICHT erreicht werden -
    /// der User soll NICHT faelschlich sehen, dass "Fertig" erfolgreich war.
    func testEditModeExitStaysInEditModeOnSaveFailure() throws {
        let source = try source
        guard let actionStart = source.range(of: "systemImage: isEditingHistory ? \"checkmark\" : \"pencil\"") else {
            return XCTFail("edit-mode-exit header action not found at expected signature")
        }
        guard let toggleCall = source.range(of: "isEditingHistory.toggle()", range: actionStart.upperBound..<source.endIndex) else {
            return XCTFail("isEditingHistory.toggle() not found after the header action")
        }
        let actionBody = source[actionStart.upperBound..<toggleCall.lowerBound]

        let catchCount = actionBody.components(separatedBy: "} catch {").count - 1
        XCTAssertEqual(catchCount, 2, "expected exactly 2 catch blocks (one per save) before isEditingHistory.toggle()")

        let returnCount = actionBody.components(separatedBy: "return").count - 1
        XCTAssertEqual(returnCount, 2, "each catch block must return before isEditingHistory.toggle(), so a failed save never looks like a successful 'Fertig'")
    }
}
