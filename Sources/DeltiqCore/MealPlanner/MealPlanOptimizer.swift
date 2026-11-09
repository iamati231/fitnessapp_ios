import Foundation

/// Nicht-persistentes Ergebnis einer Tagesplan-Optimierung.
public struct OptimizedPlanProposal: Sendable, Identifiable {
    public let id: UUID = UUID()

    /// Änderung für einen einzelnen Mahlzeit-Slot.
    public struct SlotChange: Sendable, Identifiable {
        public let id = UUID()
        public let mealType: MealType
        /// Aktuelles Rezept (vor Optimierung).
        public let currentRecipeID: String
        /// Vorgeschlagenes Rezept (identisch wenn kein Wechsel).
        public let proposedRecipeID: String
        public let currentMultiplier: Double
        public let proposedMultiplier: Double
        /// Nährwerte des aktuellen Rezepts bei aktuellem Portionsfaktor. Nil wenn berechenbar.
        public let currentNutrients: NutrientValues?
        /// Nährwerte des vorgeschlagenen Rezepts bei vorgeschlagenem Portionsfaktor.
        public let proposedNutrients: NutrientValues?

        public var recipeChanged: Bool { currentRecipeID != proposedRecipeID }
        public var multiplierChanged: Bool { currentMultiplier != proposedMultiplier }
        public var hasChange: Bool { recipeChanged || multiplierChanged }
    }

    public let changes: [SlotChange]
    /// Aktuelle Tagessumme (aus berechnbaren Slots).
    public let currentTotals: NutrientValues
    /// Vorgeschlagene Tagessumme nach Optimierung.
    public let proposedTotals: NutrientValues
    /// Nil wenn keine Warnung. Nutzerorientierter Text, Deutsch.
    public let warning: String?

    public var hasChanges: Bool { changes.contains { $0.hasChange } }
}

public enum OptimizationError: Error, Equatable {
    /// Kein Ernährungsziel gesetzt — Optimierung nicht möglich.
    case noGoalSet
    /// Keine Zuweisungen im Plan.
    case noAssignments
}

/// Deterministischer Tagesplan-Optimierer. Pure-function ohne SwiftData-Abhängigkeit.
///
/// Passt Portionsfaktoren uniform an, um Kalorien- und Makroziele zu erreichen.
/// Schlägt Rezeptalternativen vor, wenn ein Slot keine berechenbaren Nährwerte hat.
///
/// OFF-01: Unbekannte Nährwerte bleiben unbekannt. Sie fließen nicht als 0 in
/// die Skalierungsberechnung ein. Fehlende Dimensionen erzeugen eine Warnung.
/// Portionsfaktoren: Schrittweite 0.5, Bereich [0.5, 5.0].
public enum MealPlanOptimizer {

