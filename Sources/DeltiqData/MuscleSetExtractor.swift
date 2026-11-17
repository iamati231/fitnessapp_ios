#if canImport(SwiftData)
import Foundation
import SwiftData
import DeltiqCore

/// SwiftData-Glue zwischen echten `WorkoutSession`/`ExerciseLog`-Objekten
/// und dem reinen `MuscleGroupProgressCalculator` (DeltiqCore).
///
/// Liefert einen `MuscleLoggedSet` pro geloggtem Kraft-Satz; Cardio-Logs und
/// leere Platzhalter-Zeilen werden ausgeschlossen.
/// Muscle-Group: `exercise?.primaryMuscle` live-first, Fallback auf das
/// Template via `exercise?.primaryMuscleRaw`-Snapshot-Kette — wenn beides
/// fehlt, bleibt `muscleGroup == nil` (kein Crash, Caller kennzeichnet als
/// „nicht zugeordnet").
public enum MuscleSetExtractor {

    public static func extract(from sessions: [WorkoutSession]) -> [MuscleGroupProgressCalculator.MuscleLoggedSet] {
        sessions
            .filter(\.isRealWorkout)
            .flatMap { session in
                session.loggedSets
                    .filter { !$0.resolvedIsCardio }
                    .compactMap { log -> MuscleGroupProgressCalculator.MuscleLoggedSet? in
                        guard let name = log.resolvedExerciseName, !name.isEmpty else { return nil }
                        // Live-ref first; falls back to raw snapshot if live ref was nullified.
                        let muscle: MuscleGroup? = log.exercise?.primaryMuscle
                            ?? log.exercise.flatMap { MuscleGroup(rawValue: $0.primaryMuscleRaw ?? "") }
                        return .init(
                            date: log.date,
                            exerciseName: name,
                            muscleGroup: muscle,
                            isCardio: false
                        )
                    }
            }
    }
}
#endif
