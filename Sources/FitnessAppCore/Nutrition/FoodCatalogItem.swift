import Foundation

/// Ein einzelner Lebensmittel-Katalogeintrag. Reiner, unveraenderlicher
/// Werttyp — kein SwiftData-Import, keine Validierung im Typ selbst
/// (Validierung lebt in den Tests/Daten; der Typ wird nur aus
/// vertrauenswuerdigen statischen Literalen in `FoodCatalogData` konstruiert).
///
/// Mengen-Einheiten (Spec 4.2):
/// - Gramm ist die Standardmengeneinheit, immer verfuegbar.
/// - Stueck nur sinnvoll, wenn `pieceWeightGrams` gesetzt ist.
/// - Milliliter nur sinnvoll, wenn `densityGramsPerMl` gesetzt ist — niemals
///   pauschal 1 ml = 1 g annehmen.
public struct FoodCatalogItem: Identifiable, Sendable, Codable {
    /// Stabiler, lesbarer Slug (z. B. `"chicken_breast_raw"`). Persistenz-
    /// relevant fuer spaetere Tasks — nicht umbenennen ohne Migration.
    public let id: String

    /// xcstrings-Lookup-Key, Format `"nutrition.food.{id}.name"`.
    public let nameKey: String

    public let category: FoodCategory

    public let kcalPer100g: Double
    public let proteinPer100g: Double
    public let carbsPer100g: Double
    public let fatPer100g: Double

    /// Optionale Default-Portionsgroesse in Gramm (z. B. fuer "1 Portion"-UI).
    public let defaultServingGrams: Double?

    /// xcstrings-Lookup-Key fuer die Bezeichnung der Default-Portion
    /// (z. B. "1 Scheibe", "1 Glas"), falls `defaultServingGrams` gesetzt ist.
    public let servingNameKey: String?

    /// Gewicht eines Stuecks in Gramm — nur bei stueckbaren Lebensmitteln
    /// (Ei, Scheibe Brot, Banane) gesetzt.
    public let pieceWeightGrams: Double?

    /// Dichte in g/ml — NUR bei echten Fluessigkeiten gesetzt (Milch, Oel,
    /// Wasser, Saft, ...). Niemals pauschal 1.0 annehmen.
    public let densityGramsPerMl: Double?

    public init(
        id: String,
        nameKey: String,
        category: FoodCategory,
        kcalPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        defaultServingGrams: Double? = nil,
        servingNameKey: String? = nil,
        pieceWeightGrams: Double? = nil,
        densityGramsPerMl: Double? = nil
    ) {
        self.id = id
        self.nameKey = nameKey
        self.category = category
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.defaultServingGrams = defaultServingGrams
        self.servingNameKey = servingNameKey
        self.pieceWeightGrams = pieceWeightGrams
        self.densityGramsPerMl = densityGramsPerMl
    }
}
