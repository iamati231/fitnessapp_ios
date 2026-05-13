#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Result-Tuple eines Environment-Swap-Laufs. UI nutzt die drei Zahlen fuer den
/// Toast/Confirmation-Output ("3 ersetzt · 1 ohne Alternative · 2 unveraendert").
public struct PlanEnvironmentSwapResult: Equatable, Sendable {
    public let swapped: Int
    public let kept: Int
    public let compatible: Int
    public let restored: Int   // DEL-049: re-aktivierte Originale aus Urlaubs-Modus

    public init(
        swapped: Int = 0,
        kept: Int = 0,
        compatible: Int = 0,
        restored: Int = 0
    ) {
        self.swapped = swapped
        self.kept = kept
        self.compatible = compatible
        self.restored = restored
    }

    /// Summe ueber alle Plaene — handy fuers Multi-Plan-Aggregat in DEL-047/049.
    public static func + (lhs: Self, rhs: Self) -> Self {
        .init(
            swapped:    lhs.swapped + rhs.swapped,
            kept:       lhs.kept + rhs.kept,
            compatible: lhs.compatible + rhs.compatible,
            restored:   lhs.restored + rhs.restored
        )
    }

    /// True wenn ueberhaupt etwas passiert ist (mind. ein Swap, Keep oder Restore).
    /// Alles-compatible darf der Toast schweigend ignorieren.
    public var hadAnyChange: Bool { swapped > 0 || kept > 0 || restored > 0 }
}

/// Zentrale Logik, um die Uebungen eines `TrainingPlan` auf ein neues
/// `EnvironmentType` umzuschreiben — mit Archive-statt-Delete-Semantik (DEL-049).
///
/// **Warum eigener Service?** Vorher lebte die Swap-Logik inline in
/// `PlanEditorView` (DEL-022). Mit DEL-047 (Profile-Sync → alle Plaene),
/// DEL-048 (Bottom-Up Konflikt) und DEL-049 (Urlaubs-Modus mit Restore)
/// brauchen wir den exakt gleichen Algorithmus von mehreren Stellen aus →
/// Refactor zur freistehenden Funktion.
///
/// **Archive statt Delete (DEL-049):**
/// Vor DEL-049 wurde die alte Uebung beim Swap via `modelContext.delete()`
/// hart entfernt — und cascade-loeschte ihre `ExerciseLog`-Historie gleich
/// mit. Das war fuer den "Urlaubs-Modus"-Workflow inakzeptabel: User wechselt
/// kurz zu BW und verliert dauerhaft seine Gym-Bestleistungen.
///
/// Stattdessen markieren wir die alte Uebung jetzt mit `isArchived = true`
/// und setzen auf der neuen Ersatz-Uebung `swappedFromOriginal` auf die
/// archivierte Original-Instanz. `TrainingDay.activeExercises` filtert
/// archivierte Eintraege aus der UI. Beim Rueckweg ("Profil zurueck auf
/// Gym") laeuft `restoreOriginals(...)` und reaktiviert sie.
///
/// Algorithmus pro Uebung in `migrate(...)`:
///   * `.stayCompatible`: Uebung ist nativ im neuen Env nutzbar → kein Swap.
///   * `.swap(spec)`: Alte Uebung → `isArchived = true`. Neue Ersatz-Uebung
///     bekommt `swappedFromOriginal = old`. orderIndex wird vom alten
///     uebernommen, sodass die Anzeige-Reihenfolge gleich bleibt.
///   * `.keep`: Kein Mapping → Uebung bleibt aktiv und unveraendert.
public enum PlanEnvironmentMigrator {

