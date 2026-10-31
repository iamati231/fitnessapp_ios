import Foundation

/// Zutat eines Rezepts — referenziert `FoodCatalogItem.id` und gibt die
/// Grammenge fuer die Gesamtrezeptur (alle Portionen zusammen) an.
public struct RecipeIngredient: Sendable, Codable, Equatable {
    /// Referenz auf `FoodCatalogItem.id`. Eine unbekannte ID macht die
    /// Naehrwertberechnung unmoeglich — `RecipeNutritionCalculator` gibt
    /// dann `.failure(.unknownIngredient(id:))` zurueck.
    public let ingredientID: String
    /// Grammenge fuer die Gesamtrezeptur (nicht pro Portion).
    public let amountGrams: Double
}
