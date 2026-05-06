import Foundation

/// A single personal record achieved within a workout session. `PRDetector`
/// emits one of these per (exercise, kind) when the corresponding metric
/// strictly exceeds the lifter's prior best.
public struct PersonalRecord: Sendable, Hashable, Identifiable {

    /// Distinct PR categories. We track three because they can diverge: a higher
    /// weight at fewer reps doesn't always mean a higher 1RM estimate.
    public enum Kind: Sendable, Hashable, CaseIterable {
        /// Heaviest single weight ever lifted, regardless of reps.
        case heaviestWeight
        /// Highest `weight × reps` (single-set volume).
        case bestSet
        /// Highest Epley/Brzycki-average 1RM estimate.
        case estimated1RM
    }

    /// Stable identifier — allows `ForEach(prs) {}` without needing manual id-mapping.
    public let id: UUID
    public let kind: Kind
    public let exerciseName: String
    /// Weight on the bar for the PR-achieving set (kg).
    public let weightKg: Double
    /// Reps on the PR-achieving set.
    public let reps: Int
    /// Previous best for this kind. Comparable to `newValue`. Nil only in
    /// edge cases the detector currently filters out (no history, etc.).
    public let previousValue: Double
    /// Achieved value for this kind. Compare to `previousValue`.
    public let newValue: Double
    public let achievedAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        exerciseName: String,
        weightKg: Double,
        reps: Int,
        previousValue: Double,
        newValue: Double,
        achievedAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.reps = reps
        self.previousValue = previousValue
        self.newValue = newValue
        self.achievedAt = achievedAt
    }

    /// Absolute increase over the previous best.
    public var delta: Double { newValue - previousValue }

    /// Relative increase (0..1+) — useful for "+3%" displays.
    public var deltaPercent: Double {
        guard previousValue > 0 else { return 0 }
        return (newValue - previousValue) / previousValue
    }
}
