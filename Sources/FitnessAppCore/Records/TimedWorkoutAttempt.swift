import Foundation

/// Pure-data view of one completed AMRAP/EMOM/Auf-Zeit session, decoupled from
/// `WorkoutSession` (SwiftData @Model) — analogous to how `LiftAttempt` projects
/// `ExerciseLog` for the strength/cardio PR path. The view layer builds these
/// from `WorkoutSession.timeFormatSnapshot` + the four result fields before
/// passing them to `PRDetector.detectTimedFormatPR`.
public struct TimedWorkoutAttempt: Sendable, Hashable {
    /// WOD-Identitaet — der `TrainingDay`-Name (z.B. "Cindy"), NICHT ein
    /// Uebungsname. Zwei Attempts gelten als "derselbe WOD", wenn `wodName`
    /// UND `format` uebereinstimmen.
    public let wodName: String
    public let format: WorkoutTimeFormat
    public let date: Date
    /// AMRAP: vollstaendig abgeschlossene Runden.
    public let roundsCompleted: Int?
    /// AMRAP: Wiederholungen in die angebrochene Runde hinein.
    public let partialReps: Int?
    /// Auf Zeit: Gesamtzeit in Sekunden.
    public let finishTimeSeconds: Int?

    public init(
        wodName: String,
        format: WorkoutTimeFormat,
        date: Date,
        roundsCompleted: Int? = nil,
        partialReps: Int? = nil,
        finishTimeSeconds: Int? = nil
    ) {
        self.wodName = wodName
        self.format = format
        self.date = date
        self.roundsCompleted = roundsCompleted
        self.partialReps = partialReps
        self.finishTimeSeconds = finishTimeSeconds
    }
}
