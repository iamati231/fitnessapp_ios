import Foundation

/// One training day inside a `ProgramTemplate`. Weekday uses Foundation's `Calendar`
/// convention (1 = Sunday, 2 = Monday, ..., 7 = Saturday) — same as
/// `TrainingDay.weekday` in `FitnessAppData`. The Android source uses 1 = Monday,
/// so weekday integers are converted at port time, not at runtime.
public struct DaySpec: Sendable, Hashable {
    public let name: String
    public let type: DayType
    /// Calendar convention: 1 = Sunday, 2 = Monday, ..., 7 = Saturday.
    public let weekday: Int
    public let exercises: [ExerciseSpec]

    public init(name: String, type: DayType, weekday: Int, exercises: [ExerciseSpec]) {
        self.name = name
        self.type = type
        self.weekday = weekday
        self.exercises = exercises
    }
}
