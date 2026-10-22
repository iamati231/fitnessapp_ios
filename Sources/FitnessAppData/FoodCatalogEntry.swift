#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Herkunft eines `FoodCatalogEntry` — unterscheidet die ~100 geseedeten
/// Referenz-Eintraege (werden nie geloescht, nie exportiert) von Eintraegen,
/// die der Nutzer selbst angelegt hat (online uebernommen oder manuell
/// erfasst). Siehe `UserDataWipe.deleteSharedUserData` und
/// `DataExportService`/`DataImportService` (`custom_food_catalog.csv`).
public enum FoodCatalogEntrySource: String, Codable, Sendable {
    case seeded
    case onlineImported
    case userCreated
}

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
    /// Additiv. Default `.seeded` greift automatisch fuer alle bestehenden
    /// Zeilen UND fuer jeden ueber `init(from:)` angelegten Eintrag (die
    /// Seed-Quelle) — niemals explizit hier gesetzt.
    public var source: FoodCatalogEntrySource = FoodCatalogEntrySource.seeded
    /// Additiv, `nil` fuer geseedete Eintraege (die nutzen `nameKey` ueber
    /// `Localizable.xcstrings`). Online-importierte/manuell angelegte
    /// Eintraege haben keinen Lokalisierungs-Key — der Klartext-Name vom
    /// Nutzer/aus der Online-Quelle hat Vorrang, siehe `AddMealView.
    /// resolvedName(for:)`.
    public var displayName: String?

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

    /// Fuer online-importierte/manuell angelegte Eintraege (Task 4/6 der
    /// Online-Food-Lookup-SDD). Bewusst skalare Parameter statt
    /// `OnlineFoodCandidate` direkt: `FitnessAppData` importiert
    /// `FitnessAppFoodLookup` nicht, die UI-Schicht mappt dort hin.
    public convenience init(
        displayName: String,
        source: FoodCatalogEntrySource,
        category: FoodCategory,
        kcalPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        pieceWeightGrams: Double? = nil,
        densityGramsPerMl: Double? = nil
    ) {
        self.init(from: FoodCatalogItem(
            id: UUID().uuidString,
            nameKey: "",
            category: category,
            kcalPer100g: kcalPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            pieceWeightGrams: pieceWeightGrams,
            densityGramsPerMl: densityGramsPerMl
        ))
        self.source = source
        self.displayName = displayName
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