    /// Wendet die Migration auf EINEN Plan an und liefert die Counts zurueck.
    /// `plan.targetEnvironment` wird NICHT modifiziert — der Caller (UI)
    /// hat das in der Regel bereits gesetzt, bevor er hier landet.
    ///
    /// DEL-049: Wenn fuer eine Original-Uebung bereits eine *aktive*
    /// Ersatz-Variante existiert (z.B. Doppel-Swap Gym→Home→Gym ist
    /// inzwischen wieder Gym), wird das im Algorithmus toleriert — wir
    /// archivieren nur Uebungen, die im neuen Env NICHT kompatibel sind.
    public static func migrate(
        plan: TrainingPlan,
        toEnvironment newEnv: EnvironmentType,
        modelContext: ModelContext
    ) -> PlanEnvironmentSwapResult {
        var swapped = 0
        var kept = 0
        var compatible = 0

        for day in plan.days {
            // Snapshot der AKTIVEN Uebungen (archivierte rueckwirkend zu
            // beruehren waere boese — die sind absichtlich aus dem aktiven
            // Slot raus).
            let snapshot = day.activeExercises.sorted { $0.orderIndex < $1.orderIndex }
            for exercise in snapshot {
                switch ExerciseLibraryData.resolveAlternative(
                    forExerciseName: exercise.name,
                    targetEnvironment: newEnv
                ) {
                case .swap(let altSpec):
                    // DEL-049 ARCHIVE: alte Uebung NICHT loeschen, sondern
                    // zur Seite legen. Logs bleiben dran. Order-Index der
                    // alten Uebung wandert auf die neue, damit die Anzeige-
                    // Reihenfolge konsistent bleibt.
                    let originalOrderIndex = exercise.orderIndex
                    exercise.isArchived = true

                    let newExercise = Exercise(
                        name: altSpec.name,
                        sets: exercise.sets,
                        repsMin: exercise.repsMin,
                        repsMax: exercise.repsMax,
                        restSeconds: exercise.restSeconds,
                        notes: exercise.notes,
                        suggestedWeight: nil,   // andere Uebung → Last neu kalibrieren
                        orderIndex: originalOrderIndex,
                        targetRir: exercise.targetRir,
                        weightReducedNote: exercise.weightReducedNote,
                        // ExerciseTemplateSpec hat (noch) kein isCardio-Flag —
                        // unsere Alternative-Mappings sind alle Strength-Lifts,
                        // also hardcode false. Wenn das Mapping spaeter Cardio-
                        // Substitutes bekommt, hier Detection via Name oder
                        // dedicated Spec-Feld nachruesten.
                        isCardio: false,
                        isTimeBased: altSpec.isTimeBased,
                        isArchived: false,
                        swappedFromOriginal: exercise,
                        day: day
                    )
                    modelContext.insert(newExercise)
                    swapped += 1
                case .keep:
                    kept += 1
                case .stayCompatible:
                    compatible += 1
                }
            }
        }

        return PlanEnvironmentSwapResult(
            swapped: swapped, kept: kept, compatible: compatible
        )
    }

    /// Bulk-Variante fuer DEL-047 (Profil-Change → alle Plaene anpassen).
    /// Setzt `plan.targetEnvironment` auf den neuen Wert UND fuehrt die
    /// Migration durch. Aggregiert die Counts ueber alle Plaene und meldet,
    /// wie viele Plaene tatsaechlich beruehrt wurden.
    @discardableResult
    public static func migrateAll(
        plans: [TrainingPlan],
        toEnvironment newEnv: EnvironmentType,
        modelContext: ModelContext
    ) -> (plansTouched: Int, result: PlanEnvironmentSwapResult) {
        var aggregate = PlanEnvironmentSwapResult()
        var touched = 0
        for plan in plans {
            // Nicht-leere Plaene zaehlen — leere haben nichts zu migrieren.
            guard plan.days.contains(where: { !$0.activeExercises.isEmpty }) else {
                plan.targetEnvironment = newEnv
                continue
            }
            plan.targetEnvironment = newEnv
            let r = migrate(plan: plan, toEnvironment: newEnv, modelContext: modelContext)
            aggregate = aggregate + r
            touched += 1
        }
        return (touched, aggregate)
    }

    // MARK: - DEL-049 Restore

