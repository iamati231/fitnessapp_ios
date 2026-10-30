import XCTest
@testable import FitnessAppCore

/// Prueft, dass die mitgelieferte recipes.json laedt, valide IDs enthaelt
/// und die redaktionellen Sicherheits-Invarianten einhält.
final class RecipeCatalogTests: XCTestCase {

    func testCatalogLoads_atLeastFiveRecipes() {
        XCTAssertGreaterThanOrEqual(
            RecipeCatalogData.all.count, 5,
            "recipes.json muss mindestens 5 Testrezepte enthalten"
        )
    }

    func testAllIngredientIDs_existInFoodCatalog() {
        let catalogIDs = Set(FoodCatalogData.all.map(\.id))
        for recipe in RecipeCatalogData.all {
            for ingredient in recipe.ingredients {
                XCTAssertTrue(
                    catalogIDs.contains(ingredient.ingredientID),
                    "Unbekannte Zutaten-ID '\(ingredient.ingredientID)' in Rezept '\(recipe.id)'"
                )
            }
        }
    }

    // MARK: - Halal-Invariante (DEL-Ernährungsplaner, Spec §2)

    func testHalalTagRequiresHalalVerifiedBy() {
        // Kein Rezept darf halalVerifiedBy==nil haben UND gleichzeitig
        // einen Halal-Verweis erwarten — dieser Test prueft die Umkehrung:
        // alle halalVerifiedBy==nil Rezepte enthalten KEINEN halal-Hinweis im nameKey.
        // (Vollstaendiger Halal-Tag-Check erst wenn dietaryTags Halal unterstuetzt.)
        for recipe in RecipeCatalogData.all where recipe.halalVerifiedBy == nil {
            XCTAssertFalse(
                recipe.isHalalVerified,
                "Rezept '\(recipe.id)': isHalalVerified muss false sein wenn halalVerifiedBy nil ist"
            )
        }
    }

    // MARK: - Allergen-Invariante (DEL-Ernährungsplaner, Spec §3)

    func testAllFiveTestRecipes_haveAllergenVerifiedTrue() {
        let expected = ["chicken_rice_bowl", "oatmeal_berry_skyr", "red_lentil_soup",
                        "greek_yogurt_bowl", "tuna_salad"]
        let byID = Dictionary(uniqueKeysWithValues: RecipeCatalogData.all.map { ($0.id, $0) })
        for id in expected {
            let recipe = byID[id]
            XCTAssertNotNil(recipe, "Testrezept '\(id)' fehlt in recipes.json")
            XCTAssertTrue(
                recipe?.allergenVerified ?? false,
                "Testrezept '\(id)' muss allergenVerified=true haben"
            )
        }
    }

    func testNutritionCalculable_forAllVerifiedRecipes() {
        let catalog = FoodCatalogData.all
        for recipe in RecipeCatalogData.all {
            let result = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog)
            if case .failure(let err) = result {
                XCTFail("Naehrwertberechnung fuer '\(recipe.id)' schlug fehl: \(err)")
            }
        }
    }
}
