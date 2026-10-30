import XCTest
@testable import FitnessAppCore

/// Tests für MealPlanGenerator — Filterlogik, Allergen-Ausschluss, Determinismus,
/// Kalorien-Skalierung, Repetitions-Reduktion und Fehlerbehandlung.
final class MealPlanGeneratorTests: XCTestCase {

    // MARK: - Testrezepte

    private func makeRecipe(
        id: String,
        mealTypes: [MealType] = [.lunch],
        dietaryTags: [RecipeDietaryTag] = [],
        allergens: [RecipeAllergen] = [],
        allergenVerified: Bool = true
    ) -> Recipe {
        Recipe(
            id: id,
            nameKey: "test.\(id)",
            mealTypes: mealTypes,
            dietaryTags: dietaryTags,
            allergens: allergens,
            allergenVerified: allergenVerified,
            halalVerifiedBy: nil,
            servings: 1,
            prepMinutes: 10,
            ingredients: [
                RecipeIngredient(ingredientID: "chicken_breast_cooked", amountGrams: 100)
            ]
        )
    }

    private func generate(
        date: Date = Date(),
        mealTypes: [MealType] = [.lunch],
        preferences: UserNutritionPreferences = .init(),
        calorieGoal: Int? = nil,
        recent: Set<String> = [],
        recipes: [Recipe]
    ) -> Result<DailyMealPlanValue, MealPlanGenerationError> {
        MealPlanGenerator.generate(
            for: date,
            mealTypes: mealTypes,
            preferences: preferences,
            dailyCalorieGoalKcal: calorieGoal,
            recentRecipeIDs: recent,
            recipeCatalog: recipes,
            foodCatalog: FoodCatalogData.all
        )
    }

    // MARK: - eligibleRecipes: Mahlzeitentyp-Filter

