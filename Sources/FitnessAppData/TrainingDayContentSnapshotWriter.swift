#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// P8-Vorbereitung (Stufe-2-Versionierung, `docs/P8_STUFE2_VERSIONIERUNG_PLAN.md`):
/// Lesezugriff auf `WorkoutSession.contentSnapshotJSON`. Siehe die
/// Feld-Dokumentation auf `WorkoutSession` für die Begründung, warum der
/// Snapshot ein Feldpaar auf dem bestehenden Modell ist statt eines
/// eigenen `@Model`.
extension WorkoutSession {
    /// Öffentlicher Lesezugriff — unterscheidet die drei in
    /// `TrainingDayContentSnapshotState` benannten Fälle. Ein vorhandener,
    /// aber nicht lesbarer Snapshot wird NIE stillschweigend durch den
    /// (ggf. seither veränderten) Live-Tagesinhalt ersetzt; das bleibt
    /// Sache des jeweiligen Aufrufers (Paket E, noch nicht Teil dieses
    /// Pakets).
    public var contentSnapshotState: TrainingDayContentSnapshotState {
        guard let json = contentSnapshotJSON else { return .notCaptured }
        switch TrainingDayContentSnapshot.decode(fromJSON: json) {
        case .success(let snapshot): return .available(snapshot)
        case .failure(let error): return .unreadable(error)
        }
    }
}

/// Einzige erlaubte Schreibstelle für `WorkoutSession.contentSnapshotJSON`/
/// `.contentSnapshotCapturedAt`. Siehe Feld-Dokumentation auf
/// `WorkoutSession` für die Begründung.
public enum TrainingDayContentSnapshotWriter {

    /// Nimmt den AKTUELLEN Stand von `session.day?.activeExercises` auf und
    /// (über)schreibt `session.contentSnapshotJSON`. Gibt `false` zurück
    /// und ändert NICHTS, wenn:
    ///
    ///   * `session.day == nil` (z. B. HealthKit-Import ohne Plan-Tag) — es
    ///     gibt nichts, das aufgenommen werden könnte.
    ///   * `session.isCompleted == true` — der Snapshot ist eingefroren.
    ///     Das ist bewusst ein stiller, regulärer Rückgabewert statt eines
    ///     Assertion-Traps: ein späterer Aufrufer (Paket C) könnte diesen
    ///     Fall legitim erreichen (z. B. ein verspäteter Hintergrund-Call
    ///     nach dem Abschluss) und darf dafür nicht die ganze App/den
    ///     Testlauf zum Absturz bringen.
    ///
    /// Aufrufer (Paket C, noch nicht Teil dieses Pakets): einmal bei
    /// Session-Erzeugung, erneut bei jeder Ad-hoc-Übungsänderung
    /// WÄHREND der Session, und ein letztes Mal unmittelbar VOR dem Setzen
    /// von `isCompleted = true` (Reihenfolge wichtig — danach wäre der aktuelle
    /// Call ein No-Op).
    @discardableResult
    public static func capture(for session: WorkoutSession, in context: ModelContext) -> Bool {
        guard let day = session.day, !session.isCompleted else { return false }

        let snapshot = buildSnapshot(from: day)
        guard let json = snapshot.encodedJSON() else { return false }

        session.contentSnapshotJSON = json
        session.contentSnapshotCapturedAt = Date()
        return true
    }

    /// Reihenfolge wie `TrainingDay.currentContentFingerprint`
    /// (`activeExercises`, sortiert nach `orderIndex`) — dieselbe, bereits
    /// gepflegte Definition von "was gehört zum sichtbaren Tagesinhalt".
    private static func buildSnapshot(from day: TrainingDay) -> TrainingDayContentSnapshot {
        let exercises = day.activeExercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { exercise in
                TrainingDayContentSnapshot.ExerciseEntry(
                    orderIndex: exercise.orderIndex,
                    exerciseTemplateID: exercise.exerciseTemplateID,
                    nameSnapshot: exercise.name,
                    customNameSnapshot: exercise.customName,
                    role: exercise.role,
                    supersetId: exercise.supersetId,
                    isCardio: exercise.isCardio,
                    isTimeBased: exercise.isTimeBased,
                    cardioEquipment: exercise.cardioEquipment,
                    sets: exercise.sets,
                    repsMin: exercise.repsMin,
                    repsMax: exercise.repsMax,
                    restSeconds: exercise.restSeconds,
                    targetRir: exercise.targetRir,
                    targetDistanceKm: exercise.targetDistanceKm,
                    targetDurationMinutes: exercise.targetDurationMinutes
                )
            }
        return TrainingDayContentSnapshot(
            dayNameSnapshot: day.name,
            dayCustomNameSnapshot: day.customName,
            dayLocalizationKeySnapshot: day.localizationKey,
            weekday: day.weekday,
            dayType: day.type,
            timeFormat: day.timeFormat,
            timeCapMinutes: day.timeCapMinutes,
            circuitRounds: day.circuitRounds,
            circuitRestSeconds: day.circuitRestSeconds,
            circuitMode: day.circuitMode,
            exercises: exercises
        )
    }
}
#endif
