#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Eine Rezept-Zuweisung innerhalb eines `DailyMealPlan`.
/// `recipeID` ist ein String-Scalar (kein @Relationship) — Rezepte sind Bundle-Ressourcen,
/// kein SwiftData-Modell. Löschen/Ändern eines Rezepts darf historische Pläne nie mitreißen.
@Model
public final class PlannedMealAssignment {
    /// Stabile Rezept-ID aus `Recipe.id` (recipes.json).
    public var recipeID: String
    public var mealTypeRaw: String
    /// Portions-Multiplikator relativ zu `Recipe.servings` (0.5..2.5).
    public var portionMultiplier: Double

    public var plan: DailyMealPlan?

    public var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    public init(recipeID: String, mealType: MealType, portionMultiplier: Double = 1.0) {
        self.recipeID = recipeID
        self.mealTypeRaw = mealType.rawValue
        self.portionMultiplier = portionMultiplier
    }
}
#endif
