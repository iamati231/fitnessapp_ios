import Foundation

/// Ernährungsstil des Nutzers — steuert die Rezeptauswahl im MealPlanGenerator.
/// Kein automatisches Ableiten aus Zutaten: nur redaktionell oder vom Nutzer gesetzt.
public enum DietaryStyle: String, Codable, CaseIterable, Sendable {
    case omnivor      // Keine Einschränkung
    case vegetarian   // Rezept muss RecipeDietaryTag.vegetarian tragen
    case vegan        // Rezept muss RecipeDietaryTag.vegan tragen
    case pescetarian  // Rezept muss RecipeDietaryTag.pescetarian tragen
}

/// Ernährungspräferenzen des Nutzers für den MealPlanGenerator.
/// Value-Type: wird aus den Flat-Fields in UserBodyProfile befüllt.
public struct UserNutritionPreferences: Equatable, Sendable {
    public var dietaryStyle: DietaryStyle
    /// Ausgeschlossene Allergene. Bei aktivem Ausschluss werden Rezepte mit
    /// `allergenVerified=false` sicher herausgefiltert.
    public var allergenExclusions: Set<RecipeAllergen>
    /// Manuell vom Nutzer ausgeschlossene Rezept-IDs.
    public var excludedRecipeIDs: Set<String>

    public var hasAllergenFilter: Bool { !allergenExclusions.isEmpty }

    public init(
        dietaryStyle: DietaryStyle = .omnivor,
        allergenExclusions: Set<RecipeAllergen> = [],
        excludedRecipeIDs: Set<String> = []
    ) {
        self.dietaryStyle = dietaryStyle
        self.allergenExclusions = allergenExclusions
        self.excludedRecipeIDs = excludedRecipeIDs
    }
}
