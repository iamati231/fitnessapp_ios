#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData

/// DEL-149: One-Shot-Migration die persistierte Uebungs-Namen auf den
/// deutschen Library-Base umschreibt.
///
/// **Problem-Geschichte:** Vor DEL-149 schrieb der Picker-Adopt-Pfad in
/// `DayEditorView.addExercise` und `ActiveWorkoutView.addAdHocExercise`
/// `template.displayName` (locale-resolved) in `Exercise.name`. Damit
/// landeten z.B. "Koşu Bandı" (TR), "Treadmill" (EN) statt des stabilen
/// DE-Base "Laufband" in der DB. Folgeeffekt: nach Sprachwechsel rendert
/// die UI weiterhin den eingefrorenen Fremdsprach-String, weil der
/// Library-Lookup ueber `name == entry.name` nichts findet.
///
/// **Was diese Migration tut:** Iteriert die drei Tables mit persistierten
/// Uebungs-Namen und schreibt jeden Eintrag, dessen Name in irgendeiner
/// unterstuetzten Locale einer Library-Uebung entspricht, auf den DE-Base
/// um:
///   1. `Exercise.name` (Plan/Workout-Day-Side)
///   2. `ExerciseLog.exerciseNameSnapshot` (DEL-051 Orphan-Resilience-Field)
///   3. `PersonalRecordEntry.exerciseName` (Trophy-Room)
///
/// **DEL-125-customName-Cleanup:** Wenn ein vorheriger Backfill-Run
/// (`LibrarySeeder.backfillCustomNamesIfNeeded`) den Fremdsprach-Namen
/// versehentlich als "User-Custom" promotet hat (weil er nicht in der
/// DE-Library matched), wird dieser `customName`-Wert hier wieder entfernt —
/// der Eintrag ist KEINE Custom-Uebung, nur ein Lokalisierungs-Mismatch.
///
/// **Idempotent:** Skipped Eintraege, deren Name bereits in der DE-Library
/// matched (Fast-Path-Set). Bei Cold-Start nach erfolgreichem ersten Pass
/// laeuft die Funktion praktisch leer durch.
@MainActor
public enum ExerciseNameBackfill {

    /// Fuehrt den Backfill aus. Returns die Anzahl der angepassten Eintraege
    /// (Summe ueber alle drei Tables) — nuetzlich fuer Logging/Telemetry.
    @discardableResult
    public static func runIfNeeded(in context: ModelContext) -> Int {
        let libraryNames = Set(ExerciseLibraryData.all.map(\.name))
        var fixed = 0

        // ─── 1) Exercises ────────────────────────────────────────────
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for ex in exercises {
            let original = ex.name
            // Fast-Path: Name ist bereits der DE-Base → nichts zu tun.
            guard !libraryNames.contains(original),
                  let baseName = ExerciseNameLookup.canonicalBaseName(forStoredName: original)
            else { continue }

            ex.name = baseName

            // DEL-125-Cleanup: backfillCustomNamesIfNeeded hat den Eintrag
            // ggf. faelschlich als Custom markiert, weil `name` damals nicht
            // im libraryNames-Set war. Jetzt wo der `name` repariert ist,
            // muss `customName` zurueck auf nil — sonst stiehlt der
            // displayName-Pfad weiterhin den alten Fremdsprach-String.
            if ex.customName == original {
                ex.customName = nil
            }

            fixed += 1
        }

        // ─── 2) ExerciseLog-Snapshots ────────────────────────────────
        let logs = (try? context.fetch(FetchDescriptor<ExerciseLog>())) ?? []
        for log in logs {
            guard let snap = log.exerciseNameSnapshot,
                  !libraryNames.contains(snap),
                  let baseName = ExerciseNameLookup.canonicalBaseName(forStoredName: snap)
            else { continue }
            log.exerciseNameSnapshot = baseName
            fixed += 1
        }

        // ─── 3) PersonalRecordEntry ──────────────────────────────────
        let prEntries = (try? context.fetch(FetchDescriptor<PersonalRecordEntry>())) ?? []
        for entry in prEntries {
            let original = entry.exerciseName
            guard !libraryNames.contains(original),
                  let baseName = ExerciseNameLookup.canonicalBaseName(forStoredName: original)
            else { continue }
            entry.exerciseName = baseName
            fixed += 1
        }

        return fixed
    }
}
#endif
