import Foundation

/// Pure-data view of a single attempted set, decoupled from `ExerciseLog`
/// (SwiftData @Model). The view layer projects logs into this type before
/// passing them to `PRDetector`, keeping the algorithm Core-pure and testable
/// on every platform.
public struct LiftAttempt: Sendable, Hashable {
    public let exerciseName: String
    public let weightKg: Double
    public let reps: Int
    public let date: Date
    public let isCardio: Bool
    public let isTimeBased: Bool

    public init(
        exerciseName: String,
        weightKg: Double,
        reps: Int,
        date: Date,
        isCardio: Bool = false,
        isTimeBased: Bool = false
    ) {
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.reps = reps
        self.date = date
        self.isCardio = isCardio
        self.isTimeBased = isTimeBased
    }
}
