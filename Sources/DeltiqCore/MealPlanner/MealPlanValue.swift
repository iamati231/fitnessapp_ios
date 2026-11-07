import Foundation

/// Eine einzelne Mahlzeit-Zuweisung innerhalb eines Tagesplans (non-persistent).
public struct MealPlanAssignmentValue: Equatable, Sendable {
    public let recipeID: String
    public let mealType: MealType
    /// Portions-Multiplikator relativ zu Recipe.servings (0.5..2.5).
    public let portionMultiplier: Double

    public init(recipeID: String, mealType: MealType, portionMultiplier: Double = 1.0) {
        self.recipeID = recipeID
        self.mealType = mealType
        self.portionMultiplier = portionMultiplier
    }
}

/// Generierter Tagesplan (non-persistent). Persistierung via DailyMealPlan/@Model.
public struct DailyMealPlanValue: Equatable, Sendable {
    public let date: Date
    public let assignments: [MealPlanAssignmentValue]
    /// Gesetzt wenn weniger als 2 Rezepte pro Slot verfügbar waren.
    /// Niemals nil wenn ein Slot 0 Rezepte hatte — das ist dann ein Fehler (.noSuitableRecipe).
    public let insufficientSelectionWarning: String?

    public init(date: Date, assignments: [MealPlanAssignmentValue], insufficientSelectionWarning: String? = nil) {
        self.date = date
        self.assignments = assignments
        self.insufficientSelectionWarning = insufficientSelectionWarning
    }
}

/// Fehler bei der Plangenerierung. Nur wenn kein einziges geeignetes Rezept existiert.
public enum MealPlanGenerationError: Error, Equatable {
    case noSuitableRecipe(mealType: MealType)
}
