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

        // 2) Build name-sets aus der Library, damit isTimeBased + isCompound
        //    (DEL-053) automatisch propagieren — der User kann sie spaeter im
        //    ExerciseEditor manuell anpassen.
        let timeBasedNames: Set<String> = Set(
            ExerciseLibraryData.all
                .filter { $0.isTimeBased }
                .map { $0.name }
        )
        let compoundNames: Set<String> = Set(
            ExerciseLibraryData.all
                .filter { $0.isSystemCompound }
                .map { $0.name }
        )

        // 3) Create new active plan. `isTemplate: false` (DEL-030) — Templates
        // dienen jetzt nur als Seed, der User-Plan ist eine voll editierbare
        // Tiefkopie. programType + descriptionText bleiben fuer interne
        // Recommendation-Logik gespeichert, sind aber nicht mehr im
        // PlanEditor-UI sichtbar (DEL-035).
        let plan = TrainingPlan(
            name: template.name,
            programType: template.id,
            descriptionText: template.tagline,
            weeks: 12,
            isActive: true,
            targetEnvironment: template.targetEnvironment,
            isTemplate: false
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
                    // DEL-053: Compound-Flag aus Library propagieren, damit
                    // die Smart-Progression dynamische RIR-Schwellen anwendet.
                    isCompound: compoundNames.contains(exerciseSpec.name),
                    // DEL-058: Cardio-Targets aus dem Spec mitnehmen, damit
                    // der CardioSetRow im Active-Workout die Placeholders
                    // korrekt zeigen kann.
                    targetDistanceKm: exerciseSpec.targetDistanceKm,
                    targetDurationMinutes: exerciseSpec.targetDurationMinutes,
                    day: day
                )
                context.insert(exercise)
            }
        }

        return plan
    }
}
#endif
