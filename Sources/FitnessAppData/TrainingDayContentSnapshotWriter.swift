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
///
/// **Lebenszyklus-Vertrag (verbindlich, korrigiert gegenüber einer
/// früheren Planungsfassung):** eine laufende Session behält ihren EIGENEN
/// Inhaltsstand. `capture` liest den Live-Tag NUR EIN EINZIGES MAL — bei
/// der Erzeugung, wenn es noch keinen eigenen Stand gibt (guard:
/// `contentSnapshotJSON == nil`). Explizite Änderungen INNERHALB der
/// Session (Ad-hoc-Übung hinzufügen/entfernen/bearbeiten) aktualisieren
/// danach gezielt NUR den eigenen, bereits bestehenden Snapshot
/// (`recordAdHocExercise…`)
/// — nie durch einen erneuten vollständigen Re-Read des Live-Tages, der
/// zwischenzeitliche EXTERNE Änderungen (DayEditorView, Equipment-
/// Anpassung) unbemerkt mit übernehmen würde. Beim Abschluss gibt es
/// AUSDRÜCKLICH KEINEN erneuten `capture`-Aufruf — der zuletzt vorhandene
/// Stand wird eingefroren, nicht neu erzeugt (`capture`s
/// `!session.isCompleted`-Guard bleibt als zusätzliche Absicherung
/// bestehen, ist aber nicht der primäre Schutz). Bei Wiederaufnahme einer
/// offenen Session wird `capture` NIE erneut aufgerufen — der
/// `contentSnapshotJSON == nil`-Guard würde einen zweiten Aufruf zwar
/// ohnehin ablehnen, Aufrufer dürfen sich darauf aber nicht verlassen und
/// müssen `capture` schlicht nur am Erzeugungs-Ort aufrufen. Für Alt-
/// Sessions ohne Snapshot wird nie nachträglich einer erzeugt — `nil`
/// bleibt ein gültiger Dauerzustand.
///
/// **Expliziter Save (Geräteabnahme-Befund, Stufe-2-Abnahme Block C):**
/// jede Funktion hier ruft nach dem Setzen von `contentSnapshotJSON`/
/// `.contentSnapshotCapturedAt` explizit `try? context.save()` auf, statt
/// sich auf SwiftDatas impliziten Autosave zu verlassen. Ein echter
/// TestingBot-Gerätetest hat reproduziert, dass ein Ad-hoc-Edit + "+Satz"
/// nach einem Prozess-Kill kurz danach spurlos verloren gingen, obwohl sie
/// vor dem Kill live sichtbar bestätigt waren — der implizite Autosave
/// hatte schlicht noch nicht gegriffen. Folgt damit derselben Konvention
/// wie die meisten anderen Schreibstellen in `FitnessAppData` (z. B.
/// `DeloadManager`, `FourWeekReviewDueStatus`), die bisher nur in dieser
/// einen, für den Session-Inhaltsvertrag zentralen Datei fehlte.
public enum TrainingDayContentSnapshotWriter {

    /// Initial-Aufnahme bei Session-ERZEUGUNG — der einzige Aufrufzeitpunkt,
    /// an dem ein voller Re-Read von `session.day?.activeExercises` korrekt
    /// ist (es gibt noch keinen eigenen Stand). Gibt `false` zurück und
    /// ändert NICHTS, wenn:
    ///
    ///   * `session.day == nil` (z. B. HealthKit-Import ohne Plan-Tag) — es
    ///     gibt nichts, das aufgenommen werden könnte.
    ///   * `session.isCompleted == true` — unerwartet an diesem Aufrufpunkt,
    ///     aber defensiv abgesichert statt eines Traps.
    ///   * `session.contentSnapshotJSON != nil` — es existiert bereits ein
    ///     eigener Stand (erneuter Aufruf, z. B. versehentlich bei
    ///     Wiederaufnahme). Ein zweiter `capture`-Aufruf ist IMMER ein
    ///     No-Op, nie ein Überschreiben — das ist der technische Schutz
    ///     hinter "bei Wiederaufnahme niemals ersetzen".
    ///
    /// Aufrufer (Paket C): genau einmal, unmittelbar nach
    /// `context.insert(session)` an jeder produktiven Erzeugungsstelle mit
    /// `day != nil`.
    @discardableResult
    public static func capture(for session: WorkoutSession, in context: ModelContext) -> Bool {
        guard let day = session.day,
              !session.isCompleted,
              session.contentSnapshotJSON == nil
        else { return false }

        let snapshot = buildSnapshot(from: day)
        guard let json = snapshot.encodedJSON() else { return false }

        session.contentSnapshotJSON = json
        session.contentSnapshotCapturedAt = Date()
        try? context.save()   // explizit, siehe Enum-Dokumentation oben.
        return true
    }

