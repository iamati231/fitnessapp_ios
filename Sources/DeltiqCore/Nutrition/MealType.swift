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

    /// Schlägt basierend auf der Uhrzeit einen Mahlzeitentyp vor.
    /// 05–10 Uhr → Frühstück, 11–14 → Mittagessen, 17–21 → Abendessen, sonst Snack.
    public static func suggested(for date: Date = Date()) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:  return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default:      return .snack
        }
    }
}
