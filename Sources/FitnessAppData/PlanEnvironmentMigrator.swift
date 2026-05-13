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

    public init(swapped: Int = 0, kept: Int = 0, compatible: Int = 0) {
        self.swapped = swapped
        self.kept = kept
        self.compatible = compatible
    }

    /// Summe ueber alle Plaene — handy fuers Multi-Plan-Aggregat in DEL-047.
    public static func + (lhs: Self, rhs: Self) -> Self {
        .init(
            swapped:    lhs.swapped + rhs.swapped,
            kept:       lhs.kept + rhs.kept,
            compatible: lhs.compatible + rhs.compatible
        )
    }

    /// True wenn ueberhaupt etwas passiert ist (mind. ein Swap oder Keep).
    /// Alles-compatible darf der Toast schweigend ignorieren.
    public var hadAnyChange: Bool { swapped > 0 || kept > 0 }
}

/// Zentrale Logik, um die Uebungen eines `TrainingPlan` auf ein neues
/// `EnvironmentType` umzuschreiben.
///
/// **Warum eigener Service?** Vorher lebte die Swap-Logik inline in
/// `PlanEditorView` (DEL-022). Mit DEL-047 (Profile-Sync → alle Plaene) und
/// DEL-048 (Bottom-Up: User fuegt eine inkompatible Uebung hinzu → Plan-Env
/// koennte mit-umstellen) brauchen wir den exakt gleichen Algorithmus
/// von mehreren Stellen aus → Refactor zur freistehenden Funktion.
///
/// Algorithmus pro Uebung:
///   * `.stayCompatible`: Uebung ist nativ im neuen Env nutzbar (z.B. KH-
///     Bankdruecken in `.homeGym`) → kein Swap noetig, Zaehler `compatible++`.
///   * `.swap(spec)`: Uebung hat einen Alternativ-Eintrag im Mapping → wir
///     erstellen eine neue `Exercise` mit gleichem orderIndex und Sets/Reps/
///     Pause/Notes/RIR/TimeBased-Flag und loeschen die alte (sauberer
///     SwiftData-Lifecycle). `suggestedWeight` wird auf nil gesetzt — die
///     alte Last passt selten zur neuen Bewegung.
///   * `.keep`: Kein Mapping vorhanden → Uebung bleibt unveraendert, Zaehler
///     `kept++`. UI markiert sie spaeter mit Warn-Indikator.
public enum PlanEnvironmentMigrator {

    /// Wendet die Migration auf EINEN Plan an und liefert die Counts zurueck.
    /// `plan.targetEnvironment` wird NICHT modifiziert — der Caller (UI)
    /// hat das in der Regel bereits gesetzt, bevor er hier landet.
    public static func migrate(
        plan: TrainingPlan,
        toEnvironment newEnv: EnvironmentType,
        modelContext: ModelContext
    ) -> PlanEnvironmentSwapResult {
        var swapped = 0
        var kept = 0
        var compatible = 0

        for day in plan.days {
            let snapshot = day.exercises.sorted { $0.orderIndex < $1.orderIndex }
            for exercise in snapshot {
                switch ExerciseLibraryData.resolveAlternative(
                    forExerciseName: exercise.name,
                    targetEnvironment: newEnv
                ) {
                case .swap(let altSpec):
                    let newExercise = Exercise(
                        name: altSpec.name,
                        sets: exercise.sets,
                        repsMin: exercise.repsMin,
                        repsMax: exercise.repsMax,
                        restSeconds: exercise.restSeconds,
                        notes: exercise.notes,
                        suggestedWeight: nil,   // andere Uebung → Last neu kalibrieren
                        orderIndex: exercise.orderIndex,
                        targetRir: exercise.targetRir,
                        weightReducedNote: exercise.weightReducedNote,
                        // ExerciseTemplateSpec hat (noch) kein isCardio-Flag —
                        // unsere Alternative-Mappings sind alle Strength-Lifts,
                        // also hardcode false. Wenn das Mapping spaeter Cardio-
                        // Substitutes bekommt, hier Detection via Name oder
                        // dedicated Spec-Feld nachruesten.
                        isCardio: false,
                        isTimeBased: altSpec.isTimeBased,
                        day: day
                    )
                    modelContext.insert(newExercise)
                    modelContext.delete(exercise)
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
            guard plan.days.contains(where: { !$0.exercises.isEmpty }) else {
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
}
#endif
