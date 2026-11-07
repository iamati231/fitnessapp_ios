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

    // DEL-242: `liftSetCount` entfernt — nur ein Test rief es auf, kein
    // Produktivcode.
    //
    // Bewusst NICHT verdrahtet, obwohl es verlockend aussah: die verbindliche
    // Zaehlregel ist `SessionAggregator.totals`, und die zaehlt laut ihrer
    // Doku Bodyweight- UND Cardio-Saetze MIT. `liftSetCount` filterte genau
    // die heraus. Verdrahtet haette die App zwei widerspruechliche
    // Satz-Begriffe — auf demselben Screen, weil daneben `session.totalSets`
    // steht (WorkoutHistoryView, DashboardView). Ein Satz muss ueberall
    // dasselbe bedeuten.
}
