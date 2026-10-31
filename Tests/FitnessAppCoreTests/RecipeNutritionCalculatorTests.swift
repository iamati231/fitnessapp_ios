import XCTest
@testable import FitnessAppCore

final class RecipeNutritionCalculatorTests: XCTestCase {

    // MARK: - Fixtures

    private let chicken = FoodCatalogItem(
        id: "chicken", nameKey: "chicken", category: .meat,
        kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 1, fatPer100g: 4
    )
    private let rice = FoodCatalogItem(
        id: "rice", nameKey: "rice", category: .grain,
        kcalPer100g: 130, proteinPer100g: 2, carbsPer100g: 28, fatPer100g: 0.4
    )
    private lazy var catalog = [chicken, rice]

    private func makeRecipe(servings: Int = 1, ingredients: [RecipeIngredient]) -> Recipe {
        Recipe(
            id: "test", nameKey: "test", mealTypes: [.lunch],
            dietaryTags: [], allergens: [], allergenVerified: true,
            halalVerifiedBy: nil, servings: servings, prepMinutes: 10,
            ingredients: ingredients
        )
    }

    // MARK: - Portion scaling

    func testOnePortion_singleIngredient() {
        // 200 g Chicken @165 kcal/100g, 1 serving → 330 kcal
        let recipe = makeRecipe(ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 200)])
        guard case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog) else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(v.kcal, .known(330))
        XCTAssertEqual(v.proteinG, .known(62))
    }

    func testHalfPortion() {
        // 200 g Chicken, 2 servings → 165 kcal/serving; ×0.5 → 82.5 kcal
        let recipe = makeRecipe(servings: 2, ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 200)])
        guard case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog, portionMultiplier: 0.5) else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(v.kcal, .known(82.5))
    }

    func testOneAndHalfPortions() {
        // 100 g Chicken @165 kcal/100g → 165 kcal; ×1.5 → 247.5
        let recipe = makeRecipe(ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 100)])
        guard case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog, portionMultiplier: 1.5) else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(v.kcal, .known(247.5))
    }

    func testDoublePortions() {
        // 100 g Chicken → 165 kcal; ×2 → 330
        let recipe = makeRecipe(ingredients: [RecipeIngredient(ingredientID: "chicken", amountGrams: 100)])
        guard case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog, portionMultiplier: 2.0) else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(v.kcal, .known(330))
    }

    func testMultiServingRecipePerServing() {
        // 400 g Rice, 4 servings → 100 g/serving → 130 kcal
        let recipe = makeRecipe(servings: 4, ingredients: [RecipeIngredient(ingredientID: "rice", amountGrams: 400)])
        guard case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog, portionMultiplier: 1.0) else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(v.kcal, .known(130))
    }

    // MARK: - Multi-ingredient summing

    func testMultiIngredientSum() {
        // 100 g chicken (165 kcal) + 100 g rice (130 kcal) = 295 kcal
        let recipe = makeRecipe(ingredients: [
            RecipeIngredient(ingredientID: "chicken", amountGrams: 100),
            RecipeIngredient(ingredientID: "rice", amountGrams: 100)
        ])
        guard case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog) else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(v.kcal, .known(295))
    }

    // MARK: - Unknown nutrients (OFF-01)

    func testUnknownNutrientPropagatesAsUnknown() {
        // Fat is nil → must remain .unknown, never treated as 0.
        let item = FoodCatalogItem(
            id: "item_no_fat", nameKey: "item_no_fat", category: .other,
            nutrientsPer100g: NutrientValues(kcal: 100, proteinG: 5, carbsG: 10, fatG: nil)
        )
        let recipe = makeRecipe(ingredients: [RecipeIngredient(ingredientID: "item_no_fat", amountGrams: 100)])
        guard case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: [item]) else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(v.kcal, .known(100))
        XCTAssertEqual(v.fatG, .unknown, "Unknown fat must not be treated as 0")
    }

    func testUnknownNutrientScaledStaysUnknown() {
        // Scaling does NOT resolve an unknown value to a number.
        let item = FoodCatalogItem(
            id: "item_no_fat2", nameKey: "item_no_fat2", category: .other,
            nutrientsPer100g: NutrientValues(kcal: 200, proteinG: 10, carbsG: 20, fatG: nil)
        )
        let recipe = makeRecipe(ingredients: [RecipeIngredient(ingredientID: "item_no_fat2", amountGrams: 100)])
        guard case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: [item], portionMultiplier: 1.5) else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(v.kcal, .known(300))
        XCTAssertEqual(v.fatG, .unknown)
    }

    // MARK: - Missing ingredient

    func testUnknownIngredientIDReturnsFailure() {
        let recipe = makeRecipe(ingredients: [RecipeIngredient(ingredientID: "no_such_id", amountGrams: 100)])
        let result = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog)
        XCTAssertEqual(result, .failure(.unknownIngredient(id: "no_such_id")))
    }

    // MARK: - Boundary: zero multiplier

    func testZeroPortionMultiplierYieldsKnownZero() {
        // Per NutrientValues.scaled(_:by:): factor == 0 → .known(0) even for unknown values.
        // 0 g of anything contains 0 kcal, regardless of nutrient density.
        let item = FoodCatalogItem(
            id: "item_for_zero", nameKey: "item_for_zero", category: .other,
            nutrientsPer100g: NutrientValues(kcal: 100, proteinG: 5, carbsG: 10, fatG: nil)
        )
        let recipe = makeRecipe(ingredients: [RecipeIngredient(ingredientID: "item_for_zero", amountGrams: 100)])
        guard case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: [item], portionMultiplier: 0.0) else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(v.kcal, .known(0))
        XCTAssertEqual(v.fatG, .known(0), "Zero factor must yield known(0), not unknown")
    }
}
