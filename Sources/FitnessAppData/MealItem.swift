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

    /// Plaines Backref — die Cascade-Delete-Rule lebt ausschliesslich auf
    /// `MealEntry.items` (siehe dortige Doku).
    public var meal: MealEntry?

    /// Typisierter Zugriff auf `unitRaw`.
    public var unit: FoodUnit {
        get { FoodUnit(rawValue: unitRaw) ?? .gram }
        set { unitRaw = newValue.rawValue }
    }

    /// Typisierter Zugriff auf die vier flachen Snapshot-Felder.
    public var nutrientsSnapshot: NutrientValues {
        get { NutrientValues(kcal: kcalSnapshot, proteinG: proteinGSnapshot, carbsG: carbsGSnapshot, fatG: fatGSnapshot) }
        set {
            kcalSnapshot = newValue.kcal
            proteinGSnapshot = newValue.proteinG
            carbsGSnapshot = newValue.carbsG
            fatGSnapshot = newValue.fatG
        }
    }

    public init(catalogID: String?, nameSnapshot: String, quantity: Double, unit: FoodUnit, nutrients: NutrientValues, meal: MealEntry? = nil) {
        self.catalogID = catalogID
        self.nameSnapshot = nameSnapshot
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.kcalSnapshot = nutrients.kcal
        self.proteinGSnapshot = nutrients.proteinG
        self.carbsGSnapshot = nutrients.carbsG
        self.fatGSnapshot = nutrients.fatG
        self.meal = meal
    }
}
#endif
