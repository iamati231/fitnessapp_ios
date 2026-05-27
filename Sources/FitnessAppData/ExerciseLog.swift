#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

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

    /// DEL-155: Snapshot des Cardio-Equipments (rawValue) zum Log-Zeitpunkt.
    /// Wird fuer die PR-/Trend-Trennung pro Equipment genutzt und ueberlebt
    /// einen Exercise-Delete (orphan-Resilienz wie die anderen Snapshots).
    /// `nil` = pre-DEL-155-Bestand ODER Strength-Log → `resolvedCardioEquipment`
    /// faellt auf die Live-Exercise bzw. `.none` zurueck.
    public var exerciseCardioEquipmentSnapshot: String? = nil

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
        // DEL-155: Cardio-Equipment-Snapshot. Nur fuer Cardio-Logs relevant;
        // bei Strength bleibt es nil.
        self.exerciseCardioEquipmentSnapshot = (exercise?.isCardio == true)
            ? exercise?.cardioEquipmentRaw
            : nil
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

    /// DEL-155: Cardio-Equipment, LIVE-first. Anders als die anderen
    /// Snapshots wird hier die lebende Exercise-Referenz bevorzugt — der User
    /// editiert das Equipment nachtraeglich im Verlauf auf der Exercise, und
    /// diese Aenderung soll sich sofort in PR-/Trend-Gruppierung
    /// niederschlagen. Nur wenn die Live-Referenz weg ist (orphan-Log),
    /// faellt es auf den Snapshot zurueck. Default `.none`.
    public var resolvedCardioEquipment: CardioEquipment {
        if let exercise { return exercise.cardioEquipment }
        return exerciseCardioEquipmentSnapshot
            .flatMap(CardioEquipment.init(rawValue:)) ?? .none
    }

    // MARK: - DEL-099 Scoring-Convenience
    //
    // Delegiert an `ExerciseScoring` (Core). Wenn die Live-Exercise-Referenz
    // weg ist (gelöschter Plan, orphan-Log), faellt der Score auf 0 — historische
    // Recovery-Stats brauchen die statischen Faktoren und die persistieren wir
    // nicht auf dem Log selbst (waere doppelter State; falls das Bug-Surface
    // wird, ist Snapshot der naechste Schritt).

    /// CNS-Last dieses einzelnen Logs. Cardio + Time-based: Dauer * Faktor.
    /// Strength: Set-Load-Formel mit Gewicht + RIR.
    public var cnsFatigueScore: Double {
        guard let exercise else { return 0.0 }
        if exercise.isCardio || exercise.isTimeBased {
            return ExerciseScoring.timeBasedScore(
                durationSeconds: durationSeconds ?? (exercise.isTimeBased ? reps : 0),
                factor: exercise.cnsDemandFactor
            )
        }
        return ExerciseScoring.strengthCNSScore(
            weightKg: weight,
            rir: rir,
            cnsDemandFactor: exercise.cnsDemandFactor
        )
    }

    /// Lokale-Muskel-Belastung dieses einzelnen Logs. Reps + RIR fliessen
    /// hier staerker rein als bei CNS.
    public var localMuscleDamageScore: Double {
        guard let exercise else { return 0.0 }
        if exercise.isCardio || exercise.isTimeBased {
            return ExerciseScoring.timeBasedScore(
                durationSeconds: durationSeconds ?? (exercise.isTimeBased ? reps : 0),
                factor: exercise.localMuscleDamageFactor
            )
        }
        return ExerciseScoring.strengthMuscleDamageScore(
            reps: reps,
            rir: rir,
            localMuscleDamageFactor: exercise.localMuscleDamageFactor
        )
    }
}
#endif
