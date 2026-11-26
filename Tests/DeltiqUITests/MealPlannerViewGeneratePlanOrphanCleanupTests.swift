import XCTest

/// Audit-Fund (Modul-17-Folge-Task, schwerwiegendster try?-Fehlerverschlucken-Fall):
/// `generatePlan()` fuegte neue `PlannedMealAssignment`-Objekte VOR dem Aufruf von
/// `DailyMealPlan.upsertGenerated` in den `modelContext` ein. Wirft `upsertGenerated`
/// (z.B. weil `fetchOrCreate`s `context.fetch` fehlschlaegt), BEVOR es die Assignments
/// einem Plan zuweist, blieben sie als verwaiste Objekte im Context haengen - und der
/// `try?` verschluckte den Fehler komplett, ohne jede Nutzerrueckmeldung. Ergaenzt die
/// bestehende, aeltere Orphan-Absicherung in `DailyMealPlan.upsertGenerated` selbst
/// (dort nur fuer den regulaeren "Plan ist manuell angepasst"-Rueckweisungspfad, nicht
/// fuer den Fehlerfall beim Aufrufer). Quelltext-Pruefung (gleiches Muster wie
/// `ExerciseCardSaveErrorHandlingTests.logSet`), weil `upsertGenerated` keinen
/// Test-Seam fuer einen echten Fehlschlag hat.
final class MealPlannerViewGeneratePlanOrphanCleanupTests: XCTestCase {
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
                contentsOf: sourcesRoot.appendingPathComponent("Nutrition/MealPlannerView.swift"),
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

    func testGeneratePlanDeletesJustInsertedAssignmentsOnUpsertFailure() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func generatePlan() {") else {
            return XCTFail("generatePlan() not found at the expected signature")
        }
        guard let funcEnd = cleaned.range(of: "\n    }", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("generatePlan's end was not found")
        }
        let body = cleaned[funcStart.upperBound..<funcEnd.lowerBound]

        XCTAssertFalse(body.contains("try? DailyMealPlan.upsertGenerated("),
                        "generatePlan must not keep the swallowing try? form")
        guard let tryRange = body.range(of: "try DailyMealPlan.upsertGenerated(") else {
            return XCTFail("generatePlan must still call upsertGenerated, now with do/catch")
        }
        guard let catchRange = body.range(of: "} catch {", range: tryRange.upperBound..<body.endIndex) else {
            return XCTFail("generatePlan must wrap upsertGenerated in do/catch")
        }
        guard let catchEnd = body.range(of: "\n            }", range: catchRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block end not found")
        }
        let catchBody = body[catchRange.upperBound..<catchEnd.lowerBound]

        XCTAssertTrue(catchBody.contains("modelContext.delete("),
                       "a failed upsertGenerated must delete the just-inserted assignments so they don't stay orphaned")
        XCTAssertTrue(catchBody.contains("generationError = "),
                       "a failed upsertGenerated must surface an error via the existing generationError display")
    }

    func testNoBlanketContextRollbackIntroduced() throws {
        XCTAssertFalse(Self.stripLineComments(try source).contains("modelContext.rollback()"))
    }
}
