import Foundation

/// Deterministischer Tagesplan-Generator ohne SwiftData-Abhängigkeit.
/// Gleiche Inputs → gleiche Outputs (Calendar.ordinality-Seed).
public enum MealPlanGenerator {

    /// Generiert einen Tagesplan.
    /// - Parameters:
    ///   - date: Tag für den geplant wird.
    ///   - mealTypes: Gewünschte Mahlzeit-Slots in Reihenfolge.
    ///   - preferences: Ernährungspräferenzen (Stil, Allergene, Ausschlüsse).
    ///   - dailyCalorieGoalKcal: Kalorienziel. Nil = kein Kalorienziel.
    ///   - dailyProteinGoalG: Proteinziel in Gramm. Nil = kein Proteinziel.
    ///   - dailyCarbGoalG: Kohlenhydratziel in Gramm. Nil = kein KH-Ziel.
    ///   - dailyFatGoalG: Fettziel in Gramm. Nil = kein Fettziel.
    ///   - recentRecipeIDs: In den letzten Tagen verwendete IDs — werden wenn möglich vermieden.
    ///   - recipeCatalog: Vollständige Rezeptliste (RecipeCatalogData.all).
    ///   - foodCatalog: Lebensmittelkatalog für Nährwertberechnung (FoodCatalogData.all).
    ///                  Erforderlich wenn ein Ernährungsziel gesetzt ist; leeres Array erzeugt Warnung.
    /// - Returns: Tagesplan oder `.noSuitableRecipe` wenn für einen Slot kein Rezept passt.
    public static func generate(
        for date: Date,
        mealTypes: [MealType],
        preferences: UserNutritionPreferences,
        dailyCalorieGoalKcal: Int?,
        dailyProteinGoalG: Double? = nil,
        dailyCarbGoalG: Double? = nil,
        dailyFatGoalG: Double? = nil,
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

        let hasAnyGoal = dailyCalorieGoalKcal != nil || dailyProteinGoalG != nil
            || dailyCarbGoalG != nil || dailyFatGoalG != nil
        if hasAnyGoal {
            let (scaled, scaleWarning) = scaleToNutritionGoals(
                assignments,
                calorieGoalKcal: dailyCalorieGoalKcal,
                proteinGoalG: dailyProteinGoalG,
                carbGoalG: dailyCarbGoalG,
                fatGoalG: dailyFatGoalG,
                recipes: recipeCatalog,
                foodCatalog: foodCatalog
            )
            assignments = scaled
            if let w = scaleWarning {
                warning = warning.map { $0 + " | " + w } ?? w
            }
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

    /// Ernährungsweise-Hierarchie: vegan ⊂ vegetarisch ⊂ pescetarisch ⊂ omnivor.
    /// Ein rein veganes Rezept gilt als vegetarisch und pescetarisch;
    /// ein vegetarisches gilt als pescetarisch — auch ohne redundante Tags.
    static func matchesDietaryStyle(_ recipe: Recipe, style: DietaryStyle) -> Bool {
        switch style {
        case .omnivor:
            return true
        case .vegan:
            return recipe.dietaryTags.contains(.vegan)
        case .vegetarian:
            // Vegane Rezepte sind implizit vegetarisch.
            return recipe.dietaryTags.contains(.vegetarian) || recipe.dietaryTags.contains(.vegan)
        case .pescetarian:
            // Vegane und vegetarische Rezepte sind für Pescetarier geeignet.
            return recipe.dietaryTags.contains(.pescetarian)
                || recipe.dietaryTags.contains(.vegetarian)
                || recipe.dietaryTags.contains(.vegan)
        }
    }

    /// Skaliert alle Portionen auf Basis der kombinierten Ernährungsziele.
    ///
    /// Algorithmus: Für jede Dimension mit bekanntem Basiswert und gesetztem Ziel
    /// wird ein implizierter Multiplikator berechnet. Der gewichtete Durchschnitt
    /// (kcal=1, Protein=1, KH=0.5, Fett=0.5) ergibt den finalen Skalierungsfaktor,
    /// geklemmt auf [0.5, 2.5].
    ///
    /// Unbekannte Nährwerte: eine Dimension mit unbekanntem Basiswert wird NICHT
    /// als 0 gewertet — sie fließt nicht in den Multiplikator ein, und eine Warnung
    /// wird ausgegeben. Unbekannte Nährwerte dürfen nie die Skalierung verzerren.
    ///
    /// Zielkonflikt: wenn die Einzelmultiplikatoren um mehr als 0.4 auseinanderliegen,
    /// wird eine Konfliktwarnung ausgegeben (z. B. Kalorieziel will ×0.8,
    /// Proteinziel will ×1.5).
    static func scaleToNutritionGoals(
        _ assignments: [MealPlanAssignmentValue],
        calorieGoalKcal: Int?,
        proteinGoalG: Double?,
        carbGoalG: Double?,
        fatGoalG: Double?,
        recipes: [Recipe],
        foodCatalog: [FoodCatalogItem]
    ) -> (assignments: [MealPlanAssignmentValue], warning: String?) {

        guard !foodCatalog.isEmpty else {
            return (assignments, "Lebensmittelkatalog fehlt: Portionsskalierung nicht möglich.")
        }

        var baseKcal = 0.0, baseProtein = 0.0, baseCarbs = 0.0, baseFat = 0.0
        var unknownKcal = false, unknownProtein = false, unknownCarbs = false, unknownFat = false
        // Eine fehlgeschlagene Nährwertberechnung (z. B. unbekannte Zutat) darf
        // den Basiswert nicht still auf 0 schrumpfen lassen — Skalierung wäre falsch.
        var anyCalculationFailed = false

        for a in assignments {
            guard let recipe = recipes.first(where: { $0.id == a.recipeID }) else { continue }
            guard case .success(let n) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: foodCatalog)
            else { anyCalculationFailed = true; continue }

            if let v = n.kcal.value { baseKcal += v } else { unknownKcal = true }
            if let v = n.proteinG.value { baseProtein += v } else { unknownProtein = true }
            if let v = n.carbsG.value { baseCarbs += v } else { unknownCarbs = true }
            if let v = n.fatG.value { baseFat += v } else { unknownFat = true }
        }

        // Gewichteter Durchschnitt der impliziten Multiplikatoren pro Zieldimension.
        // Unbekannte Basiswerte und gescheiterte Berechnungen werden ausgeschlossen.
        var multipliers: [(value: Double, weight: Double)] = []

        if let goal = calorieGoalKcal, !unknownKcal, !anyCalculationFailed, baseKcal > 0 {
            multipliers.append((Double(goal) / baseKcal, 1.0))
        }
        if let goal = proteinGoalG, !unknownProtein, !anyCalculationFailed, baseProtein > 0 {
            multipliers.append((goal / baseProtein, 1.0))
        }
        if let goal = carbGoalG, !unknownCarbs, !anyCalculationFailed, baseCarbs > 0 {
            multipliers.append((goal / baseCarbs, 0.5))
        }
        if let goal = fatGoalG, !unknownFat, !anyCalculationFailed, baseFat > 0 {
            multipliers.append((goal / baseFat, 0.5))
        }

        guard !multipliers.isEmpty else {
            return (assignments, "Portionsskalierung nicht möglich: Nährwertangaben unvollständig.")
        }

        let totalWeight = multipliers.reduce(0.0) { $0 + $1.weight }
        let rawScale = multipliers.reduce(0.0) { $0 + $1.value * $1.weight } / totalWeight
        let scale = min(max(rawScale, 0.5), 2.5)

        var warning: String?
        if unknownKcal || unknownProtein || unknownCarbs || unknownFat {
            warning = "Nährwertangaben unvollständig: Skalierung approximiert."
        }

        if multipliers.count >= 2 {
            let values = multipliers.map(\.value)
            let minM = values.min()!
            let maxM = values.max()!
            if maxM - minM > 0.4 {
                let conflict = String(
                    format: "Zielkonflikt: Kalorien- und Makroziele erfordern unterschiedliche Portionsgrößen (×%.1f–×%.1f).",
                    minM, maxM
                )
                warning = warning.map { $0 + " | " + conflict } ?? conflict
            }
        }

        let scaled = assignments.map {
            MealPlanAssignmentValue(recipeID: $0.recipeID, mealType: $0.mealType, portionMultiplier: scale)
        }
        return (scaled, warning)
    }
}