    /// Explizite In-Session-Änderung: eine Ad-hoc-Übung wurde WÄHREND der
    /// laufenden Session hinzugefügt (`ActiveWorkoutView.addAdHocExercise`/
    /// `addAdHocCustomExercise`). Hängt GENAU EINEN neuen Eintrag an den
    /// bereits bestehenden Snapshot an — liest NICHT erneut den ganzen
    /// Live-Tag, kann also auch keine zwischenzeitliche externe Änderung
    /// aufnehmen. Gibt `false` zurück und ändert NICHTS, wenn:
    ///
    ///   * `session.isCompleted == true` — eingefroren.
    ///   * `session.isAdHoc == false` — nur Ad-hoc-Sessions haben ein
    ///     ausschließlich ihnen gehörendes, ephemeres `day` (kein externer
    ///     Mutationspfad erreicht es); produktiv aktuell ohnehin der
    ///     einzige Aufrufpfad (s. `ActiveWorkoutView`: "+ Übung" nur bei
    ///     Ad-hoc-Sessions), die Prüfung ist zusätzliche Absicherung durch
    ///     Konstruktion statt durch Aufrufer-Disziplin allein.
    ///   * es noch KEINEN bestehenden Snapshot gibt (`.notCaptured`) — kann
    ///     an einer Ad-hoc-Session praktisch nicht vorkommen (`capture`
    ///     läuft bei Erzeugung immer erfolgreich durch, auch mit leerer
    ///     Übungsliste), wird aber nicht stillschweigend nachgeholt.
    ///   * der bestehende Snapshot `.unreadable` ist — ein beschädigter
    ///     Snapshot wird nie durch einen aus dem Live-Tag neu zusammen-
    ///     gebauten ersetzt.
    @discardableResult
    public static func recordAdHocExerciseAdded(
        _ exercise: Exercise,
        to session: WorkoutSession,
        in context: ModelContext
    ) -> Bool {
        guard !session.isCompleted, session.isAdHoc,
              case .available(let existing) = session.contentSnapshotState
        else { return false }

        var exercises = existing.exercises
        exercises.append(snapshotEntry(for: exercise))
        let updated = existing.withExercises(exercises)
        guard let json = updated.encodedJSON() else { return false }

        session.contentSnapshotJSON = json
        session.contentSnapshotCapturedAt = Date()
        try? context.save()   // explizit, siehe Enum-Dokumentation oben.
        return true
    }

    /// Gegenstück zu `recordAdHocExerciseAdded` — entfernt GENAU den
    /// Eintrag, dessen `orderIndex` dem der übergebenen (noch nicht
    /// gelöschten!) `Exercise` entspricht. Aufrufer übergibt die Übung VOR
    /// dem eigentlichen `context.delete(exercise)`. Gleiche Guards wie
    /// `recordAdHocExerciseAdded`.
    @discardableResult
    public static func recordAdHocExerciseRemoved(
        _ exercise: Exercise,
        from session: WorkoutSession,
        in context: ModelContext
    ) -> Bool {
        guard !session.isCompleted, session.isAdHoc,
              case .available(let existing) = session.contentSnapshotState
        else { return false }

        let exercises = existing.exercises.filter { $0.orderIndex != exercise.orderIndex }
        let updated = existing.withExercises(exercises)
        guard let json = updated.encodedJSON() else { return false }

        session.contentSnapshotJSON = json
        session.contentSnapshotCapturedAt = Date()
        try? context.save()   // explizit, siehe Enum-Dokumentation oben.
        return true
    }

