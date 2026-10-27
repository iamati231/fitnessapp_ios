import Foundation

/// Recovers which of `PlanGenerator`'s two pace-bearing run zones (easy vs.
/// tempo) produced a saved exercise, by matching its stable anchor name.
///
/// A saved `Exercise`/`TrainingDayContentSnapshot.ExerciseEntry` never
/// persists which `RunZone` generated it, nor any pace value - the exercise
/// name (`PlanGenerator`'s private `RunZone.exerciseName`) is the only
/// surviving signal. No `.interval` case: interval days carry no pace, so
/// nothing downstream needs to distinguish them from any other non-match.
public enum CardioExerciseZone: Sendable, Equatable {
    case easy, tempo, other

    /// Matches against `PlanGenerator.RunZone.exerciseName`'s exact values.
    public static func forExerciseName(_ name: String) -> CardioExerciseZone {
        switch name {
        case "Easy Run": return .easy
        case "Long Run": return .tempo
        default: return .other
        }
    }
}
