import XCTest

/// Audit-Fund (Modul 17, MealPlanner-UI). Die Portions-Stepper-Buttons
/// pruefte die Grenze gegen den AUSGANGSWERT statt gegen das ERGEBNIS des
/// Schritts (`if portionMultiplier > 0.5 { portionMultiplier -= 0.5 }`).
/// `init` klemmt den Startwert nur auf den Bereich [0.5, 10.0], rastert ihn
/// aber nie auf 0.5-Schritte - und `MealPlanGenerator.scaleToNutritionGoals`
/// liefert routinemaessig nicht gerasterte Werte (z.B. 1.37). Zwei Taps auf
/// "-" konnten den Wert dadurch dauerhaft unter die eigene 0.5-Untergrenze
/// druecken (1.37 > 0.5 -> 0.87 > 0.5 -> 0.37, Guard dann falsch, Wert bleibt
/// bei 0.37 stehen).
///
/// Fix: gegen das Ergebnis klemmen (`max(portionMultiplier - 0.5, 0.5)` /
/// `min(portionMultiplier + 0.5, 10.0)`), analog zu MealPlannerView.adjustPortion.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class RecipeDetailViewPortionStepperFloorTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Nutrition/RecipeDetailView.swift"),
                encoding: .utf8
            )
        }
    }

    func testStepperClampsAgainstTheResultNotTheStartingValue() throws {
        let text = try source
        guard let start = text.range(of: "private var portionSection: some View {") else {
            return XCTFail("portionSection not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of portionSection not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains("portionMultiplier = max(portionMultiplier - 0.5, 0.5)"),
                      "decrement must clamp the RESULT to the 0.5 floor, not guard on the starting value")
        XCTAssertTrue(body.contains("portionMultiplier = min(portionMultiplier + 0.5, 10.0)"),
                      "increment must clamp the RESULT to the 10.0 ceiling, not guard on the starting value")
        XCTAssertFalse(body.contains("if portionMultiplier > 0.5 { portionMultiplier"),
                       "must not guard the decrement on the pre-step value anymore")
        XCTAssertFalse(body.contains("if portionMultiplier < 10.0 { portionMultiplier"),
                       "must not guard the increment on the pre-step value anymore")
    }
}
