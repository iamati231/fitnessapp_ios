#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// P8-Vorbereitung (Stufe-2-Versionierung, `docs/P8_STUFE2_VERSIONIERUNG_PLAN.md`):
/// der eingefrorene Tagesinhalt EINER `WorkoutSession`. Bewusst 1:0..1 an die
/// Session gehängt (nicht an `TrainingDay`/`TrainingPlan`) — diese erste
/// Stufe schützt historische Session-Inhalte, sie ist KEINE vollständige
/// Plan-/Tages-Versionshistorie (siehe Plan-Dokument, Abschnitt "Umfang
/// sauber begrenzen"). Nach Löschen des zugehörigen `TrainingDay` bleibt
/// dieser Record unverändert lesbar — die fehlende Plan-/Tag-Zuordnung
/// bleibt dann ausdrücklich `nil` auf `WorkoutSession.day`, wird aber NIE
/// aus diesem Inhalts-Snapshot heraus geraten (keine Namens-/Inhalts-
/// basierte Rückschlüsse auf einen gelöschten Tag).
///
/// **Schreibschutz ist ein Modul-Grenzen-Vertrag, kein Kommentar:**
/// `contentJSON`/`capturedAt` sind `public internal(set)` — lesbar wie jedes
/// andere `@Model`-Feld in diesem Codebase, aber nur innerhalb von
/// `FitnessAppData` beschreibbar. Jeder Schreibzugriff von außerhalb (also
/// aus `FitnessAppUI`, wo alle produktiven Aufrufer leben) muss zwingend
/// über `TrainingDayContentSnapshotWriter.capture(for:in:)` laufen. Dieser
/// Writer verweigert jede Änderung, sobald `session.isCompleted == true`
/// ist — der Compiler verhindert bereits, dass irgendein Aufrufer das
/// umgeht, indem er die Felder direkt setzt.
@Model
public final class TrainingDayContentRecord {
    /// JSON-codiertes `TrainingDayContentSnapshot` — siehe
    /// `TrainingDayContentSnapshot.decode(fromJSON:)`/`.encodedJSON()`.
    /// `public internal(set)` — lesbar wie jedes andere `@Model`-Feld in
    /// diesem Codebase, aber nur innerhalb von `FitnessAppData` schreibbar.
    /// Gleiches, bereits an anderer Stelle produktiv genutztes Muster wie
    /// `SharedStore.health` (`public internal(set) static var health`).
    public internal(set) var contentJSON: String

    /// Zeitpunkt der zuletzt gespeicherten Fassung — wird bei jeder
    /// erfolgreichen `capture`-Aufnahme fortgeschrieben (nicht nur beim
    /// ersten Mal), sodass er nach dem Einfrieren (`isCompleted == true`)
    /// den tatsächlichen letzten Schreibzeitpunkt zeigt.
    public internal(set) var capturedAt: Date

    /// Inverse zu `WorkoutSession.contentRecord` — dort liegt `deleteRule`
    /// + `inverse` (Cascade von Session zu Record: der Snapshot hat ohne
    /// seine Session keine eigenständige Bedeutung).
    public var session: WorkoutSession?

    init(contentJSON: String, capturedAt: Date) {
        self.contentJSON = contentJSON
        self.capturedAt = capturedAt
    }

    /// Öffentlicher Lesezugriff — unterscheidet die drei in
    /// `TrainingDayContentSnapshotState` benannten Fälle. Ein vorhandener,
    /// aber nicht lesbarer Record wird NIE stillschweigend durch den
    /// (ggf. seither veränderten) Live-Tagesinhalt ersetzt; das bleibt
    /// Sache des jeweiligen Aufrufers (Paket E, noch nicht Teil dieses
    /// Pakets).
    public var state: TrainingDayContentSnapshotState {
        switch TrainingDayContentSnapshot.decode(fromJSON: contentJSON) {
        case .success(let snapshot): return .available(snapshot)
        case .failure(let error): return .unreadable(error)
        }
    }
}

extension WorkoutSession {
    /// Bequemlichkeits-Accessor — fasst "kein Record vorhanden" (`nil`) und
    /// "Record vorhanden, siehe `state`" in den EINEN Drei-Fälle-Typ
    /// zusammen, den jeder Aufrufer ohnehin behandeln muss.
    public var contentSnapshotState: TrainingDayContentSnapshotState {
        contentRecord?.state ?? .notCaptured
    }
}

/// Einzige erlaubte Schreibstelle für `TrainingDayContentRecord`. Siehe
/// Typ-Dokumentation auf `TrainingDayContentRecord` für die Begründung.
public enum TrainingDayContentSnapshotWriter {

    /// Nimmt den AKTUELLEN Stand von `session.day?.activeExercises` auf und
    /// (über)schreibt `session.contentRecord`. Gibt `false` zurück und
    /// ändert NICHTS, wenn:
    ///
    ///   * `session.day == nil` (z. B. HealthKit-Import ohne Plan-Tag) — es
    ///     gibt nichts, das aufgenommen werden könnte.
    ///   * `session.isCompleted == true` — der Record ist eingefroren. Das
    ///     ist bewusst ein stiller, regulärer Rückgabewert statt eines
    ///     Assertion-Traps: ein späterer Aufrufer (Paket C) könnte diesen
    ///     Fall legitim erreichen (z. B. ein verspäteter Hintergrund-Call
    ///     nach dem Abschluss) und darf dafür nicht die ganze App/den
    ///     Testlauf zum Absturz bringen. Die eigentliche Durchsetzung ist
    ///     die Modul-Grenze (siehe Typ-Dokumentation) — der Rückgabewert ist
    ///     ein zusätzliches, nicht-fatales Signal für ehrliche Aufrufer, die
    ///     ihn auswerten.
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
        let now = Date()

        if let existing = session.contentRecord {
            existing.contentJSON = json
            existing.capturedAt = now
        } else {
            let record = TrainingDayContentRecord(contentJSON: json, capturedAt: now)
            context.insert(record)
            session.contentRecord = record
        }
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
