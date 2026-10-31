#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Ein einzelner Eintrag innerhalb einer `MealEntry` (z.B. "150g Haehnchenbrust").
/// `catalogID` ist bewusst ein plainer `String?`-Scalar, KEIN `@Relationship`
/// — identische Begruendung wie `ExerciseTemplate.id`: Loeschen/Aendern des
/// referenzierten `FoodCatalogEntry` darf historische `MealItem`s nie
/// mitreissen. Die Naehrwerte werden deshalb als Snapshot bei `init`
/// eingefroren (flaches Feld-pro-Wert-Muster, siehe `UserBodyProfile`-Doku
/// "Flaches Feld-pro-Wert-Muster... nicht ein JSON-Blob"), statt live aus
/// dem Katalogeintrag gelesen zu werden.
@Model
public final class MealItem {
    /// Stabile Katalog-ID zum Zeitpunkt der Erfassung. `nil` fuer frei
    /// eingegebene (nicht aus dem Katalog stammende) Eintraege. Rein
    /// informativ — Naehrwert-Anzeige liest ausschliesslich den Snapshot.
    public var catalogID: String?
    public var nameSnapshot: String
    public var quantity: Double
    public var unitRaw: String

    public var kcalSnapshot: Double
    public var proteinGSnapshot: Double
    public var carbsGSnapshot: Double
    public var fatGSnapshot: Double

    /// OFF-01: Bitzmaske, welche der vier Snapshot-Werte BEKANNT sind
    /// (Bit 0 = kcal, 1 = Protein, 2 = Kohlenhydrate, 3 = Fett). Additiv mit
    /// Default `0b1111` ("alle bekannt"): jede vor OFF-01 gespeicherte
    /// Position ist vollstaendig, ein fehlender Open-Food-Facts-Wert ist als
    /// `nil` FEHLT im Snapshot sonst nicht von einer echten 0 zu
    /// unterscheiden. Der Platzhalter in den Snapshot-Feldern ist `0` (siehe
    /// `MealItem.unknownPlaceholder`) — inhaltlich gilt der Wert nur, wenn
    /// das Bit gesetzt ist.
    public var knownNutrientMaskRaw: Int = KnownValue.allKnownMask

    /// Platzhalter fuer einen unbekannten Snapshot-Wert (keine nullable
    /// Spalte, gleiche Begruendung wie `FoodCatalogEntry.unknownPlaceholder`).
    public static let unknownPlaceholder: Double = 0

    /// Plaines Backref — die Cascade-Delete-Rule lebt ausschliesslich auf
    /// `MealEntry.items` (siehe dortige Doku).
    public var meal: MealEntry?

    /// Typisierter Zugriff auf `unitRaw`.
    public var unit: FoodUnit {
        get { FoodUnit(rawValue: unitRaw) ?? .gram }
        set { unitRaw = newValue.rawValue }
    }

    /// Typisierter Zugriff auf die vier flachen Snapshot-Felder — unbekannte
    /// Werte bleiben `unknown` (OFF-01), statt als `0` gelesen zu werden.
    public var nutrientsSnapshot: NutrientValues {
        get {
            NutrientValues(
                kcal: KnownValue((knownNutrientMaskRaw & 1) != 0 ? kcalSnapshot : nil),
                proteinG: KnownValue((knownNutrientMaskRaw & 2) != 0 ? proteinGSnapshot : nil),
                carbsG: KnownValue((knownNutrientMaskRaw & 4) != 0 ? carbsGSnapshot : nil),
                fatG: KnownValue((knownNutrientMaskRaw & 8) != 0 ? fatGSnapshot : nil)
            )
        }
        set {
            kcalSnapshot = newValue.kcal.value ?? MealItem.unknownPlaceholder
            proteinGSnapshot = newValue.proteinG.value ?? MealItem.unknownPlaceholder
            carbsGSnapshot = newValue.carbsG.value ?? MealItem.unknownPlaceholder
            fatGSnapshot = newValue.fatG.value ?? MealItem.unknownPlaceholder
            knownNutrientMaskRaw = KnownValue.mask(
                kcal: !newValue.kcal.isUnknown,
                protein: !newValue.proteinG.isUnknown,
                carbs: !newValue.carbsG.isUnknown,
                fat: !newValue.fatG.isUnknown
            )
        }
    }

    public init(catalogID: String?, nameSnapshot: String, quantity: Double, unit: FoodUnit, nutrients: NutrientValues, meal: MealEntry? = nil) {
        self.catalogID = catalogID
        self.nameSnapshot = nameSnapshot
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.kcalSnapshot = nutrients.kcal.value ?? MealItem.unknownPlaceholder
        self.proteinGSnapshot = nutrients.proteinG.value ?? MealItem.unknownPlaceholder
        self.carbsGSnapshot = nutrients.carbsG.value ?? MealItem.unknownPlaceholder
        self.fatGSnapshot = nutrients.fatG.value ?? MealItem.unknownPlaceholder
        self.knownNutrientMaskRaw = KnownValue.mask(
            kcal: !nutrients.kcal.isUnknown,
            protein: !nutrients.proteinG.isUnknown,
            carbs: !nutrients.carbsG.isUnknown,
            fat: !nutrients.fatG.isUnknown
        )
        self.meal = meal
    }
}
#endif
