import XCTest
@testable import FitnessAppCore

final class RecipeNutritionCalculatorTests: XCTestCase {

    // MARK: - Hilfsdaten

    private let chickenItem = FoodCatalogItem(
        id: "test_chicken", nameKey: "x", category: .meat,
        kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6,
        defaultServingGrams: nil, servingNameKey: nil,
        pieceWeightGrams: nil, densityGramsPerMl: nil
    )

    private func singleIngredientRecipe(
        ingredientID: String = "test_chicken",
        amountGrams: Double = 150,
        servings: Int = 1
    ) -> Recipe {
        Recipe(
            id: "test_recipe",
            nameKey: "test",
            mealTypes: [.lunch],
            dietaryTags: [],
            allergens: [],
            allergenVerified: true,
            halalVerifiedBy: nil,
            servings: servings,
            prepMinutes: 10,
            ingredients: [RecipeIngredient(ingredientID: ingredientID, amountGrams: amountGrams)]
        )
    }

    // MARK: - Grundberechnung

    func testKnownIngredient_returnsCorrectKcalPerServing() throws {
        // 150 g Haehnchen: 165 * 1.5 = 247.5 kcal, 1 Portion
        let result = try XCTUnwrap(
            RecipeNutritionCalculator.nutrients(for: singleIngredientRecipe(), catalog: [chickenItem]).get()
        )
        XCTAssertEqual(result.kcal.value ?? -1, 247.5, accuracy: 0.001)
        XCTAssertEqual(result.proteinG.value ?? -1, 46.5, accuracy: 0.001) // 31 * 1.5
        XCTAssertFalse(result.partiallyKnown)
    }

    func testTwoServings_halvesPerServingNutrients() throws {
        let recipe = singleIngredientRecipe(amountGrams: 300, servings: 2)
        let result = try XCTUnwrap(
            RecipeNutritionCalculator.nutrients(for: recipe, catalog: [chickenItem]).get()
        )
        // 300 g / 2 Portionen = 150 g pro Portion → 247.5 kcal
        XCTAssertEqual(result.kcal.value ?? -1, 247.5, accuracy: 0.001)
    }

    func testPortionMultiplier_scalesResult() throws {
        let result = try XCTUnwrap(
            RecipeNutritionCalculator.nutrients(
                for: singleIngredientRecipe(amountGrams: 150, servings: 1),
                catalog: [chickenItem],
                portionMultiplier: 2.0
            ).get()
        )
        // Doppelte Portion: 247.5 * 2 = 495 kcal
        XCTAssertEqual(result.kcal.value ?? -1, 495.0, accuracy: 0.001)
    }

    // MARK: - Fehlerfaelle

    func testUnknownIngredientID_returnsFailure() {
        let recipe = singleIngredientRecipe(ingredientID: "does_not_exist")
        if case .failure(let err) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: [chickenItem]) {
            XCTAssertEqual(err, .unknownIngredient(id: "does_not_exist"))
        } else {
            XCTFail("Erwartete .failure(.unknownIngredient)")
        }
    }

    func testEmptyCatalog_returnsFailure() {
        if case .failure = RecipeNutritionCalculator.nutrients(for: singleIngredientRecipe(), catalog: []) {
            // pass
        } else {
            XCTFail("Leerer Katalog muss .failure liefern")
        }
    }

    // MARK: - OFF-01: Unbekannte Werte propagieren

    func testPartiallyUnknownIngredient_propagatesUnknownInThatDimension() throws {
        let partialItem = FoodCatalogItem(
            id: "test_chicken",
            nameKey: "x",
            category: .meat,
            nutrientsPer100g: NutrientValues(kcal: 165, proteinG: nil, carbsG: 0, fatG: 3.6)
        )
        let result = try XCTUnwrap(
            RecipeNutritionCalculator.nutrients(for: singleIngredientRecipe(), catalog: [partialItem]).get()
        )
        XCTAssertEqual(result.kcal.value ?? -1, 247.5, accuracy: 0.001)
        XCTAssertTrue(result.proteinG.isUnknown, "Fehlender Proteinwert bleibt unknown — nie 0")
        XCTAssertTrue(result.partiallyKnown)
    }

    // MARK: - Mehrzutaten-Rezept

    func testMultipleIngredients_sumsCorrectly() throws {
        let riceItem = FoodCatalogItem(
            id: "test_rice", nameKey: "x", category: .grain,
            kcalPer100g: 121, proteinPer100g: 2.7, carbsPer100g: 25, fatPer100g: 0.4,
            defaultServingGrams: nil, servingNameKey: nil,
            pieceWeightGrams: nil, densityGramsPerMl: nil
        )
        let recipe = Recipe(
            id: "multi",
            nameKey: "test",
            mealTypes: [.lunch],
            dietaryTags: [],
            allergens: [],
            allergenVerified: true,
            halalVerifiedBy: nil,
            servings: 1,
            prepMinutes: 20,
            ingredients: [
                RecipeIngredient(ingredientID: "test_chicken", amountGrams: 150),
                RecipeIngredient(ingredientID: "test_rice",    amountGrams: 180)
            ]
        )
        let result = try XCTUnwrap(
            RecipeNutritionCalculator.nutrients(for: recipe, catalog: [chickenItem, riceItem]).get()
        )
        // 165*1.5 + 121*1.8 = 247.5 + 217.8 = 465.3 kcal
        XCTAssertEqual(result.kcal.value ?? -1, 465.3, accuracy: 0.01)
    }
}
