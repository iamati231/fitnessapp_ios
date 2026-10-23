import Foundation

/// Nutrition / hydration heuristics. Pure functions — no SwiftData, no UI.
public enum NutritionCalculations {

    /// Daily water-intake target in millilitres. Default formula `weightKg × 35`
    /// — the standard sports-medicine reference for a moderately active adult.
    /// Pass a different multiplier for athletes (40-45 ml/kg) or low-activity
    /// reference (~30 ml/kg).
    ///
    /// Returns 0 for non-positive weights (defensive — caller may pass an
    /// uninitialized profile weight).
    public static func dailyWaterTargetMl(
        weightKg: Double,
        multiplier: Double = 35.0
    ) -> Int {
        guard weightKg > 0 else { return 0 }
        return Int((weightKg * multiplier).rounded())
    }

    /// Naehrwerte fuer eine gegebene Menge eines `FoodCatalogItem` (Spec 4.2).
    ///
    /// Alle Einheiten rechnen zuerst auf Gramm um, dann greift dieselbe
    /// Gramm-Formel (`...Per100g * grams / 100`):
    /// - `.gram`: `quantity` ist bereits Gramm.
    /// - `.piece`: `quantity * item.pieceWeightGrams`; `nil` ohne gesetztes
    ///   `pieceWeightGrams`.
    /// - `.milliliter`: `quantity * item.densityGramsPerMl`; `nil` ohne
    ///   gesetzte Dichte — NIEMALS 1 ml = 1 g annehmen.
    ///
    /// Gibt exakte, ungerundete Werte zurueck (kein Runden/Truncate hier —
    /// das passiert erst bei der Anzeige, analog `TDEEView.tdee`).
    ///
    /// OFF-01: Ein unbekannter Wert im Item (nur bei online importierten
    /// Eintraegen mit unvollstaendigen Open-Food-Facts-Daten moeglich) bleibt
    /// in jeder resultierenden Dimension unbekannt — nie 0.
    public static func nutrients(
        for item: FoodCatalogItem,
        quantity: Double,
        unit: FoodUnit
    ) -> NutrientValues? {
        guard quantity > 0 else { return nil }

        let grams: Double
        switch unit {
        case .gram:
            grams = quantity
        case .piece:
            guard let pieceWeightGrams = item.pieceWeightGrams else { return nil }
            grams = quantity * pieceWeightGrams
        case .milliliter:
            guard let densityGramsPerMl = item.densityGramsPerMl else { return nil }
            grams = quantity * densityGramsPerMl
        }

        let factor = grams / 100
        return NutrientValues(
            kcal: NutrientValues.scaled(item.kcalPer100g, by: factor),
            proteinG: NutrientValues.scaled(item.proteinPer100g, by: factor),
            carbsG: NutrientValues.scaled(item.carbsPer100g, by: factor),
            fatG: NutrientValues.scaled(item.fatPer100g, by: factor)
        )
    }
}

/// Deterministic percent-of-goal + remaining-amount for ONE nutrient goal.
/// Single source of truth shared by the progress-bar UI
/// (`NutritionDayView.GoalRow.fraction`) and the on-device AI insight prompt
/// (`NutritionInsightInput` in `FitnessAppAI`, which — on purpose — has no
/// dependency on this module, see its doc comment — so `NutritionDayView`,
/// which depends on both, computes this once here and hands the plain
/// percent/remaining numbers into the AI input).
public struct GoalProgress: Sendable, Equatable {
    public let current: Double
    public let goal: Double

    public init(current: Double, goal: Double) {
        self.current = current
        self.goal = goal
    }

    /// 0...1, capped at 1.0 — for progress bars.
    public var fraction: Double { goal > 0 ? min(current / goal, 1.0) : 0 }

    /// Rounded whole-number percent, NOT capped at 100 — an exceeded goal is
    /// stated plainly (e.g. "106%"), matching `Double.formattedPercentRounded`'s
    /// rounding convention elsewhere in the app.
    public var percent: Int { goal > 0 ? Int((current / goal * 100).rounded()) : 0 }

    /// How much is left to reach the goal; floored at 0 once met or exceeded.
    public var remaining: Double { max(goal - current, 0) }
}

public extension NutritionCalculations {
    /// `nil` when `goal <= 0` (not set / invalid) — mirrors `GoalRow.fraction`'s
    /// previous `goal > 0 ? ... : 0` guard, now centralized here.
    static func goalProgress(current: Double, goal: Double) -> GoalProgress? {
        guard goal > 0 else { return nil }
        return GoalProgress(current: current, goal: goal)
    }
}

public extension FoodCatalogItem {
    /// Ob diese Menge-Einheit fuer dieses Item sinnvoll ist (Spec 4.2) —
    /// benutzt von Task 6, um im Mengen-Picker ausschliesslich zulaessige
    /// Einheiten anzuzeigen.
    func supports(_ unit: FoodUnit) -> Bool {
        switch unit {
        case .gram: return true
        case .piece: return pieceWeightGrams != nil
        case .milliliter: return densityGramsPerMl != nil
        }
    }
}
