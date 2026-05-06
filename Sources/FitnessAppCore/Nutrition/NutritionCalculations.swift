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
}
