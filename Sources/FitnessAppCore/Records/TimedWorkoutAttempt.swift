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
    /// True nur bei regulaerem Ende (Zeit-Deckel erreicht bzw. bei Auf Zeit
    /// alle Runden abgehakt), false bei einem vorzeitigen manuellen Speichern
    /// (README 2.10/19e). `detectTimedFormatPR` nutzt das bei Auf Zeit, um zu
    /// verhindern dass ein frueh abgebrochener (und dadurch kuerzerer) Lauf
    /// eine echte Bestzeit schlaegt oder selbst als eine gilt. Default `true`
    /// fuer Bestands-Aufrufer (Tests), die vor dieser Unterscheidung nur
    /// durchgezogene Laeufe modelliert haben.
    public let completedTarget: Bool

    public init(
        wodName: String,
        format: WorkoutTimeFormat,
        date: Date,
        roundsCompleted: Int? = nil,
        partialReps: Int? = nil,
        finishTimeSeconds: Int? = nil,
        completedTarget: Bool = true
    ) {
        self.wodName = wodName
        self.format = format
        self.date = date
        self.roundsCompleted = roundsCompleted
        self.partialReps = partialReps
        self.finishTimeSeconds = finishTimeSeconds
        self.completedTarget = completedTarget
    }
}
