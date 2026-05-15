#if canImport(SwiftData)
import Foundation
import SwiftData

/// One executed set of an exercise, logged during a `WorkoutSession`. This is
/// the SACRED HISTORY — it must survive *any* plan-side mutation:
///
///   * Plan-Equipment-Wechsel (DEL-049) → ExerciseLog ueberlebt, weil der
///     Migrator nur archiviert statt zu loeschen.
///   * Manuelles Loeschen einer `Exercise` im DayEditor → ExerciseLog
///     ueberlebt jetzt auch, weil die Backref auf `.nullify` umgestellt ist
///     (DEL-051) UND `exerciseNameSnapshot` plus die Cardio-/TimeBased-
///     Flags als unabhaengige Felder gespeichert sind. Der Log identifiziert
///     sich also auch ohne Live-Exercise-Pointer.
///   * `TrainingDay`/`TrainingPlan` Delete (Cascade) → der Exercise-Pointer
///     wird auch hier nullified, aber Logs bleiben mit ihrem Snapshot voll
///     auswertbar in PR-Detection und Statistik.
///
/// PR-Detection, Trophy-Room, Compound-Trend-Chart usw. lesen IMMER die
/// Snapshot-Felder (`exerciseNameSnapshot`, `exerciseIsCardio`,
/// `exerciseIsTimeBased`) und behandeln die `exercise`-Relationship nur als
/// optionale Convenience-Referenz fuer Plan-Editing.
@Model
public final class ExerciseLog {
    public var date: Date
    public var setIndex: Int
    public var weight: Double
    public var reps: Int
    public var rpe: Double
    public var rir: Float
    public var comment: String?

    /// DEL-051: Snapshot-Identitaet der ausgefuehrten Uebung. Wird beim
    /// `init(...)` aus der uebergebenen `Exercise` gezogen UND kann auf
    /// existierende Logs per Backfill nachgereicht werden. Optional, damit
    /// pre-DEL-051-Bestand ohne Snapshot lightweight migriert werden kann
    /// — PR-Sync fallbacked dann auf `exercise?.name`, solange noch eine
    /// Live-Referenz existiert.
    public var exerciseNameSnapshot: String?
    /// DEL-051: Snapshot der `Exercise.isCardio`-Flagge. Cardio-Lifts werden
    /// vom `PRDetector` aussortiert, dafuer brauchen wir den Wert auch
    /// nach einem Exercise-Delete.
    public var exerciseIsCardioSnapshot: Bool = false
    /// DEL-051: Snapshot der `Exercise.isTimeBased`-Flagge. Time-based Reps
    /// = Sekunden (Plank etc.) — separater PR-Pfad als Strength-Lifts.
    public var exerciseIsTimeBasedSnapshot: Bool = false

    /// DEL-058: Distanz in km fuer Cardio-Lifts (Easy Run, Long Run, ...).
    /// Nil fuer Strength + Time-Based. Wird im Workout direkt vom
    /// CardioSetRow ueberschrieben.
    public var distanceKm: Double?

    /// DEL-058: Gesamtdauer in Sekunden fuer Cardio-Lifts. Nil fuer
    /// Strength + Time-Based (TimeBased-Lifts speichern die Hold-Sekunden
    /// in `reps`, weil die Reps-Spalte semantisch dort die Sekunden ist —
    /// DEL-040). `durationSeconds` ist explizit fuer Cardio-Distanz-Pace-
    /// Logging gedacht.
    public var durationSeconds: Int?

    /// DEL-051: Backref auf die Plan-Uebung. `Exercise.logs` hat jetzt
    /// `.nullify` als Delete-Rule, sodass ein Plan-Side Delete die Historie
    /// NICHT mit-loescht (sie ueberlebt als orphan mit Snapshot).
    public var exercise: Exercise?
    /// Nullify rather than cascade — sessions can be deleted without losing logs.
    public var session: WorkoutSession?

    public init(
        date: Date = Date(),
        setIndex: Int,
        weight: Double,
        reps: Int,
        rpe: Double = 0.0,
        rir: Float,
        comment: String? = nil,
        exercise: Exercise? = nil,
        session: WorkoutSession? = nil,
        distanceKm: Double? = nil,
        durationSeconds: Int? = nil
    ) {
        self.date = date
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.rir = rir
        self.comment = comment
        self.exercise = exercise
        self.session = session
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        // DEL-051: Snapshot-Felder direkt aus der uebergebenen Live-Uebung
        // ziehen. Wenn `exercise == nil` (z.B. ad-hoc-Logs ohne Plan-
        // Verknuepfung) bleiben die Snapshots leer.
        self.exerciseNameSnapshot       = exercise?.name
        self.exerciseIsCardioSnapshot   = exercise?.isCardio ?? false
        self.exerciseIsTimeBasedSnapshot = exercise?.isTimeBased ?? false
    }

    // MARK: - DEL-051 Snapshot Accessors

    /// Liest den Namen der ausgefuehrten Uebung, snapshot-first. Faellt nur
    /// dann auf die Live-Exercise zurueck, wenn der Snapshot leer ist (pre-
    /// DEL-051-Bestand vor Backfill).
    public var resolvedExerciseName: String? {
        if let snap = exerciseNameSnapshot, !snap.isEmpty { return snap }
        return exercise?.name
    }

    /// Cardio-Flag mit Snapshot-first-Auflesung. Pre-DEL-051-Bestand ohne
    /// Snapshot faellt auf die (eventuell noch lebende) Exercise-Referenz
    /// zurueck; nach Exercise-Delete bleibt der Wert vorsichtig `false` =
    /// als Strength-Lift, was im PR-Pfad das richtige Verhalten ist (PR-
    /// Detection laeuft → Log wird ggf. zum PR statt verworfen).
    public var resolvedIsCardio: Bool {
        if exerciseNameSnapshot != nil { return exerciseIsCardioSnapshot }
        return exercise?.isCardio ?? false
    }

    /// Time-based-Flag mit Snapshot-first-Auflesung. Analog zu `resolvedIsCardio`.
    public var resolvedIsTimeBased: Bool {
        if exerciseNameSnapshot != nil { return exerciseIsTimeBasedSnapshot }
        return exercise?.isTimeBased ?? false
    }
}
#endif
