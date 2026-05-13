#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Seeds the `ExerciseTemplate` library with the canonical entries from
/// `ExerciseLibraryData`. Idempotent: skips if any template already exists.
///
/// Called from `RootView.task` on every app launch (cheap — one fetch-count
/// query). New users get the full library on first start; existing users with
/// hand-added custom templates aren't disturbed.
@MainActor
public enum LibrarySeeder {

    /// Returns true if the library was actually seeded (was empty before),
    /// false if it was already populated.
    @discardableResult
    public static func seedIfNeeded(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<ExerciseTemplate>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return false }

        for spec in ExerciseLibraryData.all {
            let template = ExerciseTemplate(
                name: spec.name,
                equipment: spec.equipment,
                primaryMuscle: spec.primaryMuscle,
                isCustom: false,
                difficultyLevel: spec.difficultyLevel,
                isSystemCompound: spec.isSystemCompound,
                isTimeBased: spec.isTimeBased
            )
            context.insert(template)
        }
        return true
    }

    /// DEL-051: One-Shot-Backfill der Snapshot-Felder auf vorhandenen
    /// `ExerciseLog`-Eintraegen. Bestand aus den Pre-DEL-051-Versionen hat
    /// `exerciseNameSnapshot == nil` — `resolvedExerciseName` fallback'ed
    /// zwar auf `log.exercise?.name`, aber sobald eine Plan-Uebung jemals
    /// geloescht/getauscht wird, sind die Logs ohne Live-Referenz orphan
    /// UND ohne Snapshot. Dieser Pass schreibt die Snapshots EINMALIG auf
    /// alle bestehenden Logs nach, solange die Exercise noch da ist.
    ///
    /// Idempotent: ueberspringt Logs, die bereits einen Snapshot tragen, und
    /// orphan-Logs ohne erreichbare Exercise. Wird einmal pro App-Launch
    /// aus `RootView.task` aufgerufen — cheap genug, der FetchDescriptor
    /// erlaubt einen Filter auf nil-Snapshot, sodass der Bulk-Run nach dem
    /// ersten erfolgreichen Backfill leer durchlaeuft.
    ///
    /// Returns: Anzahl der nachgezogenen Eintraege (fuer Logging/Telemetry).
    @discardableResult
    public static func backfillLogSnapshotsIfNeeded(in context: ModelContext) -> Int {
        let pendingDescriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate { $0.exerciseNameSnapshot == nil }
        )
        let pending = (try? context.fetch(pendingDescriptor)) ?? []
        var updated = 0
        for log in pending {
            guard let exercise = log.exercise else { continue }
            log.exerciseNameSnapshot       = exercise.name
            log.exerciseIsCardioSnapshot   = exercise.isCardio
            log.exerciseIsTimeBasedSnapshot = exercise.isTimeBased
            updated += 1
        }
        return updated
    }
}
#endif
