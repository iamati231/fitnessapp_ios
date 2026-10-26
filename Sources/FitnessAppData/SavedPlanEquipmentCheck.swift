#if canImport(SwiftData)
import Foundation
import FitnessAppCore

/// Equipment-Vielfalt Phase 1 Task 4, fuenfte Review-Runde, Praezisierung 1:
/// ein gespeicherter `TrainingPlan`'s Equipment-Status ist NIRGENDS neu
/// herleitbar (kein Treffer fuer `PlanEquipmentChecker`/`PlanEquipmentStatus`
/// in `PlanEditorView`/`DashboardView`/`ExerciseDetailView`). Baut aus den
/// AKTUELLEN `activeExercises` eines Plans die minimale `[DaySpec]`-
/// Repraesentation, die das bestehende, unveraenderte
/// `PlanEquipmentChecker.fullReport(days:against:)` braucht (nur `name` wird
/// fuer den Katalog-Abgleich benoetigt), und ruft es unveraendert auf. Reine
/// Neuberechnung bei JEDEM Aufruf — kein gespeicherter Status, kein neues
/// Feld auf `TrainingPlan`/`TrainingDay`.
public enum SavedPlanEquipmentCheck {
    public static func report(for plan: TrainingPlan, against profile: UserEquipmentProfile) -> PlanEquipmentReport {
        let days = plan.days.enumerated().map { index, day in
            DaySpec(
                name: day.name,
                type: day.type,
                sequenceIndex: index + 1,
                exercises: day.activeExercises.map { exercise in
                    ExerciseSpec(name: exercise.name, sets: 1, repsMin: 1, repsMax: 1)
                }
            )
        }
        return PlanEquipmentChecker.fullReport(days: days, against: profile)
    }
}
#endif
