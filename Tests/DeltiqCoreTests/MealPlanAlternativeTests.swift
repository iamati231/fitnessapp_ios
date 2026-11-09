import XCTest
@testable import DeltiqCore

/// Phase 4.7: Tests für MealPlanGenerator.alternativeRecipe – reine Logiktests ohne SwiftData.
final class MealPlanAlternativeTests: XCTestCase {

    // MARK: - Helpers

    private func makeRecipe(
        id: String,
        mealTypes: [MealType] = [.lunch],
        dietaryTags: [RecipeDietaryTag] = [],
        allergens: [RecipeAllergen] = [],
        allergenVerified: Bool = true
    ) -> Recipe {
        Recipe(
            id: id, nameKey: "test.\(id)",
            mealTypes: mealTypes, dietaryTags: dietaryTags,
            allergens: allergens, allergenVerified: allergenVerified,
            halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
            ingredients: [RecipeIngredient(ingredientID: "chicken_breast_cooked", amountGrams: 100)]
        )
    }

    // MARK: - 1. Einzelne Mahlzeit kann neu generiert werden

    func testAlternativeRecipe_returnsRecipe_whenAvailable() {
        let current = makeRecipe(id: "current")
        let other = makeRecipe(id: "other")
        let result = MealPlanGenerator.alternativeRecipe(
            for: .lunch, excluding: "current", from: [current, other],
            preferences: .init(), seed: 0
        )
        XCTAssertNotNil(result)
    }

    // MARK: - 2. Neues Rezept hat denselben mealType

    func testAlternativeRecipe_matchesMealType() {
        let dinner = makeRecipe(id: "dinner_alt", mealTypes: [.dinner])
        let lunch = makeRecipe(id: "lunch_current", mealTypes: [.lunch])
        let result = MealPlanGenerator.alternativeRecipe(
            for: .dinner, excluding: "other", from: [dinner, lunch],
            preferences: .init(), seed: 0
        )
        XCTAssertEqual(result?.id, "dinner_alt")
    }

    // MARK: - 3. Aktuelles Rezept wird ausgeschlossen

    func testAlternativeRecipe_excludesCurrentRecipe() {
        let current = makeRecipe(id: "current")
        let other = makeRecipe(id: "other")
        for seed in 0..<100 {
            let result = MealPlanGenerator.alternativeRecipe(
                for: .lunch, excluding: "current", from: [current, other],
                preferences: .init(), seed: seed
            )
            XCTAssertNotEqual(result?.id, "current", "current darf nie zurückgegeben werden (seed=\(seed))")
        }
    }

    // MARK: - 4. Dietary Style wird berücksichtigt

    func testAlternativeRecipe_respectsDietaryStyle() {
        let vegan = makeRecipe(id: "vegan", dietaryTags: [.vegan])
        let omnivor = makeRecipe(id: "omnivor", dietaryTags: [])
        let prefs = UserNutritionPreferences(dietaryStyle: .vegan)
        let result = MealPlanGenerator.alternativeRecipe(
            for: .lunch, excluding: "current", from: [vegan, omnivor],
            preferences: prefs, seed: 0
        )
        XCTAssertEqual(result?.id, "vegan", "Nur vegane Rezepte dürfen ausgewählt werden")
    }

    // MARK: - 5. Allergene werden berücksichtigt

    func testAlternativeRecipe_respectsAllergens() {
        let safe = makeRecipe(id: "safe", allergens: [], allergenVerified: true)
        let nuts = makeRecipe(id: "nuts", allergens: [.nuts], allergenVerified: true)
        let prefs = UserNutritionPreferences(allergenExclusions: [.nuts])
        for seed in 0..<20 {
            let result = MealPlanGenerator.alternativeRecipe(
                for: .lunch, excluding: "current", from: [safe, nuts],
                preferences: prefs, seed: seed
            )
            XCTAssertNotEqual(result?.id, "nuts", "Nuss-Allergen muss ausgeschlossen sein (seed=\(seed))")
        }
    }

    // MARK: - 6. Ausgeschlossene Rezepte werden nicht ausgewählt

    func testAlternativeRecipe_respectsExcludedRecipeIDs() {
        let excluded = makeRecipe(id: "excluded")
        let allowed = makeRecipe(id: "allowed")
        let prefs = UserNutritionPreferences(excludedRecipeIDs: ["excluded"])
        for seed in 0..<20 {
            let result = MealPlanGenerator.alternativeRecipe(
                for: .lunch, excluding: "current", from: [excluded, allowed],
                preferences: prefs, seed: seed
            )
            XCTAssertNotEqual(result?.id, "excluded", "Manuell ausgeschlossene Rezepte dürfen nie ausgewählt werden (seed=\(seed))")
        }
    }

    // MARK: - 10. Keine Alternative vorhanden → nil

    func testAlternativeRecipe_returnsNil_whenNoneAvailable() {
        let only = makeRecipe(id: "only")
        let result = MealPlanGenerator.alternativeRecipe(
            for: .lunch, excluding: "only", from: [only],
            preferences: .init(), seed: 0
        )
        XCTAssertNil(result, "Wenn keine Alternative existiert, muss nil zurückgegeben werden")
    }

    func testAlternativeRecipe_returnsNil_whenCatalogEmpty() {
        let result = MealPlanGenerator.alternativeRecipe(
            for: .lunch, excluding: "x", from: [],
            preferences: .init(), seed: 0
        )
        XCTAssertNil(result)
    }

    // MARK: - 11. Wiederholte Neugenerierung liefert Variation

    func testAlternativeRecipe_variesWithSeed() {
        let r0 = makeRecipe(id: "r0")
        let r1 = makeRecipe(id: "r1")
        let r2 = makeRecipe(id: "r2")
        let catalog = [r0, r1, r2]
        // Mit pool.count = 3 und verschiedenen Seeds müssen mindestens 2 verschiedene Rezepte auftauchen
        let results = Set((0..<9).compactMap {
            MealPlanGenerator.alternativeRecipe(
                for: .lunch, excluding: "current",
                from: catalog, preferences: .init(), seed: $0
            )?.id
        })
        XCTAssertGreaterThan(results.count, 1, "Verschiedene Seeds müssen verschiedene Rezepte liefern können")
    }

    // MARK: - Bevorzuge Rezepte, die nicht im selben Plan sind (Soft-Preference)

    func testAlternativeRecipe_prefersFreshOverUsed() {
        let used = makeRecipe(id: "used")
        let fresh = makeRecipe(id: "fresh")
        // Mit seed=0 und pool=[fresh]: fresh muss bevorzugt werden
        let result = MealPlanGenerator.alternativeRecipe(
            for: .lunch, excluding: "current",
            preferExcluding: ["used"],
            from: [used, fresh], preferences: .init(), seed: 0
        )
        XCTAssertEqual(result?.id, "fresh", "Nicht im Plan verwendete Rezepte sollen bevorzugt werden")
    }

    func testAlternativeRecipe_fallsBackToUsed_whenNoFresh() {
        let used = makeRecipe(id: "used")
        // Einzige Alternative ist „used" (current wird exkludiert) → Fallback erlaubt
        let result = MealPlanGenerator.alternativeRecipe(
            for: .lunch, excluding: "current",
            preferExcluding: ["used"],
            from: [used, makeRecipe(id: "current")], preferences: .init(), seed: 0
        )
        XCTAssertEqual(result?.id, "used", "Fallback auf bereits verwendete Rezepte wenn kein frisches verfügbar")
    }
}
