#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Persisted 1:1 mirror of `FoodCatalogItem` (Core). `catalogID` holds the
/// stable slug from `FoodCatalogItem.id` — named differently from SwiftData's
/// own object identity so `PersistentModel` machinery and the domain
/// identifier never get confused with each other.
@Model
public final class FoodCatalogEntry {
    public var catalogID: String
    public var nameKey: String
    public var category: FoodCategory
    public var kcalPer100g: Double
    public var proteinPer100g: Double
    public var carbsPer100g: Double
    public var fatPer100g: Double
    public var defaultServingGrams: Double?
    public var servingNameKey: String?
    public var pieceWeightGrams: Double?
    public var densityGramsPerMl: Double?

    public init(from item: FoodCatalogItem) {
        self.catalogID = item.id
        self.nameKey = item.nameKey
        self.category = item.category
        self.kcalPer100g = item.kcalPer100g
        self.proteinPer100g = item.proteinPer100g
        self.carbsPer100g = item.carbsPer100g
        self.fatPer100g = item.fatPer100g
        self.defaultServingGrams = item.defaultServingGrams
        self.servingNameKey = item.servingNameKey
        self.pieceWeightGrams = item.pieceWeightGrams
        self.densityGramsPerMl = item.densityGramsPerMl
    }

    /// Round-trips back to the plain Core value type.
    public var asCatalogItem: FoodCatalogItem {
        FoodCatalogItem(
            id: catalogID,
            nameKey: nameKey,
            category: category,
            kcalPer100g: kcalPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            defaultServingGrams: defaultServingGrams,
            servingNameKey: servingNameKey,
            pieceWeightGrams: pieceWeightGrams,
            densityGramsPerMl: densityGramsPerMl
        )
    }
}
#endif
