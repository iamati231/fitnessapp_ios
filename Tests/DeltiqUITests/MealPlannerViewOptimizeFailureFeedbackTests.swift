import XCTest

/// Audit-Fund (Modul 17, MealPlanner-UI). `startOptimization()` behandelte nur
/// den `.success`-Fall von `MealPlanOptimizer.optimize(...)` - bei `.failure`
/// (z.B. `.noAssignments`, erreichbar nachdem alle Mahlzeiten eines Tages
/// entfernt wurden) verschwand nur der Lade-Indikator, ohne jede Rueckmeldung.
/// Die strukturell analogen Flows `regenerateAssignment`/`generatePlan` zeigen
/// bei einem Fehlschlag im selben File explizit eine Meldung.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class MealPlannerViewOptimizeFailureFeedbackTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Nutrition/MealPlannerView.swift"),
                encoding: .utf8
            )
        }
    }

    func testStartOptimizationShowsFeedbackOnFailure() throws {
        let text = try source
        guard let start = text.range(of: "private func startOptimization() async {") else {
            return XCTFail("startOptimization() not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of startOptimization() not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains("case .failure"),
                      "startOptimization must handle the .failure case of MealPlanOptimizer.optimize, not just .success")
        XCTAssertTrue(body.contains("showOptimizationFailedAlert = true"),
                      "a failed optimization must surface feedback to the user, matching the regenerate/generate sibling flows")
    }

    func testCatalogHasOptimizeFailedKeys() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        XCTAssertTrue(catalog.contains("\"mealPlanner.optimize.failed.title\""))
        XCTAssertTrue(catalog.contains("\"mealPlanner.optimize.failed.message\""))
    }
}