    /// Explizite In-Session-Änderung (P8 Stufe-2, Wiederaufnahme-Isolation):
    /// eine BESTEHENDE Ad-hoc-Übung wurde WÄHREND der laufenden Session über
    /// den Übungseditor bearbeitet (`ActiveWorkoutView`s `exerciseToEdit`-
    /// Sheet — NUR von dort aufgerufen, NIE aus `DayEditorView`, das
    /// denselben Editor auch für reguläre Plan-Übungen UND unabhängig von
    /// einer offenen Session öffnet; ein Aufruf von dort wäre exakt die
    /// verbotene "nachträgliche Vermischung mit externen Änderungen").
    /// Ersetzt GENAU den Eintrag, dessen Identität (`instanceID`, Fallback
    /// `orderIndex`) der übergebenen `Exercise` entspricht, durch ihre
    /// AKTUELLEN Feldwerte — liest nicht erneut den ganzen Live-Tag, kann
    /// also auch keine zwischenzeitliche externe Änderung an einer ANDEREN
    /// Übung aufnehmen. Gibt `false` zurück und ändert NICHTS bei denselben
    /// Guards wie `recordAdHocExerciseAdded`, plus: kein Eintrag mit
    /// passender Identität gefunden (kann an einer Ad-hoc-Session praktisch
    /// nicht vorkommen, da jede Ad-hoc-Übung über `recordAdHocExerciseAdded`
    /// entsteht).
    @discardableResult
    public static func recordAdHocExerciseEdited(
        _ exercise: Exercise,
        within session: WorkoutSession,
        in context: ModelContext
    ) -> Bool {
        guard !session.isCompleted, session.isAdHoc,
              case .available(let existing) = session.contentSnapshotState
        else { return false }

        guard let index = existing.exercises.firstIndex(where: { entry in
            if let instanceID = entry.instanceID, let liveID = exercise.instanceID {
                return instanceID == liveID
            }
            return entry.orderIndex == exercise.orderIndex
        }) else { return false }

        var exercises = existing.exercises
        exercises[index] = snapshotEntry(for: exercise)
        let updated = existing.withExercises(exercises)
        guard let json = updated.encodedJSON() else { return false }

        session.contentSnapshotJSON = json
        session.contentSnapshotCapturedAt = Date()
        try? context.save()   // explizit, siehe Enum-Dokumentation oben.
        return true
    }

