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
/// **Bewusst KEINE `@Relationship` zu `WorkoutSession`:** eine erste Fassung
/// nutzte `@Relationship(inverse:)` auf beiden Seiten (1:0..1, zu-eins/zu-
/// eins) — das stürzte auf Apple-CI reproduzierbar mit Signal 5 ab, ein
/// `brk #0x1`-Trap INNERHALB von SwiftData selbst (lldb-Backtrace,
/// unabhängig von `deleteRule` .cascade/.nullify, In-Memory-/On-Disk-Store
/// und Parallelität — siehe Commit-Historie). Stattdessen: ein einfacher
/// `sessionID`-Scalar, gleiches bereits etablierte Muster wie
/// `ExerciseTemplate.id`/`Exercise.exerciseTemplateID` in diesem Codebase.
/// Lookups laufen als "breiter Fetch + In-Memory-Filter" statt per
/// `#Predicate` — ebenfalls ein bereits etabliertes Muster hier (siehe
/// `PersonalRecordSync`/`HealthExportMarker`-Kommentare zu Predicate-
/// Fragilität).
@Model
public final class TrainingDayContentRecord {
    /// Fremdschlüssel auf `WorkoutSession.id` (siehe dortige Dokumentation).
    /// Kein `@Relationship` — siehe Typ-Dokumentation.
    public var sessionID: UUID
    public var contentJSON: String
    public var capturedAt: Date

    init(sessionID: UUID, contentJSON: String, capturedAt: Date) {
        self.sessionID = sessionID
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
    /// Breiter Fetch + In-Memory-Filter statt `#Predicate` (siehe
    /// Typ-Dokumentation auf `TrainingDayContentRecord`). Erfordert einen
    /// expliziten `ModelContext` — anders als eine `@Relationship` gibt es
    /// hier keinen impliziten Pfad vom Modell zu seinem Context, was auch
    /// dem bestehenden Codebase-Stil entspricht (jede Stelle, die einen
    /// `ModelContext` braucht, bekommt ihn explizit uebergeben statt ihn
    /// "von irgendwo" zu holen).
    public func contentRecord(in context: ModelContext) -> TrainingDayContentRecord? {
        let all = (try? context.fetch(FetchDescriptor<TrainingDayContentRecord>())) ?? []
        return all.first { $0.sessionID == id }
    }

    /// Bequemlichkeits-Accessor — fasst "kein Record vorhanden" (`nil`) und
    /// "Record vorhanden, siehe `state`" in den EINEN Drei-Fälle-Typ
    /// zusammen, den jeder Aufrufer ohnehin behandeln muss.
    public func contentSnapshotState(in context: ModelContext) -> TrainingDayContentSnapshotState {
        contentRecord(in: context)?.state ?? .notCaptured
    }
}

/// Einzige erlaubte Schreibstelle für `TrainingDayContentRecord`. Siehe
/// Typ-Dokumentation auf `TrainingDayContentRecord` für die Begründung.
public enum TrainingDayContentSnapshotWriter {

    /// Nimmt den AKTUELLEN Stand von `session.day?.activeExercises` auf und
    /// (über)schreibt den zu `session` gehoerenden Record. Gibt `false`
    /// zurück und ändert NICHTS, wenn:
    ///
    ///   * `session.day == nil` (z. B. HealthKit-Import ohne Plan-Tag) — es
    ///     gibt nichts, das aufgenommen werden könnte.
    ///   * `session.isCompleted == true` — der Record ist eingefroren. Das
    ///     ist bewusst ein stiller, regulärer Rückgabewert statt eines
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
        let now = Date()

        if let existing = session.contentRecord(in: context) {
            existing.contentJSON = json
            existing.capturedAt = now
        } else {
            let record = TrainingDayContentRecord(sessionID: session.id, contentJSON: json, capturedAt: now)
            context.insert(record)
        }
        return true
    }

    /// Entfernt den zu `session` gehoerenden Record, falls vorhanden — ein
    /// verwaister Record ohne Session hat keine eigenständige Bedeutung.
    /// Bewusst EXPLIZIT statt einer automatischen `@Relationship`-Cascade
    /// (siehe Typ-Dokumentation): **jede Stelle, die künftig eine
    /// `WorkoutSession` löscht, muss diese Funktion VOR `context.delete
    /// (session)` aufrufen.** Heute löscht noch kein produktiver Call-Site
    /// eine `WorkoutSession` (geprüft) — diese Funktion ist bewusst bereits
    /// vorhanden, aber noch ungenutzt, fuer Paket C.
    @discardableResult
    public static func deleteRecord(for session: WorkoutSession, in context: ModelContext) -> Bool {
        guard let record = session.contentRecord(in: context) else { return false }
        context.delete(record)
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
