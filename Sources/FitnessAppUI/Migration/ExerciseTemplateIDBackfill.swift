#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppData

/// Settings-Epic Phase 6 (EXLIB-07/09): One-Shot-Migration, die Bestands-
/// `Exercise`/`ExerciseLog`/`PersonalRecordEntry`-Zeilen rueckwirkend mit der
/// stabilen `ExerciseTemplate.id` verknuepft, wo das eindeutig moeglich ist.
///
/// **Warum ueberhaupt noetig:** Vor dieser Phase kopierte der Adopt-Pfad nur
/// den Namen (`Exercise.name`). Ohne diesen Backfill bliebe JEDE Historie,
/// die vor diesem Update entstand, fuer immer `exerciseTemplateID == nil` —
/// nur neu geloggte Saetze waeren vor einem spaeteren Umbenennen geschuetzt.
///
/// **Match-Regel — bewusst konservativ, kein Raten:** Pro Eintrag wird genau
/// dann verknuepft, wenn GENAU EINE `ExerciseTemplate` exakt denselben Namen
/// traegt wie der gespeicherte Namens-Snapshot. Zwei oder mehr Treffer (z.B.
/// eine Custom-Uebung zufaellig gleich benannt wie eine System-Uebung, oder
/// zwei Customs mit identischem Namen) ODER gar kein Treffer lassen die ID
/// bewusst `nil` — es wird NICHT anhand AEHNLICHER Namen geraten, nur bei
/// exaktem UND eindeutigem Treffer verknuepft. Fuer System-Uebungen ist das
/// praktisch immer eindeutig (Namen sind read-only und laut Katalog-Test
/// kollisionsfrei); fuer Custom-Uebungen ist es eindeutig, solange der User
/// zum Zeitpunkt dieser Migration noch keine zwei gleich benannten eigenen
/// Vorlagen besitzt. Unaufloesbare Alt-Eintraege verlieren dadurch keine
/// Daten — sie fallen weiterhin auf den Namens-Snapshot zurueck, exakt das
/// Verhalten vor dieser Phase (siehe `resolvedExerciseTemplateID`-Aufrufer).
///
/// **MUSS NACH `ExerciseNameBackfill.runIfNeeded` laufen** — sonst waeren
/// Fremdsprach-Namens-Snapshots (z.B. "Treadmill" statt "Laufband") noch
/// nicht auf den DE-Base umgeschrieben und fielen faelschlich als
/// unaufloesbar durch.
///
/// **Idempotent:** Ueberspringt Zeilen, die bereits eine ID tragen — nach
/// dem ersten erfolgreichen Durchlauf laeuft die Funktion praktisch leer.
@MainActor
public enum ExerciseTemplateIDBackfill {

    /// Fuehrt den Backfill aus. Returns die Anzahl der verknuepften Zeilen
    /// (Summe ueber alle drei Tables) — nuetzlich fuer Logging/Telemetry.
    @discardableResult
    public static func runIfNeeded(in context: ModelContext) -> Int {
        let templates = (try? context.fetch(FetchDescriptor<ExerciseTemplate>())) ?? []
        guard !templates.isEmpty else { return 0 }

        var templatesByName: [String: [ExerciseTemplate]] = [:]
        for template in templates {
            templatesByName[template.name, default: []].append(template)
        }

        // Nur bei GENAU einem Treffer verknuepfen — siehe Typ-Doc.
        func uniqueMatch(forName name: String) -> UUID? {
            guard let matches = templatesByName[name], matches.count == 1 else { return nil }
            return matches[0].id
        }

        var fixed = 0

        // ─── 1) Exercises ────────────────────────────────────────────
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for ex in exercises {
            guard ex.exerciseTemplateID == nil,
                  let id = uniqueMatch(forName: ex.name)
            else { continue }
            ex.exerciseTemplateID = id
            fixed += 1
        }

        // ─── 2) ExerciseLog-Snapshots ────────────────────────────────
        // Logs ohne eigenen Namens-Snapshot (sehr alter, pre-DEL-051-Bestand)
        // bleiben hier unangetastet — `resolvedExerciseTemplateID` faellt in
        // dem Fall ohnehin auf die (jetzt ggf. oben frisch verknuepfte)
        // Live-`exercise`-Referenz zurueck, exakt wie `resolvedExerciseName`.
        let logs = (try? context.fetch(FetchDescriptor<ExerciseLog>())) ?? []
        for log in logs {
            guard log.exerciseTemplateIDSnapshot == nil,
                  let snap = log.exerciseNameSnapshot,
                  let id = uniqueMatch(forName: snap)
            else { continue }
            log.exerciseTemplateIDSnapshot = id
            fixed += 1
        }

        // ─── 3) PersonalRecordEntry ──────────────────────────────────
        // WOD-Zeitformat-PRs tragen den WOD-Namen in `exerciseName`, der
        // nie eine `ExerciseTemplate` matcht — `uniqueMatch` liefert dort
        // automatisch `nil`, keine Sonderbehandlung noetig.
        let prEntries = (try? context.fetch(FetchDescriptor<PersonalRecordEntry>())) ?? []
        for entry in prEntries {
            guard entry.exerciseTemplateID == nil,
                  let id = uniqueMatch(forName: entry.exerciseName)
            else { continue }
            entry.exerciseTemplateID = id
            fixed += 1
        }

        return fixed
    }
}
#endif