    /// Explizite In-Session-Änderung (P8 Stufe-2, Wiederaufnahme-Isolation):
    /// die "+ Satz"/Satz-entfernen-Aktion direkt auf einer `ExerciseCard`
    /// (`ExerciseCard.addSet`/`removeSet`) mutiert `exercise.sets` live — und
    /// zwar für JEDE Session, nicht nur Ad-hoc (anders als der
    /// Übungseditor, der aus `ActiveWorkoutView` heraus nur für Ad-hoc
    /// erreichbar ist). Diese Aktion ist trotzdem NIE "extern": sie existiert
    /// ausschließlich als Steuerelement auf der Karte DIESER laufenden
    /// Session. Deshalb — anders als `recordAdHocExercise…` — KEIN
    /// `session.isAdHoc`-Guard hier. Aktualisiert chirurgisch NUR das
    /// `sets`-Feld des passenden Eintrags (Matching: `instanceID`, Fallback
    /// `orderIndex`) — NICHT per vollem `snapshotEntry(for:)`-Rebuild, damit
    /// ein zwischenzeitlich auf einem ANDEREN Weg (DayEditorView) verändertes
    /// Feld derselben Übung nicht unbemerkt huckepack mit übernommen wird.
    /// Gibt `false` zurück und ändert NICHTS, wenn `session.isCompleted`,
    /// kein Snapshot existiert (`.notCaptured`/`.unreadable`) oder keine
    /// passende Eintrags-Identität gefunden wird.
    @discardableResult
    public static func recordSetCountChange(
        for exercise: Exercise,
        in session: WorkoutSession,
        context: ModelContext
    ) -> Bool {
        guard !session.isCompleted,
              case .available(let existing) = session.contentSnapshotState
        else { return false }

        guard let index = existing.exercises.firstIndex(where: { entry in
            if let instanceID = entry.instanceID, let liveID = exercise.instanceID {
                return instanceID == liveID
            }
            return entry.orderIndex == exercise.orderIndex
        }) else { return false }

        var exercises = existing.exercises
        let entry = exercises[index]
        exercises[index] = TrainingDayContentSnapshot.ExerciseEntry(
            orderIndex: entry.orderIndex,
            instanceID: entry.instanceID,
            exerciseTemplateID: entry.exerciseTemplateID,
            nameSnapshot: entry.nameSnapshot,
            customNameSnapshot: entry.customNameSnapshot,
            role: entry.role,
            supersetId: entry.supersetId,
            isCardio: entry.isCardio,
            isTimeBased: entry.isTimeBased,
            cardioEquipment: entry.cardioEquipment,
            sets: exercise.sets,
            repsMin: entry.repsMin,
            repsMax: entry.repsMax,
            restSeconds: entry.restSeconds,
            targetRir: entry.targetRir,
            targetDistanceKm: entry.targetDistanceKm,
            targetDurationMinutes: entry.targetDurationMinutes
        )
        let updated = existing.withExercises(exercises)
        guard let json = updated.encodedJSON() else { return false }

        session.contentSnapshotJSON = json
        session.contentSnapshotCapturedAt = Date()
        try? context.save()   // explizit, siehe Enum-Dokumentation oben.
        return true
    }

    /// Reihenfolge wie `TrainingDay.currentContentFingerprint`
    /// (`activeExercises`, sortiert nach `orderIndex`) — dieselbe, bereits
    /// gepflegte Definition von "was gehört zum sichtbaren Tagesinhalt".
    private static func buildSnapshot(from day: TrainingDay) -> TrainingDayContentSnapshot {
        let exercises = day.activeExercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(snapshotEntry(for:))
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
            enduranceWarmupDurationSeconds: day.enduranceWarmupDurationSeconds,
            enduranceCooldownDurationSeconds: day.enduranceCooldownDurationSeconds,
            enduranceIntervalRounds: day.enduranceIntervalRounds,
            enduranceWorkDurationSeconds: day.enduranceWorkDurationSeconds,
            enduranceWorkDistanceKm: day.enduranceWorkDistanceKm,
            enduranceRestDurationSeconds: day.enduranceRestDurationSeconds,
            exercises: exercises
        )
    }

    /// Öffentlich (zusätzlich zur internen Nutzung in `buildSnapshot`/
    /// `recordAdHocExercise…`): `SessionContentResolver`-Aufrufer ohne
    /// lesbaren Snapshot (`.notCaptured`/`.unreadable`, z. B. Alt-Sessions
    /// vor diesem Feature) synthetisieren hiermit einen äquivalenten
    /// Eintrag aus dem AKTUELLEN Live-Tag als Fallback-Anzeigebasis — exakt
    /// dieselbe Feldzuordnung, die auch `capture` verwendet, keine
    /// zweite, potenziell abweichende Kopie der Logik.
    public static func snapshotEntry(for exercise: Exercise) -> TrainingDayContentSnapshot.ExerciseEntry {
        TrainingDayContentSnapshot.ExerciseEntry(
            orderIndex: exercise.orderIndex,
            instanceID: exercise.instanceID,
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
}
#endif
