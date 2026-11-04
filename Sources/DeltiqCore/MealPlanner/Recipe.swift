import Foundation

/// Ein Rezept aus der lokalen Rezeptdatenbank.
/// Geladen aus `recipes.json` via `RecipeCatalogData`.
public struct Recipe: Identifiable, Sendable, Codable, Equatable {
    /// Stabiler Slug — persistenz-relevant fuer spaetere `DailyMealPlan`-
    /// Zuweisungen. Umbenennen erfordert Datenmigration.
    public let id: String
    /// xcstrings-Lookup-Key, Format `"recipe.<id>.name"`.
    public let nameKey: String
    /// Fuer welche Mahlzeiten dieses Rezept geeignet ist.
    public let mealTypes: [MealType]
    /// Redaktionell geprueft — KEIN automatisches Ableiten aus Zutaten.
    public let dietaryTags: [RecipeDietaryTag]
    /// Allergene gemaess EU-LMIV, die in diesem Rezept enthalten sind.
    /// Nur gueltig wenn `allergenVerified == true`.
    public let allergens: [RecipeAllergen]
    /// `true` = Allergen-Liste vollstaendig und geprueft.
    /// `false` = Status unbekannt → bei JEDEM aktiven Ausschluss herausfiltern.
    public let allergenVerified: Bool
    /// Nicht-`nil` nur wenn ein Redakteur die Halal-Eignung explizit
    /// bestaetigt und dokumentiert hat. Niemals automatisch aus
    /// der Zutaten-Abwesenheit von Schweinefleisch ableiten.
    public let halalVerifiedBy: String?
    /// Anzahl Portionen die das Rezept ergibt (Naehrwerte werden geteilt).
    public let servings: Int
    /// Geschaetzte Zubereitungszeit in Minuten.
    public let prepMinutes: Int
    /// Zutatenliste mit Gramm-Angaben fuer die Gesamtrezeptur.
    public let ingredients: [RecipeIngredient]

    public var isHalalVerified: Bool { halalVerifiedBy != nil }
}
