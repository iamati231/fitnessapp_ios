import Foundation

/// Naehrwertberechnung fuer Rezepte — stapelt `NutritionCalculations.nutrients`
/// ueber alle Zutaten und skaliert auf Portionsgroesse.
///
/// OFF-01-konform: Ein unbekannter Naehrwert in einer Zutat faerbt die
/// entsprechende Dimension des Gesamtergebnisses `unknown`. Niemals als 0.
public enum RecipeNutritionCalculator {

    public enum CalculationError: Swift.Error, Equatable {
        /// Eine Zutaten-ID kommt im uebergebenen Katalog nicht vor.
        case unknownIngredient(id: String)
    }

    /// Naehrwerte pro Portion eines Rezepts.
    ///
    /// - Parameters:
    ///   - recipe: Das Rezept.
    ///   - catalog: Zutatenkatalog — typisch `FoodCatalogData.all`.
    ///   - portionMultiplier: Skalierungsfaktor (1.0 = eine Portion).
    /// - Returns: `.success(NutrientValues)` pro Portion, oder
    ///   `.failure(.unknownIngredient)` wenn eine ID fehlt.
    public static func nutrients(
        for recipe: Recipe,
        catalog: [FoodCatalogItem],
        portionMultiplier: Double = 1.0
    ) -> Result<NutrientValues, CalculationError> {
        let catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        var perIngredient: [NutrientValues] = []
        for ingredient in recipe.ingredients {
            guard let item = catalogByID[ingredient.ingredientID] else {
                return .failure(.unknownIngredient(id: ingredient.ingredientID))
            }
            // Alle Rezeptzutaten sind in Gramm angegeben.
            guard let values = NutritionCalculations.nutrients(for: item, quantity: ingredient.amountGrams, unit: .gram) else {
                // Menge <= 0 ist ein Datenfehler; Position mit 0 g ignorieren.
                continue
            }
            perIngredient.append(values)
        }
        let servings = max(recipe.servings, 1)
        let factor = portionMultiplier / Double(servings)
        return .success(NutrientValues.sum(perIngredient).scaled(by: factor))
    }
}
