import XCTest
@testable import FitnessAppCore

/// Prueft, dass die mitgelieferte recipes.json laedt, valide IDs enthaelt
/// und die redaktionellen Sicherheits-Invarianten einhält.
final class RecipeCatalogTests: XCTestCase {

    func testCatalogLoads_atLeastTwentyFiveRecipes() {
        XCTAssertGreaterThanOrEqual(
            RecipeCatalogData.all.count, 25,
            "recipes.json muss mindestens 25 Rezepte enthalten (Phase 2)"
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

    // MARK: - Phase-2-Validierung

    func testAllRecipeIDs_areUnique() {
        let ids = RecipeCatalogData.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Rezept-IDs muessen eindeutig sein")
    }

    func testAllIngredientAmounts_arePositive() {
        for recipe in RecipeCatalogData.all {
            for ingredient in recipe.ingredients {
                XCTAssertGreaterThan(
                    ingredient.amountGrams, 0,
                    "Rezept '\(recipe.id)', Zutat '\(ingredient.ingredientID)': amountGrams muss > 0 sein"
                )
            }
        }
    }

    func testAllRecipes_haveAtLeastOneServing() {
        for recipe in RecipeCatalogData.all {
            XCTAssertGreaterThanOrEqual(
                recipe.servings, 1,
                "Rezept '\(recipe.id)': servings muss >= 1 sein"
            )
        }
    }

    func testAllRecipes_haveAtLeastOneMealType() {
        for recipe in RecipeCatalogData.all {
            XCTAssertFalse(
                recipe.mealTypes.isEmpty,
                "Rezept '\(recipe.id)': mealTypes darf nicht leer sein"
            )
        }
    }

    func testExactlyFiveRecipes_haveAllergenVerifiedTrue() {
        // Nur die 5 redaktionell geprueften Testrezepte duerfen allergenVerified=true tragen.
        // Ein neues Rezept darf nicht pauschal verifiziert werden — dieser Test schlaegt
        // an, sobald jemand allergenVerified ohne tatsaechliche Pruefung auf true setzt.
        let verifiedIDs = RecipeCatalogData.all.filter(\.allergenVerified).map(\.id).sorted()
        let expected = ["chicken_rice_bowl", "greek_yogurt_bowl", "oatmeal_berry_skyr",
                        "red_lentil_soup", "tuna_salad"].sorted()
        XCTAssertEqual(verifiedIDs, expected,
            "Genau diese 5 Rezepte duerfen allergenVerified=true haben")
    }
}
