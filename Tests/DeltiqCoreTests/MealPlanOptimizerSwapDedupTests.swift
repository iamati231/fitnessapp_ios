import XCTest
@testable import DeltiqCore

/// Audit-Fund (Modul 17, MealPlanner-Algorithmus-Kern). `MealPlanOptimizer.optimize`
/// baute sein Dedup-Set `assignedIDs` einmalig vor der Slot-Schleife und
/// aktualisierte es nie, wenn fuer einen unaufloesbaren Slot bereits ein
/// Ersatzrezept gewaehlt wurde - im Gegensatz zur Schwesterfunktion
/// `MealPlanGenerator.generate()`, die ihr Set inkrementell pflegt (vgl.
/// `testGenerateNoDuplicateRecipesWhenCatalogLargeEnough`). Enthielt ein Plan
/// zwei Slots mit identischem mealType und identischer (unloesbarer)
/// recipeID - laut MealType.swift ausdruecklich erlaubt ("zwei Snacks") -,
/// schlug die Swap-Suche fuer BEIDE denselben ersten Kandidaten vor.
///
/// Fix: der frisch gewaehlte Swap wird sofort als belegt markiert.
final class MealPlanOptimizerSwapDedupTests: XCTestCase {

    private let food = FoodCatalogItem(
        id: "chicken", nameKey: "t.chicken", category: .meat,
        kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6
    )

    private let snackA = Recipe(
        id: "snack_a", nameKey: "t.snack_a",
        mealTypes: [.snack], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 2,
        ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 50)]
    )

    private let snackB = Recipe(
        id: "snack_b", nameKey: "t.snack_b",
        mealTypes: [.snack], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 2,
        ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 60)]
    )

    func testTwoUnresolvableSlotsOfSameMealTypeDoNotGetTheIdenticalSwap() {
        // Zwei Snack-Zuweisungen referenzieren dieselbe, nicht mehr im Katalog
        // vorhandene recipeID - beide muessen einen Ersatz finden, aber nicht
        // denselben.
        let result = MealPlanOptimizer.optimize(
            assignments: [
                (recipeID: "r_gone", mealType: .snack, portionMultiplier: 1.0),
                (recipeID: "r_gone", mealType: .snack, portionMultiplier: 1.0)
            ],
            calorieGoal: 2000, proteinGoal: nil, carbGoal: nil, fatGoal: nil,
            recipeCatalog: [snackA, snackB], // r_gone bewusst NICHT enthalten
            foodCatalog: [food],
            preferences: UserNutritionPreferences()
        )
        guard case .success(let p) = result else { XCTFail("Erwartet .success"); return }
        XCTAssertEqual(p.changes.count, 2)
        let proposedIDs = p.changes.map(\.proposedRecipeID)
        XCTAssertEqual(Set(proposedIDs).count, 2,
                       "Zwei gleichzeitig unloesbare Slots desselben mealType duerfen nicht denselben Ersatz vorgeschlagen bekommen: \(proposedIDs)")
    }
}
