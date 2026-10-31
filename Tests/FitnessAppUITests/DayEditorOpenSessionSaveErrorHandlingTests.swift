import XCTest

/// Audit-Fund (ponytail-audit, Save-Fehler in Workout-Editoren): `DayEditorView`s
/// "Speichern & neu starten"/"Verwerfen"-Aktionen fuer eine bereits offene Session
/// (DEL-042-Recovery-Dialog) nutzten `try? modelContext.save()` und navigierten danach
/// unbedingt in eine neue Session weiter - ein Fehlschlag blieb unsichtbar UND der User
/// landete in einer neuen Session, waehrend die alte in einem unklaren Zustand haengt.
/// Quelltext-Pruefung, gleiches Muster wie `BodyDataEditorRollbackTests` - `saveAndDismiss()`
/// und `deleteExercises()` in dieser Datei nutzen bereits dasselbe do/catch +
/// `showTransientToast(...)`-Muster, das hier auf die zwei verbliebenen Stellen uebertragen wird.
final class DayEditorOpenSessionSaveErrorHandlingTests: XCTestCase {
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
                contentsOf: sourcesRoot.appendingPathComponent("Workout/DayEditorView.swift"),
                encoding: .utf8
            )
        }
    }

    /// `completeOpenSessionAndStartNew()`: ein fehlgeschlagener Save darf den User NICHT
    /// in `actuallyStartNewSession()` weiterschicken - er muss erfahren, dass die alte
    /// Session nicht abgeschlossen wurde, statt kommentarlos in einer neuen zu landen.
    func testCompleteOpenSessionReturnsBeforeStartingNewSessionOnSaveFailure() throws {
        let source = try source
        guard let funcStart = source.range(of: "private func completeOpenSessionAndStartNew() {") else {
            return XCTFail("completeOpenSessionAndStartNew() not found at the expected signature")
        }
        guard let funcEnd = source.range(of: "\n    }", range: funcStart.upperBound..<source.endIndex) else {
            return XCTFail("completeOpenSessionAndStartNew()'s end was not found")
        }
        let body = source[funcStart.upperBound..<funcEnd.lowerBound]

        XCTAssertTrue(body.contains("do {\n            try modelContext.save()\n        } catch {"),
                       "must use do/catch instead of try? modelContext.save()")
        XCTAssertFalse(body.contains("try? modelContext.save()"))
        XCTAssertTrue(body.contains("showTransientToast(String(localized: \"day.editor.save.failed\""),
                       "failure must surface via the established showTransientToast(...) pattern")

        guard let catchRange = body.range(of: "} catch {") else {
            return XCTFail("catch block not found")
        }
        let catchBody = body[catchRange.upperBound...]
        guard let nextBrace = catchBody.firstIndex(of: "}") else {
            return XCTFail("catch block end not found")
        }
        XCTAssertTrue(catchBody[..<nextBrace].contains("return"),
                       "the catch block must return before actuallyStartNewSession() is called")
    }

    /// `discardOpenSessionAndStartNew()`: identisches Muster.
    func testDiscardOpenSessionReturnsBeforeStartingNewSessionOnSaveFailure() throws {
        let source = try source
        guard let funcStart = source.range(of: "private func discardOpenSessionAndStartNew() {") else {
            return XCTFail("discardOpenSessionAndStartNew() not found at the expected signature")
        }
        guard let funcEnd = source.range(of: "\n    }", range: funcStart.upperBound..<source.endIndex) else {
            return XCTFail("discardOpenSessionAndStartNew()'s end was not found")
        }
        let body = source[funcStart.upperBound..<funcEnd.lowerBound]

        XCTAssertTrue(body.contains("do {\n            try modelContext.save()\n        } catch {"),
                       "must use do/catch instead of try? modelContext.save()")
        XCTAssertFalse(body.contains("try? modelContext.save()"))
        XCTAssertTrue(body.contains("showTransientToast(String(localized: \"day.editor.save.failed\""),
                       "failure must surface via the established showTransientToast(...) pattern")

        guard let catchRange = body.range(of: "} catch {") else {
            return XCTFail("catch block not found")
        }
        let catchBody = body[catchRange.upperBound...]
        guard let nextBrace = catchBody.firstIndex(of: "}") else {
            return XCTFail("catch block end not found")
        }
        XCTAssertTrue(catchBody[..<nextBrace].contains("return"),
                       "the catch block must return before actuallyStartNewSession() is called")
    }

    /// Scope-Grenze (Ticket): keine pauschale Aenderung aller `try? modelContext.save()`-
    /// Stellen in dieser Datei - nur die zwei offene-Session-Aktionen oben wurden angefasst.
    /// Tick-basierte Autosaves und alle anderen bestehenden Stellen bleiben unveraendert.
    func testNoBlanketContextRollbackIntroduced() throws {
        XCTAssertFalse(try source.contains("modelContext.rollback()"))
    }
}
