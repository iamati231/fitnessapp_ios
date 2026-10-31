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
    /// Naehrwerte pro 100 g/ml. Geseedete, selbst angelegte und alle vor
    /// OFF-01 gespeicherten Eintraege sind vollstaendig. Bei online aus Open
    /// Food Facts uebernommenen Eintraegen kann ein einzelner Wert fehlen:
    /// er steht dann als Platzhalter in diesem Feld und wird ueber
    /// `nutrientsPer100g` (gemeinsam mit `knownNutrientMaskRaw`) als
    /// `.unknown` gelesen — nie als inhaltliche `0`.
    public var kcalPer100g: Double
    public var proteinPer100g: Double
    public var carbsPer100g: Double
    public var fatPer100g: Double
    public var defaultServingGrams: Double?
    public var servingNameKey: String?
    public var pieceWeightGrams: Double?
    public var densityGramsPerMl: Double?
    /// Additiv, als rohe `String` gespeichert (nicht als Enum direkt) —
    /// gleiches Muster wie `MealItem.unitRaw`/`unit`: ein neues Nicht-Optional
    /// `@Model`-Feld vom Typ eines `Codable`-Enums bekommt bei SwiftDatas
    /// Lightweight-Migration auf bereits bestehenden Zeilen KEINEN
    /// zuverlaessigen Default und fuehrt beim Lesen zu einem
    /// `swift_dynamicCastFailure`-Crash (siehe TestFlight-Crash Build 173,
    /// `FoodCatalogEntry.source.getter`). Ein primitiver `String`-Default wird
    /// dagegen zuverlaessig fuer Alt-Zeilen zurueckgegeben.
    public var sourceRaw: String = FoodCatalogEntrySource.seeded.rawValue
    public var source: FoodCatalogEntrySource {
        get { FoodCatalogEntrySource(rawValue: sourceRaw) ?? .seeded }
        set { sourceRaw = newValue.rawValue }
    }
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
        self.kcalPer100g = item.kcalPer100g.value ?? FoodCatalogEntry.unknownPlaceholder
        self.proteinPer100g = item.proteinPer100g.value ?? FoodCatalogEntry.unknownPlaceholder
        self.carbsPer100g = item.carbsPer100g.value ?? FoodCatalogEntry.unknownPlaceholder
        self.fatPer100g = item.fatPer100g.value ?? FoodCatalogEntry.unknownPlaceholder
        self.knownNutrientMaskRaw = KnownValue.mask(
            kcal: !item.kcalPer100g.isUnknown,
            protein: !item.proteinPer100g.isUnknown,
            carbs: !item.carbsPer100g.isUnknown,
            fat: !item.fatPer100g.isUnknown
        )
        self.defaultServingGrams = item.defaultServingGrams
        self.servingNameKey = item.servingNameKey
        self.pieceWeightGrams = item.pieceWeightGrams
        self.densityGramsPerMl = item.densityGramsPerMl
    }

    /// Fuer online-importierte/manuell angelegte Eintraege (Task 4/6 der
    /// Online-Food-Lookup-SDD). Bewusst skalare Parameter statt
    /// `OnlineFoodCandidate` direkt: `FitnessAppData` importiert
    /// `FitnessAppFoodLookup` nicht, die UI-Schicht mappt dort hin.
    ///
    /// OFF-01: Die vier Naehrwerte sind bewusst `Double?` — Open Food Facts
    /// liefert regelmaessig unvollstaendige Makros. Ein fehlender Wert wird
    /// als `nil` GESPEICHERT (unbekannt) und nie zu `0` gemacht; gelesen wird
    /// er ueber `nutrientsPer100g`, das "0 g" und "unbekannt" unterscheidet.
    public convenience init(
        displayName: String,
        source: FoodCatalogEntrySource,
        category: FoodCategory,
        kcalPer100g: Double?,
        proteinPer100g: Double?,
        carbsPer100g: Double?,
        fatPer100g: Double?,
        pieceWeightGrams: Double? = nil,
        densityGramsPerMl: Double? = nil
    ) {
        self.init(from: FoodCatalogItem(
            id: UUID().uuidString,
            nameKey: "",
            category: category,
            nutrientsPer100g: NutrientValues(
                kcal: kcalPer100g,
                proteinG: proteinPer100g,
                carbsG: carbsPer100g,
                fatG: fatPer100g
            ),
            pieceWeightGrams: pieceWeightGrams,
            densityGramsPerMl: densityGramsPerMl
        ))
        self.source = source
        self.displayName = displayName
    }

    /// Platzhalter-Zahl, die fuer einen unbekannten Wert gespeichert wird.
    /// Bewusst `0` und keine nullable Spalte: SwiftData bekommt fuer ein
    /// additiv hinzugefuegtes Nicht-Optional-Feld keinen zuverlaessigen
    /// Default (siehe `sourceRaw`-Doku). Ob der Wert inhaltlich gilt,
    /// entscheidet allein `knownNutrientMaskRaw` — beide werden immer
    /// gemeinsam gesetzt (`init(from:)`/`init(displayName:...)`).
    static let unknownPlaceholder: Double = 0

    /// Bitzmaske: Bit 0 = kcal, 1 = Protein, 2 = Kohlenhydrate, 3 = Fett.
    /// Additiv mit Default `0b1111` ("alle bekannt", `KnownValue.allKnownMask`)
    /// — fuer jede vor OFF-01 gespeicherte Zeile ist das der korrekte Wert,
    /// weil dort alle vier Felder echter Inhalt sind.
    public var knownNutrientMaskRaw: Int = KnownValue.allKnownMask

    /// Naehrwerte pro 100 g/ml als Wertetyp mit explizitem `unknown`.
    public var nutrientsPer100g: NutrientValues {
        NutrientValues(
            kcal: KnownValue((knownNutrientMaskRaw & 1) != 0 ? kcalPer100g : nil),
            proteinG: KnownValue((knownNutrientMaskRaw & 2) != 0 ? proteinPer100g : nil),
            carbsG: KnownValue((knownNutrientMaskRaw & 4) != 0 ? carbsPer100g : nil),
            fatG: KnownValue((knownNutrientMaskRaw & 8) != 0 ? fatPer100g : nil)
        )
    }

    /// Round-trips back to the plain Core value type.
    public var asCatalogItem: FoodCatalogItem {
        let nutrients = nutrientsPer100g
        return FoodCatalogItem(
            id: catalogID,
            nameKey: nameKey,
            category: category,
            // Der Vollstaendig-Konstruktor nimmt bekannte `Double`s; `.unknown`
            // wird ueber `knownNutrientMaskRaw` nach dem Bau wieder hergestellt.
            kcalPer100g: nutrients.kcal.value ?? 0,
            proteinPer100g: nutrients.proteinG.value ?? 0,
            carbsPer100g: nutrients.carbsG.value ?? 0,
            fatPer100g: nutrients.fatG.value ?? 0,
            defaultServingGrams: defaultServingGrams,
            servingNameKey: servingNameKey,
            pieceWeightGrams: pieceWeightGrams,
            densityGramsPerMl: densityGramsPerMl
        ).withNutrients(nutrients)
    }
}
#endif