    /// DEL-049: Iteriert ueber alle aktiven Uebungen in `plan.days` und
    /// reaktiviert jene Originale (`swappedFromOriginal`), deren Equipment
    /// im neuen Env wieder kompatibel ist. Die Ersatz-Uebung wird hart
    /// geloescht (sie war ein Urlaubs-Modus-Provisorium; ihre Logs gehen
    /// per cascade mit weg — das ist OK, denn Urlaubs-BW-Logs wollte der
    /// User vermutlich nicht in der Gym-Bestleistung-Tabelle haben).
    ///
    /// Algorithmus pro Uebung:
    ///   * Nur aktive Uebungen (`!isArchived`) werden betrachtet.
    ///   * `swappedFromOriginal == nil` → skip (war kein Swap-Result).
    ///   * Original-Uebung im neuen Env inkompatibel → skip (Restore wuerde
    ///     ja sofort einen neuen Konflikt erzeugen).
    ///   * Sonst: original.isArchived = false, original.orderIndex = aktueller
    ///     orderIndex, current → modelContext.delete.
    @discardableResult
    public static func restoreOriginals(
        plan: TrainingPlan,
        toEnvironment newEnv: EnvironmentType,
        modelContext: ModelContext
    ) -> PlanEnvironmentSwapResult {
        var restored = 0
        for day in plan.days {
            // Snapshot — wir modifizieren day.exercises in der Iteration.
            let snapshot = day.activeExercises
            for current in snapshot {
                guard let original = current.swappedFromOriginal,
                      isOriginalCompatible(original, with: newEnv)
                else { continue }
                // Original wieder aktiv + an die Position der Ersatz-Uebung
                // ruecken (User-Reihenfolge bleibt stabil).
                original.isArchived = false
                original.orderIndex = current.orderIndex
                // Loop-Cleanup: falls die Ersatz-Uebung selber ein Original
                // hatte (Doppel-Swap), dranleihen — sonst dangling.
                // (In der Praxis sollte chains nicht auftauchen, weil wir
                // beim Swap die archived-Originale skipen.)
                modelContext.delete(current)
                restored += 1
            }
        }
        return PlanEnvironmentSwapResult(restored: restored)
    }

    /// Bulk-Restore fuer DEL-047/049: setzt `plan.targetEnvironment` UND
    /// restored fuer alle Plaene das Original-Setup.
    @discardableResult
    public static func restoreAll(
        plans: [TrainingPlan],
        toEnvironment newEnv: EnvironmentType,
        modelContext: ModelContext
    ) -> (plansTouched: Int, result: PlanEnvironmentSwapResult) {
        var aggregate = PlanEnvironmentSwapResult()
        var touched = 0
        for plan in plans {
            let beforeRestoreCount = plan.days.reduce(0) { $0 + $1.archivedExercises.count }
            plan.targetEnvironment = newEnv
            let r = restoreOriginals(plan: plan, toEnvironment: newEnv, modelContext: modelContext)
            aggregate = aggregate + r
            if r.restored > 0 || beforeRestoreCount > 0 {
                touched += 1
            }
        }
        return (touched, aggregate)
    }

    /// Schnell-Check: hat dieser Plan mindestens eine aktive Uebung mit einem
    /// `swappedFromOriginal`, dessen Original im neuen Env wieder kompatibel
    /// waere? Wird vom UI benutzt, um zwischen "anpassen?"- und
    /// "wiederherstellen?"-Prompt zu entscheiden.
    public static func hasRestorableOriginals(
        plan: TrainingPlan,
        forEnvironment env: EnvironmentType
    ) -> Bool {
        for day in plan.days {
            for current in day.activeExercises {
                guard let original = current.swappedFromOriginal else { continue }
                if isOriginalCompatible(original, with: env) {
                    return true
                }
            }
        }
        return false
    }

    /// Aggregat-Check ueber alle Plaene — fuer den Profil-Sync-Prompt
    /// (DEL-047+049).
    public static func hasAnyRestorableOriginals(
        plans: [TrainingPlan],
        forEnvironment env: EnvironmentType
    ) -> Bool {
        plans.contains { hasRestorableOriginals(plan: $0, forEnvironment: env) }
    }

    // MARK: - Helpers

    /// Looked up via Library, sodass wir das Equipment des Original-Eintrags
    /// kennen. Falls die Uebung nicht in der Library steht (Custom-Exercise),
    /// nehmen wir konservativ "nicht kompatibel" an — der User soll dann
    /// manuell entscheiden.
    private static func isOriginalCompatible(
        _ exercise: Exercise,
        with env: EnvironmentType
    ) -> Bool {
        guard let spec = ExerciseLibraryData.all.first(where: { $0.name == exercise.name }) else {
            return false
        }
        return ExerciseLibraryData.isEquipment(spec.equipment, compatibleWith: env)
    }
}
#endif
