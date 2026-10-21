#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Persisted personal-record event — written from `ActiveWorkoutView.finishWorkout()`
/// whenever `PRDetector` reports a new record. The Trophy Room (`PRHistoryView`)
/// queries this table directly so it never has to re-walk the entire log history.
///
/// **Why a dedicated table** — running `PRDetector` over all logs at every render
/// would scale poorly past a year of data. Storing each PR as it happens turns the
/// trophy-room into a simple `@Query(sort: \.date)` lookup.
///
/// **kind** is stored as the raw String of `PersonalRecord.Kind` (e.g.
/// `"estimated1RM"`). Renaming a case in `Kind` is a migration event — the
/// String values must stay stable.
///
/// **value semantics** are kind-dependent:
///   - `heaviestWeight`, `estimated1RM` → kg
///   - `bestSet` → kg-volume (weight × reps)
///   - `maxReps` → reps (Double for uniform plotting)
///   - `maxHoldSeconds` → seconds
@Model
public final class PersonalRecordEntry {

    public var date: Date
    public var exerciseName: String
    /// Settings-Epic Phase 6 (EXLIB-07/09): stabile Rueckreferenz auf die
    /// `ExerciseTemplate`, aus der dieser PR entstand (ueber `LiftAttempt` /
    /// `PersonalRecord.exerciseTemplateID` propagiert). `nil` fuer
    /// WOD-Zeitformat-PRs (`exerciseName` traegt dort den WOD-Namen, keine
    /// Uebungs-Vorlage) sowie fuer Alt-Eintraege ohne Backfill-Treffer — der
    /// Trophy-Room faellt dann auf `exerciseName` zurueck, exakt das
    /// Verhalten vor dieser Phase.
    public var exerciseTemplateID: UUID?

    /// `PersonalRecord.Kind.rawValue`. Exposed via the typed `kind` accessor below.
    public var kindRaw: String

    /// Achieved metric value. Unit is kind-dependent (see type-doc).
    public var value: Double

    /// Previous best of the same kind for this exercise. 0 when there was no
    /// prior record (shouldn't happen because `PRDetector` requires history,
    /// but defensive default avoids force-unwraps in the chart layer).
    public var previousValue: Double

    /// Loaded weight (kg) on the PR-achieving set. 0 for bodyweight or pure
    /// time-based exercises. Kept on the row for the detail-line display.
    public var weightKg: Double

    /// Reps on the PR-achieving set. For `maxHoldSeconds` this is the seconds
    /// of the hold (matches the source `LiftAttempt` convention).
    public var reps: Int

    /// DEL-156: Cardio-Equipment-RawValue dieses PRs. `nil` = pre-DEL-156-
    /// Bestand oder Non-Cardio-PR → Computed `cardioEquipment` liefert `.none`.
    /// Trennt Cardio-PRs nach Modalitaet im Trophy-Room (Laufband ≠ Fahrrad).
    public var cardioEquipmentRaw: String? = nil

    /// Typed accessor. `.none` als Default fuer Strength/Bodyweight/TimeBased
    /// und Bestandsdaten ohne Snapshot.
    public var cardioEquipment: CardioEquipment {
        cardioEquipmentRaw.flatMap(CardioEquipment.init(rawValue:)) ?? .none
    }

    /// Back-link to the session in which the PR was set. Nullify (not cascade)
    /// so deleting a session doesn't lose the record's history.
    public var session: WorkoutSession?

    public init(
        date: Date,
        exerciseName: String,
        exerciseTemplateID: UUID? = nil,
        kindRaw: String,
        value: Double,
        previousValue: Double,
        weightKg: Double,
        reps: Int,
        cardioEquipmentRaw: String? = nil,
        session: WorkoutSession? = nil
    ) {
        self.date = date
        self.exerciseName = exerciseName
        self.exerciseTemplateID = exerciseTemplateID
        self.kindRaw = kindRaw
        self.value = value
        self.previousValue = previousValue
        self.weightKg = weightKg
        self.reps = reps
        self.cardioEquipmentRaw = cardioEquipmentRaw
        self.session = session
    }

    /// Typed accessor — returns nil if a stored row references an unknown kind
    /// (e.g. a future-version case that this build doesn't know yet). Callers
    /// should treat unknown kinds as "skip this row" rather than crashing.
    public var kind: PersonalRecord.Kind? {
        PersonalRecord.Kind(rawValue: kindRaw)
    }

    /// Convenience constructor from a value-type `PersonalRecord` produced by
    /// `PRDetector.detectPRs`. The session is attached separately because it's
    /// a `@Model` reference that the caller already has in hand.
    public convenience init(record: PersonalRecord, session: WorkoutSession?) {
        self.init(
            date: record.achievedAt,
            exerciseName: record.exerciseName,
            exerciseTemplateID: record.exerciseTemplateID,
            kindRaw: record.kind.rawValue,
            value: record.newValue,
            previousValue: record.previousValue,
            weightKg: record.weightKg,
            reps: record.reps,
            // DEL-156: Equipment aus dem detektierten Record uebernehmen.
            cardioEquipmentRaw: record.cardioEquipment == .none ? nil : record.cardioEquipment.rawValue,
            session: session
        )
    }
}
#endif
