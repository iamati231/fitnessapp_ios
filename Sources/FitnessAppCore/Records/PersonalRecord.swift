import Foundation

/// A single personal record achieved within a workout session. `PRDetector`
/// emits one of these per (exercise, kind) when the corresponding metric
/// strictly exceeds the lifter's prior best.
public struct PersonalRecord: Sendable, Hashable, Identifiable {

    /// Distinct PR categories. Five kinds spread across three exercise-types:
    ///   - **Weighted lifts** (any attempt has weight > 0): heaviestWeight, bestSet, estimated1RM.
    ///   - **Bodyweight** (all attempts weight == 0, not time-based): maxReps.
    ///   - **Time-based / isometric** (Plank, Wall Sit, Mountain Climbers): maxHoldSeconds.
    /// Cardio (treadmill, bike) is intentionally excluded — different metric domain
    /// (pace / distance / heart-rate) belongs in a separate detector.
    /// String-rawvalue so persistence layers (`PersonalRecordEntry` @Model) can
     /// round-trip the kind without a custom codable shim. Stable identifiers —
     /// renaming a case here is a database-migration event.
    public enum Kind: String, Sendable, Hashable, CaseIterable, Codable {
        /// Heaviest single weight ever lifted, regardless of reps.
        case heaviestWeight
        /// Highest `weight × reps` (single-set volume).
        case bestSet
        /// Highest Epley/Brzycki-average 1RM estimate.
        case estimated1RM
        /// Highest reps achieved in a bodyweight-only exercise (Klimmzuege, Liegestuetze, Dips).
        case maxReps
        /// Longest hold for an isometric / time-based exercise (Plank, Wall Sit, Seitstuetz).
        case maxHoldSeconds
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