    func testEligibleRecipes_wrongMealType_excluded() {
        let breakfast = makeRecipe(id: "r1", mealTypes: [.breakfast])
        let result = MealPlanGenerator.eligibleRecipes(
            in: [breakfast], for: .lunch, preferences: .init()
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testEligibleRecipes_correctMealType_included() {
        let lunch = makeRecipe(id: "r1", mealTypes: [.lunch])
        let result = MealPlanGenerator.eligibleRecipes(
            in: [lunch], for: .lunch, preferences: .init()
        )
        XCTAssertEqual(result.map(\.id), ["r1"])
    }

    // MARK: - eligibleRecipes: Dietary-Filter

    func testEligibleRecipes_veganFilter_excludesOmnivorRecipe() {
        let omnivor = makeRecipe(id: "r1")  // kein Tag
        let result = MealPlanGenerator.eligibleRecipes(
            in: [omnivor], for: .lunch,
            preferences: .init(dietaryStyle: .vegan)
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testEligibleRecipes_veganFilter_includesVeganRecipe() {
        let vegan = makeRecipe(id: "r1", dietaryTags: [.vegan, .vegetarian])
        let result = MealPlanGenerator.eligibleRecipes(
            in: [vegan], for: .lunch,
            preferences: .init(dietaryStyle: .vegan)
        )
        XCTAssertEqual(result.map(\.id), ["r1"])
    }

    func testEligibleRecipes_vegetarianFilter_veganOnlyTag_includedByHierarchy() {
        // Hierarchie-Fix: vegan ⊂ vegetarisch — veganes Rezept ohne .vegetarian-Tag muss sichtbar sein
        let vegan = makeRecipe(id: "r1", dietaryTags: [.vegan])
        let result = MealPlanGenerator.eligibleRecipes(
            in: [vegan], for: .lunch,
            preferences: .init(dietaryStyle: .vegetarian)
        )
        XCTAssertFalse(result.isEmpty, "Veganes Rezept muss für Vegetarier sichtbar sein (vegan ⊂ vegetarisch)")
    }

    // MARK: - eligibleRecipes: Allergen-Ausschluss

    func testEligibleRecipes_allergenFilter_unverifiedAlwaysExcluded() {
        let unverified = makeRecipe(id: "r1", allergens: [], allergenVerified: false)
        let result = MealPlanGenerator.eligibleRecipes(
            in: [unverified], for: .lunch,
            preferences: .init(allergenExclusions: [.gluten])
        )
        XCTAssertTrue(result.isEmpty,
            "Unverifiziertes Rezept muss bei aktivem Allergenfilter ausgeschlossen werden")
    }

    func testEligibleRecipes_allergenFilter_verifiedWithMatchingAllergen_excluded() {
        let glutenRecipe = makeRecipe(id: "r1", allergens: [.gluten], allergenVerified: true)
        let result = MealPlanGenerator.eligibleRecipes(
            in: [glutenRecipe], for: .lunch,
            preferences: .init(allergenExclusions: [.gluten])
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testEligibleRecipes_allergenFilter_verifiedWithoutAllergen_included() {
        let safe = makeRecipe(id: "r1", allergens: [.eggs], allergenVerified: true)
        let result = MealPlanGenerator.eligibleRecipes(
            in: [safe], for: .lunch,
            preferences: .init(allergenExclusions: [.gluten])
        )
        XCTAssertEqual(result.map(\.id), ["r1"])
    }

    func testEligibleRecipes_noAllergenFilter_unverifiedIncluded() {
        let unverified = makeRecipe(id: "r1", allergenVerified: false)
        let result = MealPlanGenerator.eligibleRecipes(
            in: [unverified], for: .lunch, preferences: .init()
        )
        XCTAssertEqual(result.map(\.id), ["r1"])
    }

    // MARK: - eligibleRecipes: Manuelle Ausschlüsse

    func testEligibleRecipes_excludedRecipeID_excluded() {
        let recipe = makeRecipe(id: "r1")
        let result = MealPlanGenerator.eligibleRecipes(
            in: [recipe], for: .lunch,
            preferences: .init(excludedRecipeIDs: ["r1"])
        )
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - generate: Fehler bei leerem Pool

    func testGenerate_noSuitableRecipe_returnsFailure() {
        let result = generate(mealTypes: [.dinner], preferences: .init(dietaryStyle: .vegan), recipes: [])
        if case .failure(let err) = result {
            XCTAssertEqual(err, .noSuitableRecipe(mealType: .dinner))
        } else {
            XCTFail("Erwartete .failure(.noSuitableRecipe)")
        }
    }

    // MARK: - generate: Warnung bei < 2 Rezepten

    func testGenerate_oneRecipeAvailable_setsWarning() throws {
        let recipe = makeRecipe(id: "r1", mealTypes: [.lunch])
        let plan = try XCTUnwrap(generate(recipes: [recipe]).get())
        XCTAssertNotNil(plan.insufficientSelectionWarning)
        XCTAssertEqual(plan.assignments.count, 1)
    }

    func testGenerate_twoRecipesAvailable_noWarning() throws {
        let r1 = makeRecipe(id: "r1", mealTypes: [.lunch])
        let r2 = makeRecipe(id: "r2", mealTypes: [.lunch])
        let plan = try XCTUnwrap(generate(recipes: [r1, r2]).get())
        XCTAssertNil(plan.insufficientSelectionWarning)
    }

    // MARK: - generate: Repetitions-Reduktion

    func testGenerate_avoidsRecentRecipes_whenFreshAvailable() throws {
        let recent = makeRecipe(id: "recent", mealTypes: [.lunch])
        let fresh = makeRecipe(id: "fresh", mealTypes: [.lunch])
        let plan = try XCTUnwrap(
            generate(recent: ["recent"], recipes: [recent, fresh]).get()
        )
        XCTAssertEqual(plan.assignments.first?.recipeID, "fresh",
            "Frisches Rezept soll bevorzugt werden wenn kürzlich nicht verwendet")
    }

    func testGenerate_allRecentRecipes_fallsBackToAny() throws {
        let r1 = makeRecipe(id: "r1", mealTypes: [.lunch])
        let r2 = makeRecipe(id: "r2", mealTypes: [.lunch])
        let plan = try XCTUnwrap(
            generate(recent: ["r1", "r2"], recipes: [r1, r2]).get()
        )
        XCTAssertFalse(plan.assignments.isEmpty)
    }

    // MARK: - generate: Determinismus

    func testGenerate_sameDateSameInputs_sameResult() throws {
        let recipes = (1...5).map { makeRecipe(id: "r\($0)", mealTypes: [.lunch]) }
        let date = Date(timeIntervalSince1970: 1_000_000)

        let plan1 = try XCTUnwrap(generate(date: date, recipes: recipes).get())
        let plan2 = try XCTUnwrap(generate(date: date, recipes: recipes).get())
        XCTAssertEqual(plan1, plan2, "Gleiche Inputs müssen gleiche Ergebnisse liefern")
    }

    // MARK: - generate: Mehrere Slots

    func testGenerate_multipleSlots_oneAssignmentPerSlot() throws {
        let bRecipe = makeRecipe(id: "b1", mealTypes: [.breakfast])
        let lRecipe = makeRecipe(id: "l1", mealTypes: [.lunch])
        let dRecipe = makeRecipe(id: "d1", mealTypes: [.dinner])

        let plan = try XCTUnwrap(
            generate(mealTypes: [.breakfast, .lunch, .dinner],
                     recipes: [bRecipe, lRecipe, dRecipe]).get()
        )
        XCTAssertEqual(plan.assignments.count, 3)
        XCTAssertTrue(plan.assignments.contains { $0.mealType == .breakfast })
        XCTAssertTrue(plan.assignments.contains { $0.mealType == .lunch })
        XCTAssertTrue(plan.assignments.contains { $0.mealType == .dinner })
    }

    // MARK: - scaleToNutritionGoals: Klammerung

    func testScaleToNutritionGoals_clampsToMaximum() {
        let assignment = MealPlanAssignmentValue(recipeID: "chicken_rice_bowl", mealType: .lunch, portionMultiplier: 1.0)
        let (scaled, _) = MealPlanGenerator.scaleToNutritionGoals(
            [assignment], calorieGoalKcal: 99999, proteinGoalG: nil, carbGoalG: nil, fatGoalG: nil,
            recipes: RecipeCatalogData.all, foodCatalog: FoodCatalogData.all
        )
        XCTAssertLessThanOrEqual(scaled.first?.portionMultiplier ?? 0, 2.5)
    }

    func testScaleToNutritionGoals_clampsToMinimum() {
        let assignment = MealPlanAssignmentValue(recipeID: "chicken_rice_bowl", mealType: .lunch, portionMultiplier: 1.0)
        let (scaled, _) = MealPlanGenerator.scaleToNutritionGoals(
            [assignment], calorieGoalKcal: 1, proteinGoalG: nil, carbGoalG: nil, fatGoalG: nil,
            recipes: RecipeCatalogData.all, foodCatalog: FoodCatalogData.all
        )
        XCTAssertGreaterThanOrEqual(scaled.first?.portionMultiplier ?? 0, 0.5)
    }

    // MARK: - scaleToNutritionGoals: Makroziele

    func testScaleToNutritionGoals_proteinGoalOnly_clampsToMax() {
        // Extrem hohes Proteinziel → Skalierung maximal 2.5
        let assignment = MealPlanAssignmentValue(recipeID: "chicken_rice_bowl", mealType: .lunch, portionMultiplier: 1.0)
        let (scaled, _) = MealPlanGenerator.scaleToNutritionGoals(
            [assignment], calorieGoalKcal: nil, proteinGoalG: 99999, carbGoalG: nil, fatGoalG: nil,
            recipes: RecipeCatalogData.all, foodCatalog: FoodCatalogData.all
        )
        XCTAssertEqual(scaled.first?.portionMultiplier ?? 0, 2.5, accuracy: 0.001)
    }

    func testScaleToNutritionGoals_goalConflict_emitsWarning() {
        // Kalorienziel → ×0.5 (extrem niedrig), Proteinziel → ×2.5 (extrem hoch): Konflikt
        let assignment = MealPlanAssignmentValue(recipeID: "chicken_rice_bowl", mealType: .lunch, portionMultiplier: 1.0)
        let (_, warning) = MealPlanGenerator.scaleToNutritionGoals(
            [assignment], calorieGoalKcal: 1, proteinGoalG: 99999, carbGoalG: nil, fatGoalG: nil,
            recipes: RecipeCatalogData.all, foodCatalog: FoodCatalogData.all
        )
        XCTAssertNotNil(warning, "Zielkonflikt muss Warnung setzen")
        XCTAssertTrue(warning?.contains("Zielkonflikt") == true, "Warnung muss 'Zielkonflikt' enthalten")
    }

    // MARK: - scaleToNutritionGoals: Leerer Katalog

    func testScaleToNutritionGoals_emptyFoodCatalog_emitsWarning() {
        let assignment = MealPlanAssignmentValue(recipeID: "chicken_rice_bowl", mealType: .lunch, portionMultiplier: 1.0)
        let (scaled, warning) = MealPlanGenerator.scaleToNutritionGoals(
            [assignment], calorieGoalKcal: 2000, proteinGoalG: nil, carbGoalG: nil, fatGoalG: nil,
            recipes: RecipeCatalogData.all, foodCatalog: []
        )
        XCTAssertNotNil(warning, "Leerer Katalog muss Warnung setzen")
        XCTAssertTrue(warning?.contains("Lebensmittelkatalog") == true)
        XCTAssertEqual(scaled.first?.portionMultiplier ?? 0, 1.0, accuracy: 0.001,
            "Portionen dürfen bei fehlendem Katalog nicht verändert werden")
    }

    func testGenerate_emptyFoodCatalog_withCalorieGoal_emitsWarning() throws {
        let r1 = makeRecipe(id: "r1", mealTypes: [.lunch])
        let r2 = makeRecipe(id: "r2", mealTypes: [.lunch])
        let plan = try XCTUnwrap(MealPlanGenerator.generate(
            for: Date(timeIntervalSince1970: 1_000_000),
            mealTypes: [.lunch],
            preferences: .init(),
            dailyCalorieGoalKcal: 2000,
            recentRecipeIDs: [],
            recipeCatalog: [r1, r2],
            foodCatalog: []
        ).get())
        XCTAssertNotNil(plan.insufficientSelectionWarning, "Fehlender Katalog bei gesetztem Ziel muss Warnung setzen")
    }

    // MARK: - scaleToNutritionGoals: Unbekannte Nährwerte

    func testScaleToNutritionGoals_unknownIngredient_cannotScale_emitsWarning() {
        // Rezept mit nicht im Katalog enthaltener Zutat → Nährwerte unberechenbar → kein Scaling
        let unknownRecipe = Recipe(
            id: "test_unknown_ingr",
            nameKey: "test.unknown",
            mealTypes: [.lunch],
            dietaryTags: [],
            allergens: [],
            allergenVerified: true,
            halalVerifiedBy: nil,
            servings: 1,
            prepMinutes: 5,
            ingredients: [RecipeIngredient(ingredientID: "nonexistent_xyz", amountGrams: 100)]
        )
        let assignment = MealPlanAssignmentValue(recipeID: "test_unknown_ingr", mealType: .lunch, portionMultiplier: 1.0)
        let (scaled, warning) = MealPlanGenerator.scaleToNutritionGoals(
            [assignment], calorieGoalKcal: 2000, proteinGoalG: nil, carbGoalG: nil, fatGoalG: nil,
            recipes: [unknownRecipe], foodCatalog: FoodCatalogData.all
        )
        XCTAssertNotNil(warning, "Unbekannte Zutat muss Warnung setzen")
        XCTAssertEqual(scaled.first?.portionMultiplier ?? 0, 1.0, accuracy: 0.001,
            "Portionen dürfen bei unbekannten Nährwerten nicht verändert werden")
    }

    // MARK: - Ernährungsfilter-Hierarchie

    func testMatchesDietaryStyle_veganIncludedForVegetarian() {
        let vegan = makeRecipe(id: "r1", dietaryTags: [.vegan])
        XCTAssertTrue(MealPlanGenerator.matchesDietaryStyle(vegan, style: .vegetarian),
            "Veganes Rezept gilt implizit als vegetarisch (vegan ⊂ vegetarisch)")
    }

    func testMatchesDietaryStyle_veganIncludedForPescetarian() {
        let vegan = makeRecipe(id: "r1", dietaryTags: [.vegan])
        XCTAssertTrue(MealPlanGenerator.matchesDietaryStyle(vegan, style: .pescetarian),
            "Veganes Rezept gilt implizit als pescetarisch")
    }

    func testMatchesDietaryStyle_vegetarianIncludedForPescetarian() {
        let vegetarian = makeRecipe(id: "r1", dietaryTags: [.vegetarian])
        XCTAssertTrue(MealPlanGenerator.matchesDietaryStyle(vegetarian, style: .pescetarian),
            "Vegetarisches Rezept gilt implizit als pescetarisch")
    }

    func testEligibleRecipes_pescetarianFilter_vegetarianTag_included() {
        let vegetarian = makeRecipe(id: "r1", mealTypes: [.lunch], dietaryTags: [.vegetarian])
        let result = MealPlanGenerator.eligibleRecipes(
            in: [vegetarian], for: .lunch,
            preferences: .init(dietaryStyle: .pescetarian)
        )
        XCTAssertFalse(result.isEmpty, "Vegetarisches Rezept muss für Pescetarier sichtbar sein")
    }
}
