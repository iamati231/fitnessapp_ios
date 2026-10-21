#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// P8 Stufe-2 (Session-Inhaltsvertrag, Wiederaufnahme-Isolation): wie eine
/// laufende/wiederaufgenommene `WorkoutSession` ihren eigenen, eingefrorenen
/// Tagesinhalt (`contentSnapshotState`) gegen den AKTUELLEN Stand von
/// `day.activeExercises` auflöst — unabhängig davon, ob der Live-Tag seit
/// Session-Start extern umsortiert, erweitert, verkürzt oder in den
/// Zielwerten geändert wurde (Auftrag: "eine laufende Session behält ihren
/// eigenen Inhaltsstand" gilt auch für Wiederaufnahme, nicht nur für das
/// Snapshot-JSON selbst). Entry-Reihenfolge, -Rolle und -Zielwerte sind
/// IMMER die zum Aufnahmezeitpunkt eingefrorenen (`entry`) — nie die
/// (ggf. seither extern geänderten) Live-`Exercise`-Felder.
public enum ResolvedSessionExercise: Identifiable, Sendable {
    /// Der Snapshot-Eintrag ist zweifelsfrei diesem noch existierenden
    /// Live-Objekt zugeordnet — Logging schreibt gegen `exercise` (die
    /// Beziehung/Identität bleibt erhalten, `ExerciseLog` bekommt einen
    /// echten `exercise`-Pointer), Anzeige/Zielwerte kommen aus `entry`.
    case live(entry: TrainingDayContentSnapshot.ExerciseEntry, exercise: Exercise)
    /// Das Live-Objekt, aus dem dieser Eintrag stammte, existiert nicht
    /// mehr (extern gelöscht, während die Session offen war). Wird NIE
    /// stillschweigend aus der Liste entfernt — Aufrufer zeigen diesen Fall
    /// sichtbar (read-only), analog zu orphanen `ExerciseLog`s in der
    /// Historie (`ExerciseLogGrouping`). Neues Logging ist dafür bewusst
    /// NICHT vorgesehen (kein Live-Objekt, an das ein neuer Satz andocken
    /// könnte, ohne die "Snapshot-Eintrag = editierbares Live-Planobjekt"-
    /// Grenze zu verwischen) — bereits vor der Löschung erfasste Logs
    /// bleiben über ihre eigenen Snapshot-Felder unverändert sichtbar.
    case removedFromLiveDay(entry: TrainingDayContentSnapshot.ExerciseEntry)

    public var entry: TrainingDayContentSnapshot.ExerciseEntry {
        switch self {
        case .live(let entry, _): return entry
        case .removedFromLiveDay(let entry): return entry
        }
    }

    /// Stabil innerhalb EINES Snapshots (unterschiedliche Einträge haben
    /// nie denselben `orderIndex`, auch zwei gleichnamige Vorkommen nicht —
    /// siehe `TrainingDayContentSnapshot.ExerciseEntry.orderIndex`-Doku).
    public var id: Int { entry.orderIndex }

    public var exercise: Exercise? {
        if case .live(_, let exercise) = self { return exercise }
        return nil
    }
}

/// Einzige Stelle, die Player (`ActiveWorkoutView`, `TimedWorkoutPlayerView`,
/// `CircuitWorkoutPlayerView`) für "welche Übungen, in welcher Reihenfolge,
/// mit welchen Zielwerten tatsächlich trainiert werden" konsultieren.
public enum SessionContentResolver {
    /// Löst `snapshot.exercises` (sortiert nach `orderIndex`, dem
    /// Aufnahmezeitpunkt-Stand) gegen `liveExercises` auf. Matching PRIMÄR
    /// über `instanceID` (stabil über externe Umsortierungen hinweg,
    /// anders als `orderIndex` selbst); fehlt sie (Snapshot vor diesem Feld
    /// aufgenommen, oder das Live-Gegenstück trägt selbst keine) oder
    /// findet sich keine Übereinstimmung, Fallback auf
    /// `exerciseTemplateID`+`orderIndex` — das bisherige, bestmögliche
    /// Verhalten für Altbestand. Eine Live-`Exercise`, die NICHT im
    /// Snapshot vorkommt (extern seit Session-Start hinzugefügt), taucht
    /// hier nie auf — allein durch die Konstruktion (iteriert wird über
    /// `snapshot.exercises`, nie über `liveExercises`).
    public static func resolve(
        snapshot: TrainingDayContentSnapshot,
        liveExercises: [Exercise]
    ) -> [ResolvedSessionExercise] {
        snapshot.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { entry in
                if let exercise = matchByInstanceID(entry, in: liveExercises)
                    ?? matchByTemplateAndOrderIndex(entry, in: liveExercises) {
                    return .live(entry: entry, exercise: exercise)
                }
                return .removedFromLiveDay(entry: entry)
            }
    }

    private static func matchByInstanceID(
        _ entry: TrainingDayContentSnapshot.ExerciseEntry,
        in liveExercises: [Exercise]
    ) -> Exercise? {
        guard let instanceID = entry.instanceID else { return nil }
        return liveExercises.first { $0.instanceID == instanceID }
    }

    /// Bestmöglicher Fallback für Snapshots, die vor `instanceID`
    /// aufgenommen wurden. Exakt das Verhalten vor diesem Fix — bekannt
    /// unsicher nach externen Umsortierungen, aber nicht schlechter als der
    /// Zustand davor, und nur für Alt-Sessions relevant.
    private static func matchByTemplateAndOrderIndex(
        _ entry: TrainingDayContentSnapshot.ExerciseEntry,
        in liveExercises: [Exercise]
    ) -> Exercise? {
        liveExercises.first {
            $0.orderIndex == entry.orderIndex && $0.exerciseTemplateID == entry.exerciseTemplateID
        }
    }
}
#endif
