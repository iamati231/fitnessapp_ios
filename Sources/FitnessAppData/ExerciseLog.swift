#if canImport(SwiftData)
import Foundation
import SwiftData

@Model
public final class ExerciseLog {
    public var date: Date
    public var setIndex: Int
    public var weight: Double
    public var reps: Int
    public var rpe: Double
    public var rir: Float
    public var comment: String?

    public var exercise: Exercise?
    /// Nullify rather than cascade — sessions can be deleted without losing logs.
    public var session: WorkoutSession?

    public init(
        date: Date = Date(),
        setIndex: Int,
        weight: Double,
        reps: Int,
        rpe: Double = 0.0,
        rir: Float,
        comment: String? = nil,
        exercise: Exercise? = nil,
        session: WorkoutSession? = nil
    ) {
        self.date = date
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.rir = rir
        self.comment = comment
        self.exercise = exercise
        self.session = session
    }
}
#endif
