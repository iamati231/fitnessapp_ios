import XCTest

/// Audit-Fund (Modul 17, MealPlanner-UI). `saveRecipeToDiary()` fiel bei einer
/// Zutat mit nicht-positiver Menge (amountGrams <= 0, ein Datenfehler im
/// Katalog) auf eine voll-unbekannte `NutrientValues` zurueck, speicherte den
/// Eintrag aber trotzdem ins Tagebuch - anders als die Schwesterfunktion
/// `RecipeNutritionCalculator.nutrients`, die genau diese Zutat per
/// `continue` ignoriert ("Menge <= 0 ist ein Datenfehler; Position mit 0 g
/// ignorieren"). Kein Rezept im aktuellen Katalog loest das heute aus, aber
/// die Luecke wuerde sofort bei der naechsten fehlerhaften Katalog-Zeile
/// einen Phantom-Eintrag im Ernaehrungstagebuch erzeugen.
///
/// Fix: dieselbe continue-Logik wie RecipeNutritionCalculator.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class RecipeDetailViewDiarySkipsNonpositiveIngredientsTests: XCTestCase {
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

    func testSaveRecipeToDiarySkipsIngredientsWhoseNutrientsAreNil() throws {
        let text = try source
        guard let start = text.range(of: "private func saveRecipeToDiary() {") else {
            return XCTFail("saveRecipeToDiary() not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of saveRecipeToDiary() not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains("guard let nutrients = NutritionCalculations.nutrients(for: food, quantity: scaledGrams, unit: .gram) else"),
                      "must skip an ingredient whose nutrients lookup fails, matching RecipeNutritionCalculator.nutrients' own convention")
        XCTAssertFalse(body.contains("?? NutrientValues(kcal: .unknown"),
                       "must no longer fall back to an all-unknown placeholder and still insert the item")

        guard let guardRange = body.range(of: "guard let nutrients"),
              let continueRange = body.range(of: "continue", range: guardRange.upperBound..<body.endIndex),
              let insertRange = body.range(of: "modelContext.insert(item)", range: guardRange.upperBound..<body.endIndex) else {
            return XCTFail("expected statements not found in order")
        }
        XCTAssertTrue(continueRange.lowerBound < insertRange.lowerBound,
                      "the continue must happen before any insert for a skipped ingredient")
    }
}
