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
                isTimeBased: spec.isTimeBased,
                // DEL-080: Cardio-Flag aus Spec propagieren, sodass Ad-Hoc-
                // Cardio-Einheiten (Freier Lauf, Radfahren, ...) korrekt
                // klassifiziert in den Picker landen.
                isCardio: spec.isCardio,
                // DEL-098: Belastungsfaktoren aus der Spec uebernehmen,
                // sodass der spaetere Recovery-Score schon vom ersten
                // Workout an mit sinnvollen Werten rechnen kann.
                systemicFatigueFactor: spec.systemicFatigueFactor,
                localMuscleDamageFactor: spec.localMuscleDamageFactor,
                cnsDemandFactor: spec.cnsDemandFactor,
                axialLoadFactor: spec.axialLoadFactor,
                technicalComplexityFactor: spec.technicalComplexityFactor,
                recoveryClass: spec.recoveryClass,
                // DEL-111: i18n-Lookup-Key + isSystemProvided-Flag.
                // Beide propagieren aus der Spec — Library-Eintraege
                // mit annotiertem Key bekommen multilinguale Anzeige,
                // alle anderen fallen auf das deutsche `name` zurueck.
                localizationKey: spec.localizationKey,
                isSystemProvided: true
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

    /// DEL-123: One-Shot-Backfill der `localizationKey`-Felder auf vorhandenen
    /// `TrainingPlan` + `TrainingDay`-Eintraegen. Pre-DEL-123-Daten haben den
    /// Key nicht — die Plan-Listen zeigen deutsche Strings im EN/TR-Modus.
    ///
    /// Strategie: konservatives Matching ueber `plan.programType` -> Template-
    /// Lookup. Nur wenn `plan.name` noch exakt der Template-DE-Name ist
    /// (also der User den Plan NICHT manuell umbenannt hat), schreiben wir
    /// den `localizationKey` rein. User-Custom-Renamen bleiben unangetastet
    /// und rendern weiter den User-getippten String.
    ///
    /// Day-Level: das gleiche Muster ueber `day.name == daySpec.name`. Rest-
    /// Tage (type == .rest mit Auto-Erzeugung) bekommen pauschal
    /// `day.restDay.title` falls sie noch den deutschen Default tragen.
    ///
    /// Idempotent: ueberspringt alle Plaene + Tage, die bereits einen Key
    /// tragen. Bei einem Cold-Start nach der ersten erfolgreichen Migration
    /// laeuft die Funktion praktisch leer durch.
    ///
    /// Returns: Anzahl der gesetzten Plan-Keys (Day-Updates implizit).
    @discardableResult
    public static func backfillPlanLocalizationKeysIfNeeded(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.localizationKey == nil }
        )
        let pending = (try? context.fetch(descriptor)) ?? []
        guard !pending.isEmpty else { return 0 }

        // Templates per programType-ID indexieren — O(1)-Lookup fuer den
        // typischen Fall (geadoptierte System-Templates).
        let templatesByID = Dictionary(
            uniqueKeysWithValues: ProgramTemplates.all.map { ($0.id, $0) }
        )

        var updated = 0
        for plan in pending {
            guard let template = templatesByID[plan.programType] else {
                continue   // Custom-Plan ohne Template-Origin — Skip
            }
            // Konservatives Match: nur wenn der User den Plan-Namen NICHT
            // veraendert hat, propagieren wir den localizationKey.
            // Custom-Rename ist erkennbar daran, dass plan.name vom
            // Template-Default abweicht.
            guard plan.name == template.name else { continue }
            plan.localizationKey = template.localizationKey
            updated += 1

            // DaySpec-Index aufbauen und Tag-Namen matchen
            let daySpecsByName = Dictionary(
                uniqueKeysWithValues: template.days.map { ($0.name, $0) }
            )
            for day in plan.days where day.localizationKey == nil {
                if day.type == .rest && day.name == "Ruhetag" {
                    day.localizationKey = "day.restDay.title"
                } else if let spec = daySpecsByName[day.name] {
                    day.localizationKey = spec.localizationKey
                }
            }
        }
        return updated
    }
}
#endif
