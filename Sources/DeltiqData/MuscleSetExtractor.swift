#if canImport(SwiftData)
import Foundation
import SwiftData
import DeltiqCore

/// SwiftData-Glue zwischen echten `WorkoutSession`/`ExerciseLog`-Objekten
/// und dem reinen `MuscleGroupProgressCalculator` (DeltiqCore).
///
/// Liefert einen `MuscleLoggedSet` pro Arbeitssatz (`.workingSet`-Rolle);
/// Cardio-Logs, Warmups, Cooldowns und leere Platzhalter-Zeilen werden
/// ausgeschlossen. Verwaiste Logs (exercise == nil) gelten konservativ als
/// Arbeitssätze und werden einbezogen.
/// Muscle-Group: (1) Exercise.primaryMuscle-Override (Custom), sonst
/// (2) ExerciseTemplate.primaryMuscle via resolvedExerciseTemplateID.
/// Wenn beides fehlt bleibt `muscleGroup == nil`.
public enum MuscleSetExtractor {

    /// - Parameters:
    ///   - sessions: Abgeschlossene Workout-Sessions.
    ///   - templates: Alle ExerciseTemplates – wird für den Muskel-Lookup
    ///     bei System-Übungen gebraucht, bei denen Exercise.primaryMuscle nil ist.
    public static func extract(
        from sessions: [WorkoutSession],
        templates: [ExerciseTemplate]
    ) -> [MuscleGroupProgressCalculator.MuscleLoggedSet] {
        let templateMap: [UUID: MuscleGroup] = Dictionary(
            templates.map { ($0.id, $0.primaryMuscle) },
            uniquingKeysWith: { first, _ in first }
        )
        return sessions
            .filter(\.isRealWorkout)
            .flatMap { session in
                session.loggedSets
                    .filter { !$0.resolvedIsCardio }
                    .compactMap { log -> MuscleGroupProgressCalculator.MuscleLoggedSet? in
                        guard let name = log.resolvedExerciseName, !name.isEmpty else { return nil }
                        // Skip warmup/cooldown; orphaned logs (exercise == nil) default to workingSet.
                        let isWorking = log.exercise.map { $0.role == .workingSet } ?? true
                        guard isWorking else { return nil }
                        // Muscle lookup: custom-exercise override → template catalog → nil
                        let muscle: MuscleGroup? = log.exercise?.primaryMuscle
                            ?? log.resolvedExerciseTemplateID.flatMap { templateMap[$0] }
                        return .init(
                            date: log.date,
                            exerciseName: name,
                            muscleGroup: muscle,
                            isCardio: false,
                            sessionTimestamp: session.startTime
                        )
                    }
            }
    }
}
#endif
