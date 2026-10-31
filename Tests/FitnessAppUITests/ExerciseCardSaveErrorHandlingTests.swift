import XCTest

/// Audit-Fund (ponytail-audit UI, Save-Fehler in Satz-Logging): `logSet()`/`unlogSet()`
/// nutzten `try? modelContext.save()` - der Doc-Kommentar beider Funktionen beschreibt
/// einen bereits auf echtem Geraet reproduzierten Datenverlust (Satz verschwindet nach
/// Kaltstart), der dadurch nur zur Haelfte behoben war. Quelltext-Pruefung (gleiches
/// Muster wie `BodyDataEditorRollbackTests`), weil `save()` keinen Test-Seam fuer einen
/// echten `ModelContext.save()`-Fehlschlag hat. Sucht auf kommentarbereinigtem Text,
/// weil die erklaerenden Doku-Kommentare selbst Codefragmente zitieren (gleiche Falle
/// wie in `WorkoutSummaryViewSaveErrorHandlingTests`).
final class ExerciseCardSaveErrorHandlingTests: XCTestCase {
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
                contentsOf: sourcesRoot.appendingPathComponent("Workout/ExerciseCard.swift"),
                encoding: .utf8
            )
        }
    }

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testNoTryQuestionMarkSaveRemains() throws {
        XCTAssertFalse(try source.contains("try? modelContext.save()"))
    }

    func testNoBlanketContextRollbackIntroduced() throws {
        XCTAssertFalse(Self.stripLineComments(try source).contains("modelContext.rollback()"))
    }

    /// `logSet()`: ein fehlgeschlagener Save muss das gerade eingefuegte Log wieder
    /// entfernen (der Haken haengt sonst bis zum naechsten Kaltstart faelschlich auf
    /// "geloggt") UND darf `onSetLogged` nicht mehr aufrufen.
    func testLogSetRevertsTheJustInsertedLogAndSkipsOnSetLoggedOnFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func logSet(setIndex: Int, values: LoggedSetValues) {") else {
            return XCTFail("logSet(setIndex:values:) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("logSet's end was not found")
        }
        let body = cleaned[funcStart.upperBound..<funcEnd.lowerBound]

        guard let catchRange = body.range(of: "} catch {") else {
            return XCTFail("logSet must use do/catch instead of try?")
        }
        guard let catchEnd = body.range(of: "\n        }", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]

        XCTAssertTrue(catchBody.contains("modelContext.delete(log)"),
                       "a failed save must delete the just-inserted log so the checkmark doesn't lie")
        XCTAssertTrue(catchBody.contains("return"),
                       "the catch block must return before onSetLogged(setIndex) is called")

        // onSetLogged must appear AFTER the catch block closes (success-only path).
        guard let onSetLoggedCall = body.range(of: "onSetLogged(setIndex)", range: catchEnd.upperBound..<body.endIndex) else {
            return XCTFail("onSetLogged(setIndex) must still be called on the success path")
        }
        XCTAssertTrue(onSetLoggedCall.lowerBound > catchEnd.upperBound)
    }

    /// `unlogSet()`: do/catch statt `try?`, aber bewusst KEIN Undo-Versuch (siehe
    /// Code-Kommentar: `delete()` wirkt schon vor dem Save auf den Live-Graphen,
    /// ein Re-Insert ist weder noetig noch ohne Weiteres moeglich).
    func testUnlogSetUsesDoCatchWithoutModelContextDelete() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func unlogSet(setIndex: Int) {") else {
            return XCTFail("unlogSet(setIndex:) not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("unlogSet's end was not found")
        }
        let body = cleaned[funcStart.upperBound..<funcEnd.lowerBound]
        XCTAssertTrue(body.contains("} catch {"), "unlogSet must use do/catch instead of try?")
        XCTAssertTrue(body.contains("saveErrorMessage = "), "a failed save must surface an error")
    }
}
