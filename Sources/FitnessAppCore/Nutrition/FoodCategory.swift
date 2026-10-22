import Foundation

/// Grobe Einordnung eines `FoodCatalogItem` fuer Filter/Gruppierung in der UI.
/// Muster identisch zu `DashboardWidgetType`: raw-Value ist stabil (keine
/// Rename ohne Migration), keine weitere Logik im Typ.
public enum FoodCategory: String, Codable, Sendable, CaseIterable {
    case meat
    case fish
    case dairy
    case egg
    case grain
    case vegetable
    case fruit
    case legume
    case nutSeed
    case fat
    case beverage
    case sweet
    /// Online-Food-Lookup / manuelle Erfassung: Faenger fuer Eintraege, die
    /// in keine der obigen Gruppen passen (z.B. Fertiggerichte, Mischrezepte).
    case other

    /// xcstrings-Lookup-Key: `nutrition.category.{rawValue}.name`.
    public var localizationKey: String {
        "nutrition.category.\(rawValue).name"
    }
}
