#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Materializes a `ProgramTemplate` (pure-data spec from Core) into a fully wired
/// `TrainingPlan` + `TrainingDay` + `Exercise` graph in SwiftData. Called from
/// `ProgramTemplatePickerView` when the user picks a template.
///
/// Side-effects:
///   1. Deactivates ALL existing TrainingPlans (`isActive = false`) — there can
///      always be only one active plan at a time.
///   2. Creates a new active `TrainingPlan` from the template metadata.
///   3. Creates `TrainingDay` rows for every `DaySpec`.
///   4. Creates `Exercise` rows for every `ExerciseSpec` inside each day, with
///      `orderIndex` set to the spec's position in the array. The
///      `isTimeBased` flag is auto-derived by name lookup against
///      `ExerciseLibraryData` — so library-flagged isometric exercises (Plank,
///      Wall Sit, Burpees, ...) propagate correctly without manual repeat-config.
@MainActor
public enum ProgramInstantiator {

    /// Returns the newly-created TrainingPlan so the caller can navigate to it.
    @discardableResult
    public static func instantiate(
        _ template: ProgramTemplate,
        in context: ModelContext
    ) -> TrainingPlan {
        // 1) Deactivate every existing plan.
        let allPlans = (try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        for plan in allPlans {
            plan.isActive = false
        }

        // 2) Build a name-set of time-based exercises from the seed library so
        //    the flag propagates to plan exercises automatically.
        let timeBasedNames: Set<String> = Set(
            ExerciseLibraryData.all
                .filter { $0.isTimeBased }
                .map { $0.name }
        )

        // 3) Create new active plan. `isTemplate: true` triggert die Read-
        // Only-Logik in den Editoren — User kann Trainings-Parameter (Pause,
        // RIR, Gewicht) anpassen, aber Name/Tage/Uebungs-Struktur sind locked.
        let plan = TrainingPlan(
            name: template.name,
            programType: template.id,
            descriptionText: template.tagline,
            weeks: 12,
            isActive: true,
            targetEnvironment: template.targetEnvironment,
            isTemplate: true
        )
        context.insert(plan)

        // 4) Materialize days + exercises.
        for daySpec in template.days {
            let day = TrainingDay(
                name: daySpec.name,
                weekday: daySpec.weekday,
                type: daySpec.type,
                plan: plan
            )
            context.insert(day)

            for (orderIndex, exerciseSpec) in daySpec.exercises.enumerated() {
                let exercise = Exercise(
                    name: exerciseSpec.name,
                    sets: exerciseSpec.sets,
                    repsMin: exerciseSpec.repsMin,
                    repsMax: exerciseSpec.repsMax,
                    restSeconds: exerciseSpec.restSeconds,
                    orderIndex: orderIndex,
                    targetRir: exerciseSpec.targetRir,
                    isCardio: exerciseSpec.isCardio,
                    isTimeBased: timeBasedNames.contains(exerciseSpec.name),
                    day: day
                )
                context.insert(exercise)
            }
        }

        return plan
    }
}
#endif
