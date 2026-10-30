import Foundation

/// Deterministischer Tagesplan-Generator ohne SwiftData-Abhängigkeit.
/// Gleiche Inputs → gleiche Outputs (Calendar.ordinality-Seed).
public enum MealPlanGenerator {

    /// Generiert einen Tagesplan.
    /// - Parameters:
    ///   - date: Tag für den geplant wird.
    ///   - mealTypes: Gewünschte Mahlzeit-Slots in Reihenfolge.
    ///   - preferences: Ernährungspräferenzen (Stil, Allergene, Ausschlüsse).
    ///   - dailyCalorieGoalKcal: Kalorienziel — skaliert alle Portionen proportional. Nil = keine Skalierung.
    ///   - recentRecipeIDs: In den letzten Tagen verwendete IDs — werden wenn möglich vermieden.
    ///   - recipeCatalog: Vollständige Rezeptliste (RecipeCatalogData.all).
    ///   - foodCatalog: Lebensmittelkatalog für Nährwertberechnung (FoodCatalogData.all).
    ///                  Nur für Kalorienskalierung; bei leerem Array wird nicht skaliert.
    /// - Returns: Tagesplan oder `.noSuitableRecipe` wenn für einen Slot kein Rezept passt.
    public static func generate(
        for date: Date,
        mealTypes: [MealType],
        preferences: UserNutritionPreferences,
        dailyCalorieGoalKcal: Int?,
        recentRecipeIDs: Set<String>,
        recipeCatalog: [Recipe],
        foodCatalog: [FoodCatalogItem] = []
    ) -> Result<DailyMealPlanValue, MealPlanGenerationError> {

        var assignments: [MealPlanAssignmentValue] = []
        var warning: String?
        let dayOrd = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1

        for (slotIndex, mealType) in mealTypes.enumerated() {
            let suitable = eligibleRecipes(in: recipeCatalog, for: mealType, preferences: preferences)

            guard !suitable.isEmpty else {
                return .failure(.noSuitableRecipe(mealType: mealType))
            }

            if suitable.count < 2 {
                let w = "Zu wenig Rezepte für \(mealType.rawValue): nur \(suitable.count) geeignet."
                warning = warning.map { $0 + " | " + w } ?? w
            }

            // Bevorzuge Rezepte außerhalb des Wiederholungsfensters
            let fresh = suitable.filter { !recentRecipeIDs.contains($0.id) }
            let pool = fresh.isEmpty ? suitable : fresh

            // Deterministischer Index: Tag-im-Jahr × 37 + Slot-Position
            let seed = (dayOrd &* 37) &+ slotIndex
            let recipe = pool[abs(seed) % pool.count]

            assignments.append(MealPlanAssignmentValue(
                recipeID: recipe.id,
                mealType: mealType,
                portionMultiplier: 1.0
            ))
        }

        if let goal = dailyCalorieGoalKcal, !foodCatalog.isEmpty {
            assignments = scaleToCalorieGoal(
                assignments, goalKcal: goal, recipes: recipeCatalog, foodCatalog: foodCatalog
            )
        }

        return .success(DailyMealPlanValue(
            date: date,
            assignments: assignments,
            insufficientSelectionWarning: warning
        ))
    }

    // MARK: - Internal (internal for testability)

    /// Liefert alle Rezepte, die für `mealType` und `preferences` geeignet sind.
    /// Unbekannte Allergeninformationen (allergenVerified=false) werden bei aktivem
    /// Allergenfilter sicher ausgeschlossen.
    static func eligibleRecipes(
        in catalog: [Recipe],
        for mealType: MealType,
        preferences: UserNutritionPreferences
    ) -> [Recipe] {
        catalog.filter { recipe in
            guard recipe.mealTypes.contains(mealType) else { return false }
            guard !preferences.excludedRecipeIDs.contains(recipe.id) else { return false }
            guard matchesDietaryStyle(recipe, style: preferences.dietaryStyle) else { return false }

            if preferences.hasAllergenFilter {
                // allergenVerified=false → unbekannter Status → immer ausschließen
                guard recipe.allergenVerified else { return false }
                for allergen in preferences.allergenExclusions {
                    if recipe.allergens.contains(allergen) { return false }
                }
            }
            return true
        }
    }

    static func matchesDietaryStyle(_ recipe: Recipe, style: DietaryStyle) -> Bool {
        switch style {
        case .omnivor:    return true
        case .vegetarian: return recipe.dietaryTags.contains(.vegetarian)
        case .vegan:      return recipe.dietaryTags.contains(.vegan)
        case .pescetarian: return recipe.dietaryTags.contains(.pescetarian)
        }
    }

    /// Skaliert alle Portionen proportional, damit das Gesamtkalorienziel getroffen wird.
    /// Klammerung auf [0.5, 2.5] verhindert unrealistische Portionen.
    static func scaleToCalorieGoal(
        _ assignments: [MealPlanAssignmentValue],
        goalKcal: Int,
        recipes: [Recipe],
        foodCatalog: [FoodCatalogItem]
    ) -> [MealPlanAssignmentValue] {
        guard goalKcal > 0 else { return assignments }

        var baseTotal = 0.0
        for a in assignments {
            guard let recipe = recipes.first(where: { $0.id == a.recipeID }) else { continue }
            if case .success(let n) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: foodCatalog),
               let kcal = n.kcal.value {
                baseTotal += kcal
            }
        }

        guard baseTotal > 0 else { return assignments }

        let scale = min(max(Double(goalKcal) / baseTotal, 0.5), 2.5)

        return assignments.map {
            MealPlanAssignmentValue(recipeID: $0.recipeID, mealType: $0.mealType, portionMultiplier: scale)
        }
    }
}
