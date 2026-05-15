import Foundation

/// A single personal record achieved within a workout session. `PRDetector`
/// emits one of these per (exercise, kind) when the corresponding metric
/// strictly exceeds the lifter's prior best.
public struct PersonalRecord: Sendable, Hashable, Identifiable {

    /// Distinct PR categories. Seven kinds across four exercise-types:
    ///   - **Weighted lifts** (any attempt has weight > 0): heaviestWeight, bestSet, estimated1RM.
    ///   - **Bodyweight** (all attempts weight == 0, not time-based): maxReps.
    ///   - **Time-based / isometric** (Plank, Wall Sit, Mountain Climbers): maxHoldSeconds.
    ///   - **Cardio (DEL-064)** (Easy Run, Long Run, Intervalle): longestDistance, fastestPace.
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
        /// Highest reps achieved in a bodyweight-only exercise (Klimmzüge, Liegestütze, Dips).
        case maxReps
        /// Longest hold for an isometric / time-based exercise (Plank, Wall Sit, Seitstütz).
        case maxHoldSeconds
        /// DEL-064: Weiteste Distanz, die je in dieser Cardio-Uebung gelaufen
        /// wurde (km). Aggregat ueber alle Saetze einer Session.
        case longestDistance
        /// DEL-064: Beste Average-Pace einer Cardio-Session (min/km, niedriger
        /// = besser). Nur valide ueber Sessions mit `totalKm >=` Mindestdistanz —
        /// PRDetector guarded gegen Sprint-Outlier.
        case fastestPace
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
