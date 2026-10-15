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
        // Bugfix (Geraetetest): erst Kollisionen auf den Vorlagen selbst
        // reparieren (siehe Doc dort), bevor ueberhaupt irgendetwas anhand
        // der `id` verknuepft wird — sonst wuerde eine kollidierende ID in
        // genau diesem Lauf noch an eine falsche Uebung verknuepft.
        repairDuplicateTemplateIDsIfNeeded(in: context)

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

        // Bugfix (Geraetetest): Konsistenz-Check statt blindem "ueberspringen,
        // wenn schon gesetzt". Eine bereits gesetzte ID, die zu KEINER
        // Vorlage mit demselben Namen mehr gehoert (z.B. weil
        // `LibrarySeeder.deduplicateTemplatesIfNeeded` genau die Vorlage
        // geloescht hat, auf die diese ID zeigte, oder durch eine fruehere
        // ID-Kollision), wird zurueckgesetzt und unten neu aufgeloest statt
        // dauerhaft falsch (oder ins Leere) zu zeigen.
        func isConsistent(id: UUID, name: String) -> Bool {
            templatesByName[name]?.contains { $0.id == id } ?? false
        }

        var fixed = 0

        // ─── 1) Exercises ────────────────────────────────────────────
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for ex in exercises {
            if let current = ex.exerciseTemplateID, !isConsistent(id: current, name: ex.name) {
                ex.exerciseTemplateID = nil
            }
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
            if let snap = log.exerciseNameSnapshot,
               let current = log.exerciseTemplateIDSnapshot,
               !isConsistent(id: current, name: snap) {
                log.exerciseTemplateIDSnapshot = nil
            }
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
            if let current = entry.exerciseTemplateID, !isConsistent(id: current, name: entry.exerciseName) {
                entry.exerciseTemplateID = nil
            }
            guard entry.exerciseTemplateID == nil,
                  let id = uniqueMatch(forName: entry.exerciseName)
            else { continue }
            entry.exerciseTemplateID = id
            fixed += 1
        }

        return fixed
    }

    /// Bugfix (Geraetetest): Absicherung gegen ein von SwiftData nicht
    /// offiziell dokumentiertes, aber von mehreren Entwicklern berichtetes
    /// Lightweight-Migrations-Risiko: ein neu hinzugefuegtes Property mit
    /// Experession-Default (wie `ExerciseTemplate.id: UUID = UUID()`) MUSS
    /// nicht zwingend pro Bestandszeile einen eigenen, frischen Wert
    /// bekommen — einige Berichte zufolge kann die Migration denselben
    /// einen Default-Wert auf mehrere/alle migrierten Zeilen anwenden.
    /// Konnte aus dieser Session heraus nicht an echtem Apple-SwiftData
    /// verifiziert werden (kein Xcode-/Geraete-Zugriff) — diese Funktion
    /// behandelt es defensiv als moeglich, statt es zu unterstellen.
    ///
    /// Waere das tatsaechlich eingetreten, wuerden PR-/Verlaufs-Gruppierung
    /// (`PRDetector.GroupKey`, `PRHistoryView.TrophyGroupKey`), die rein
    /// nach dem `exerciseTemplateID`-WERT gruppieren, unterschiedliche
    /// Uebungen mit kollidierender ID faelschlich zusammenlegen — ein
    /// stiller Datenfehler, der ohne Gegenmassnahme nie auffallen wuerde.
    ///
    /// Erkennt JEDE `id`, die von 2+ verschiedenen `ExerciseTemplate`-
    /// Objekten geteilt wird (System UND Custom — betrifft beide Scopes
    /// gleichermassen), behaelt sie auf einem Objekt und vergibt den
    /// uebrigen je eine frische, garantiert neue `UUID()`. Laeuft VOR jeder
    /// Namens-Verknuepfung in `runIfNeeded`, damit eine Kollision nie an
    /// eine falsche Uebung durchgereicht wird.
    ///
    /// Kann bereits VOR diesem Fix fehlerhaft gesetzte `exerciseTemplateID`-
    /// Werte auf `Exercise`/`ExerciseLog`/`PersonalRecordEntry` nicht
    /// rueckwirkend heilen (die Zuordnung wurde ja schon getroffen, bevor
    /// die Vorlagen-ID hier korrigiert wird) — dafuer sorgt der separate
    /// Konsistenz-Check weiter unten in `runIfNeeded`.
    ///
    /// Idempotent: nach dem ersten Durchlauf ist jede `id` eindeutig, die
    /// Gruppierung findet dann nichts mehr.
    ///
    /// Returns: Anzahl der neu vergebenen IDs.
    @discardableResult
    public static func repairDuplicateTemplateIDsIfNeeded(in context: ModelContext) -> Int {
        let templates = (try? context.fetch(FetchDescriptor<ExerciseTemplate>())) ?? []
        guard templates.count > 1 else { return 0 }

        var byID: [UUID: [ExerciseTemplate]] = [:]
        for template in templates {
            byID[template.id, default: []].append(template)
        }

        var repaired = 0
        for group in byID.values where group.count > 1 {
            for duplicate in group.dropFirst() {
                duplicate.id = UUID()
                repaired += 1
            }
        }
        return repaired
    }
}
#endif
