import XCTest
@testable import DeltiqCore

/// Audit-Fund (Modul 17, MealPlanner-Algorithmus-Kern). `MealPlanOptimizer.optimize`
/// liess einen vollstaendig unaufloesbaren Slot (Rezept nicht mehr im recipeCatalog,
/// z.B. nach Daten-/Katalog-Drift) komplett aus `currentTotals`/`proposedTotals`
/// herausfallen, statt ihn als `.unknown` zu behandeln - das entspricht
/// stillschweigend einer 0-kcal-Annahme und widerspricht dem direkt darueber
/// dokumentierten OFF-01-Vertrag. Der daraus berechnete Skalierungsfaktor wurde
/// dann auf ALLE Slots angewendet, auch auf voellig intakte.
///
/// Fix: ein unaufloesbarer Slot traegt jetzt mit vier `.unknown`-Feldern zur
/// Summe bei. `NutrientValues.sum` propagiert "ein Unbekannter faerbt die ganze
/// Dimension unbekannt" bereits von sich aus - das macht `currentTotals`/
/// `proposedTotals` ehrlich unbekannt und loest automatisch den schon
/// bestehenden "Portionsskalierung nicht moeglich"-Pfad aus, statt einen
/// falschen Faktor auf unbeteiligte Slots anzuwenden.
final class MealPlanOptimizerUnresolvableSlotTotalsTests: XCTestCase {

    private let food = FoodCatalogItem(
        id: "chicken", nameKey: "t.chicken", category: .meat,
        kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6
    )

    private let breakfastRecipe = Recipe(
        id: "r_breakfast", nameKey: "t.breakfast",
        mealTypes: [.breakfast], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 100)]
    )

    func testOrphanedRecipeMakesTotalsUnknownInsteadOfUndercounted() {
        // Lunch referenziert ein Rezept, das NICHT mehr im Katalog ist.
        let result = MealPlanOptimizer.optimize(
            assignments: [
                (recipeID: "r_breakfast", mealType: .breakfast, portionMultiplier: 1.0),
                (recipeID: "r_gone", mealType: .lunch, portionMultiplier: 1.0)
            ],
            calorieGoal: 2000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [breakfastRecipe], // r_gone bewusst NICHT enthalten
            foodCatalog: [food],
            preferences: UserNutritionPreferences()
        )
        guard case .success(let p) = result else { XCTFail("Erwartet .success"); return }

        XCTAssertTrue(p.currentTotals.kcal.isUnknown,
                      "Ein unaufloesbarer Slot muss die Tagessumme unbekannt machen, nicht stillschweigend als 0 zaehlen")
        XCTAssertTrue(p.proposedTotals.kcal.isUnknown,
                      "proposedTotals muss ebenso unbekannt bleiben")

        // Ohne verlaesslichen Skalierungsfaktor darf der intakte Breakfast-Slot
        // NICHT hochskaliert werden.
        let breakfastChange = p.changes.first { $0.mealType == .breakfast }
        XCTAssertEqual(breakfastChange?.proposedMultiplier, 1.0,
                       "Intakter Slot darf nicht auf Basis einer unvollstaendigen Tagessumme hochskaliert werden")
        XCTAssertNotNil(p.warning)
    }
}
