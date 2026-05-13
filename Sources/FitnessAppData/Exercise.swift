#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

@Model
public final class Exercise {
    public var name: String
    public var sets: Int
    public var repsMin: Int
    public var repsMax: Int
    public var restSeconds: Int
    public var notes: String?
    public var suggestedWeight: Double?
    public var orderIndex: Int
    public var targetRir: Float
    public var weightReducedNote: String?
    /// True for cardio finishers — UI shows duration/level instead of kg/reps (F153).
    public var isCardio: Bool
    /// True for isometric/time-based exercises (Plank, Wall Sit) — reps record seconds (F161).
    public var isTimeBased: Bool

    /// DEL-049: Urlaubs-Modus / Equipment-Wechsel Snapshot.
    /// True wenn diese Uebung NICHT mehr im aktiven Plan-Slot steht, sondern
    /// als Fallback aufgehoben wird, weil sie durch eine Alternative ersetzt
    /// wurde (z.B. Bankdruecken im Gym-Plan → Liegestuetze im BW-Modus).
    /// Views nutzen `TrainingDay.activeExercises` statt `day.exercises`, um
    /// archivierte Eintraege aus der UI auszublenden. Die ExerciseLog-
    /// Relationship bleibt erhalten — wir verlieren also KEINE Historie.
    public var isArchived: Bool = false

    /// DEL-049: Wenn diese Uebung als Ersatz fuer eine andere eingefuegt wurde
    /// (Top-Down-Migration), zeigt das Property auf das Original. Beim
    /// Rueckweg ("Urlaub zu Ende") liest der Migrator dieses Feld, hebt das
    /// Original wieder aktiv und entsorgt die Ersatz-Uebung — inklusive
    /// Restore des letzten bekannten Arbeitsgewichts via Original-Logs.
    public var swappedFromOriginal: Exercise?

    public var day: TrainingDay?

    /// DEL-051: HEILIGE HISTORIE. Frueher `.cascade` — beim Loeschen einer
    /// Plan-Uebung (manuell oder via Day/Plan-Cascade) gingen die ExerciseLog-
    /// Eintraege gleich mit weg, was Bestleistungen vernichtet hat. Jetzt
    /// `.nullify`: die Logs verlieren nur ihren `exercise`-Backref-Pointer,
    /// behalten aber ihren Snapshot in `exerciseNameSnapshot` /
    /// `exerciseIsCardioSnapshot` / `exerciseIsTimeBasedSnapshot` und bleiben
    /// fuer PR-Detection, Trophy-Room, Compound-Trends und alle anderen
    /// Statistik-Surfaces voll auswertbar.
    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.exercise)
    public var logs: [ExerciseLog] = []

    public init(
        name: String,
        sets: Int = 3,
        repsMin: Int = 8,
        repsMax: Int = 12,
        restSeconds: Int = 90,
        notes: String? = nil,
        suggestedWeight: Double? = nil,
        orderIndex: Int = 0,
        targetRir: Float = 2.0,
        weightReducedNote: String? = nil,
        isCardio: Bool = false,
        isTimeBased: Bool = false,
        isArchived: Bool = false,
        swappedFromOriginal: Exercise? = nil,
        day: TrainingDay? = nil
    ) {
        self.name = name
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.restSeconds = restSeconds
        self.notes = notes
        self.suggestedWeight = suggestedWeight
        self.orderIndex = orderIndex
        self.targetRir = targetRir
        self.weightReducedNote = weightReducedNote
        self.isCardio = isCardio
        self.isTimeBased = isTimeBased
        self.isArchived = isArchived
        self.swappedFromOriginal = swappedFromOriginal
        self.day = day
    }
}
#endif
