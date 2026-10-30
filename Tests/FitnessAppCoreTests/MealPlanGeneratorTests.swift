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

    func testEligibleRecipes_vegetarianFilter_veganOnlyTag_excluded() {
        // .vegan-Tag allein reicht nicht für .vegetarian-Filter
        let vegan = makeRecipe(id: "r1", dietaryTags: [.vegan])
        let result = MealPlanGenerator.eligibleRecipes(
            in: [vegan], for: .lunch,
            preferences: .init(dietaryStyle: .vegetarian)
        )
        XCTAssertTrue(result.isEmpty, "Vegetarian-Filter prüft .vegetarian-Tag, nicht .vegan")
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

    // MARK: - scaleToCalorieGoal: Klammerung

    func testScaleToCalorieGoal_clampsToMaximum() {
        // Sehr hohes Ziel → maximal 2.5
        let assignment = MealPlanAssignmentValue(recipeID: "chicken_rice_bowl", mealType: .lunch, portionMultiplier: 1.0)
        let scaled = MealPlanGenerator.scaleToCalorieGoal(
            [assignment], goalKcal: 99999, recipes: RecipeCatalogData.all, foodCatalog: FoodCatalogData.all
        )
        XCTAssertLessThanOrEqual(scaled.first?.portionMultiplier ?? 0, 2.5)
    }

    func testScaleToCalorieGoal_clampsToMinimum() {
        // Sehr niedriges Ziel → mindestens 0.5
        let assignment = MealPlanAssignmentValue(recipeID: "chicken_rice_bowl", mealType: .lunch, portionMultiplier: 1.0)
        let scaled = MealPlanGenerator.scaleToCalorieGoal(
            [assignment], goalKcal: 1, recipes: RecipeCatalogData.all, foodCatalog: FoodCatalogData.all
        )
        XCTAssertGreaterThanOrEqual(scaled.first?.portionMultiplier ?? 0, 0.5)
    }
}
