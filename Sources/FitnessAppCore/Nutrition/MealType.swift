import Foundation

/// Mahlzeit-Kategorie fuer einen `MealEntry` (Data). Mehrere Eintraege mit
/// demselben Typ am selben Tag sind ausdruecklich erlaubt (z.B. zwei Snacks).
public enum MealType: String, Codable, Sendable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    /// xcstrings-Lookup-Key: `nutrition.mealType.{rawValue}.name`. Muster
    /// identisch zu `FoodCategory.localizationKey`.
    public var localizationKey: String {
        "nutrition.mealType.\(rawValue).name"
    }
}