    public static func optimize(
        assignments: [(recipeID: String, mealType: MealType, portionMultiplier: Double)],
        calorieGoal: Int?,
        proteinGoal: Double?,
        carbGoal: Double?,
        fatGoal: Double?,
        recipeCatalog: [Recipe],
        foodCatalog: [FoodCatalogItem],
        preferences: UserNutritionPreferences
    ) -> Result<OptimizedPlanProposal, OptimizationError> {

        guard calorieGoal != nil || proteinGoal != nil || carbGoal != nil || fatGoal != nil else {
            return .failure(.noGoalSet)
        }
        guard !assignments.isEmpty else {
            return .failure(.noAssignments)
        }

        let recipeByID = Dictionary(uniqueKeysWithValues: recipeCatalog.map { ($0.id, $0) })
        let assignedIDs = Set(assignments.map(\.recipeID))

        // Schritt 1: Jeden Slot auflösen — Nährwerte berechnen, ggf. Rezeptalternative finden.
        struct ResolvedSlot {
            let originalRecipeID: String
            let resolvedRecipeID: String  // swap candidate or identical
            let mealType: MealType
            let originalMultiplier: Double
            let currentNutrients: NutrientValues?  // nil wenn original unberechenbar
        }

        var resolvedSlots: [ResolvedSlot] = []
        for a in assignments {
            let currentNutrients: NutrientValues?
            if let recipe = recipeByID[a.recipeID],
               case .success(let n) = RecipeNutritionCalculator.nutrients(
                   for: recipe, catalog: foodCatalog, portionMultiplier: a.portionMultiplier) {
                currentNutrients = n
            } else {
                currentNutrients = nil
            }

            if currentNutrients != nil {
                resolvedSlots.append(ResolvedSlot(
                    originalRecipeID: a.recipeID, resolvedRecipeID: a.recipeID,
                    mealType: a.mealType, originalMultiplier: a.portionMultiplier,
                    currentNutrients: currentNutrients
                ))
            } else {
                // Rezeptalternative suchen: gleiches mealType, Präferenzen, Dedup.
                let eligible = MealPlanGenerator.eligibleRecipes(
                    in: recipeCatalog, for: a.mealType, preferences: preferences)
                    .filter { $0.id != a.recipeID }
                let fresh = eligible.filter { !assignedIDs.contains($0.id) }
                let pool = fresh.isEmpty ? eligible : fresh
                var swapID = a.recipeID
                for candidate in pool {
                    if case .success = RecipeNutritionCalculator.nutrients(
                        for: candidate, catalog: foodCatalog, portionMultiplier: 1.0) {
                        swapID = candidate.id
                        break
                    }
                }
                resolvedSlots.append(ResolvedSlot(
                    originalRecipeID: a.recipeID, resolvedRecipeID: swapID,
                    mealType: a.mealType, originalMultiplier: a.portionMultiplier,
                    currentNutrients: nil
                ))
            }
        }

        // Schritt 2: Aktuelle Tagessumme aus berechenbaren Slots.
        let knownNutrients = resolvedSlots.compactMap { $0.currentNutrients }
        let currentTotals = NutrientValues.sum(knownNutrients)
        let hasUnresolvableSlots = resolvedSlots.contains { $0.currentNutrients == nil }

        // Schritt 3: Gewichteten Skalierungsfaktor berechnen.
        // Unbekannte Dimensionen fließen nicht als 0 ein (OFF-01).
        var multipliers: [(value: Double, weight: Double)] = []
        var hasUnknownDimensions = false

        if let goal = calorieGoal {
            if let v = currentTotals.kcal.value, v > 0 { multipliers.append((Double(goal) / v, 1.0)) }
            else { hasUnknownDimensions = true }
        }
        if let goal = proteinGoal {
            if let v = currentTotals.proteinG.value, v > 0 { multipliers.append((goal / v, 1.0)) }
            else { hasUnknownDimensions = true }
        }
        if let goal = carbGoal {
            if let v = currentTotals.carbsG.value, v > 0 { multipliers.append((goal / v, 0.5)) }
            else { hasUnknownDimensions = true }
        }
        if let goal = fatGoal {
            if let v = currentTotals.fatG.value, v > 0 { multipliers.append((goal / v, 0.5)) }
            else { hasUnknownDimensions = true }
        }

        var warning: String?
        if hasUnresolvableSlots || hasUnknownDimensions {
            warning = "Einige Nährwerte sind unbekannt. Optimierung nur teilweise möglich."
        }

        // Kein nutzbarer Multiplikator → Nährwerte vollständig unbekannt.
        guard !multipliers.isEmpty else {
            let unchangedChanges = resolvedSlots.map { slot in
                OptimizedPlanProposal.SlotChange(
                    mealType: slot.mealType,
                    currentRecipeID: slot.originalRecipeID,
                    proposedRecipeID: slot.resolvedRecipeID,
                    currentMultiplier: slot.originalMultiplier,
                    proposedMultiplier: slot.originalMultiplier,
                    currentNutrients: slot.currentNutrients,
                    proposedNutrients: slot.currentNutrients
                )
            }
            return .success(OptimizedPlanProposal(
                changes: unchangedChanges,
                currentTotals: currentTotals,
                proposedTotals: currentTotals,
                warning: "Nährwertangaben unvollständig: Portionsskalierung nicht möglich."
            ))
        }

        let totalWeight = multipliers.reduce(0.0) { $0 + $1.weight }
        let rawScaleFactor = multipliers.reduce(0.0) { $0 + $1.value * $1.weight } / totalWeight

        if multipliers.count >= 2 {
            let values = multipliers.map(\.value)
            if let minM = values.min(), let maxM = values.max(), maxM - minM > 0.4 {
                let conflict = String(format: "Zielkonflikt: Portionsgrößen-Spannung ×%.1f–×%.1f.", minM, maxM)
                warning = warning.map { $0 + " | " + conflict } ?? conflict
            }
        }

        // Schritt 4: Pro Slot — neuen Portionsfaktor (0.5-Schritte, [0.5, 5.0]) und Nährwerte.
        var changes: [OptimizedPlanProposal.SlotChange] = []
        var proposedComponents: [NutrientValues] = []

        for slot in resolvedSlots {
            let rawProposed = slot.originalMultiplier * rawScaleFactor
            let proposed = min(max((rawProposed / 0.5).rounded() * 0.5, 0.5), 5.0)

            var proposedNutrients: NutrientValues? = nil
            if let recipe = recipeByID[slot.resolvedRecipeID],
               case .success(let n) = RecipeNutritionCalculator.nutrients(
                   for: recipe, catalog: foodCatalog, portionMultiplier: proposed) {
                proposedNutrients = n
                proposedComponents.append(n)
            }

            changes.append(OptimizedPlanProposal.SlotChange(
                mealType: slot.mealType,
                currentRecipeID: slot.originalRecipeID,
                proposedRecipeID: slot.resolvedRecipeID,
                currentMultiplier: slot.originalMultiplier,
                proposedMultiplier: proposed,
                currentNutrients: slot.currentNutrients,
                proposedNutrients: proposedNutrients
            ))
        }

        let proposedTotals = NutrientValues.sum(proposedComponents)

        return .success(OptimizedPlanProposal(
            changes: changes,
            currentTotals: currentTotals,
            proposedTotals: proposedTotals,
            warning: warning
        ))
    }
}
