import Foundation

/// Pure exercise-science calculations: 1RM estimates and progressive-overload helper.
///
/// 1:1 port of `ExerciseCalculations.kt`. Both formulas use the same valid range
/// (1-36 reps) — outside that range the original sources lose accuracy fast, so
/// nil is returned rather than an unreliable estimate.
public enum ExerciseCalculations {

    /// Epley formula. Valid range: 1-36 reps.
    public static func estimate1RM(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, (1...36).contains(reps) else { return nil }
        if reps == 1 { return weightKg }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }

    /// Brzycki formula — slightly more conservative than Epley for high-rep sets.
    /// Valid range: 1-36 reps (37 would divide by zero).
    public static func estimate1RMBrzycki(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, (1...36).contains(reps) else { return nil }
        return weightKg * 36.0 / (37.0 - Double(reps))
    }

    /// Average of Epley and Brzycki — used as the "best estimate".
    public static func estimate1RMAverage(weightKg: Double, reps: Int) -> Double? {
        guard let e = estimate1RM(weightKg: weightKg, reps: reps),
              let b = estimate1RMBrzycki(weightKg: weightKg, reps: reps)
        else { return nil }
        return (e + b) / 2.0
    }

    /// Suggests the weight that hits `targetReps` at the same %1RM, rounded DOWN to the
    /// nearest `barIncrement` (default 2.5 kg). Used by the progressive-overload helper.
    public static func suggestWeightForReps(
        current1RM: Double,
        targetReps: Int,
        barIncrement: Double = 2.5
    ) -> Double {
        let raw = targetReps <= 1
            ? current1RM
            : current1RM / (1.0 + Double(targetReps) / 30.0)
        return floor(raw / barIncrement) * barIncrement
    }
}
