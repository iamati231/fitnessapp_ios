import Foundation

/// Aggregations over a set of `LiftAttempt`s within a workout. Pure functions —
/// no SwiftData, no SwiftUI. Used by `WorkoutSummaryView`'s "Best:" header,
/// future widgets ("Best of session"), and Apple-Watch surfaces.
///
/// All functions accept `[LiftAttempt]` (a Core value type). The view layer
/// projects `ExerciseLog` instances into attempts once per body render.
public enum WorkoutAnalytics {

    /// Returns the attempt with the highest `volume` (weight × reps). Nil for
    /// empty input. Cardio + time-based attempts are NOT filtered out — caller
    /// decides whether to pre-filter (the volume formula degenerates to 0 for
    /// bodyweight-only attempts where `weightKg == 0`, but the API stays honest).
    public static func bestSet(in attempts: [LiftAttempt]) -> LiftAttempt? {
        attempts.max { $0.volume < $1.volume }
    }

    /// Sum of `volume` across all attempts. Used for session-total displays.
    public static func totalVolume(in attempts: [LiftAttempt]) -> Double {
        attempts.reduce(0.0) { $0 + $1.volume }
    }

    /// Number of attempts that count as "weighted lifts" — excludes cardio,
    /// isometric (time-based), and bodyweight-only. Used as the basis for
    /// session-set-count displays where pure cardio shouldn't inflate the number.
    public static func liftSetCount(in attempts: [LiftAttempt]) -> Int {
        attempts.filter { !$0.isCardio && !$0.isTimeBased && $0.weightKg > 0 }.count
    }
}
