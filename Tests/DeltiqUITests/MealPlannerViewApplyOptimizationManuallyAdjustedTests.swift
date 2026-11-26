import XCTest

/// Audit-Fund (Modul 17, MealPlanner-UI). `applyOptimization(_:)` mutierte und
/// speicherte die optimierten Zuweisungen, setzte dabei aber nie
/// `plan.isManuallyAdjusted = true` - im Gegensatz zu jeder anderen
/// schreibenden Aktion in derselben Datei (adjustPortion, swapAssignment,
/// removeAssignment, regenerateAssignment). `isManuallyAdjusted` ist genau
/// das Flag, das `DailyMealPlan.upsertGenerated` vor einer erneuten
/// Ueberschreibung durch den Generator schuetzt: ein gerade bestaetigter
/// Optimierungs-Lauf konnte durch erneutes Tippen auf "Plan generieren"
/// kommentarlos ersatzlos geloescht werden.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class MealPlannerViewApplyOptimizationManuallyAdjustedTests: XCTestCase {
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

    func testApplyOptimizationSetsManuallyAdjustedBeforeSaving() throws {
        let text = try source
        guard let start = text.range(of: "private func applyOptimization(_ proposal: OptimizedPlanProposal) {") else {
            return XCTFail("applyOptimization(_:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of applyOptimization(_:) not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains("plan.isManuallyAdjusted = true"),
                      "applyOptimization must mark the plan as manually adjusted, otherwise a confirmed optimization can be silently wiped by the next 'generate plan' tap")

        // Audit-Folge-Fix (try?-Fehlerverschlucken): save() laeuft jetzt in
        // einem do/catch statt per try? - die Reihenfolge-Garantie bleibt
        // unveraendert, nur das literal gesuchte Save-Statement aendert sich.
        guard let saveRange = body.range(of: "try modelContext.save()"),
              let flagRange = body.range(of: "plan.isManuallyAdjusted = true") else {
            return XCTFail("expected statements not found")
        }
        XCTAssertTrue(flagRange.lowerBound < saveRange.lowerBound,
                      "the flag must be set BEFORE the save, not after")
    }
}
