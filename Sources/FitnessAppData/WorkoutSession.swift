#if canImport(SwiftData)
import Foundation
import SwiftData

/// One persisted workout session.
///
/// A row is created at workout *start* with `isCompleted=false` and `durationMinutes=0` (F63).
/// The final "Save" on the Summary screen does an UPDATE that fills stats and flips
/// `isCompleted=true`. Rows with `isCompleted=false` are surfaced as crash-recovery
/// banners on the Home screen (F72).
@Model
public final class WorkoutSession {
    public var startTime: Date
    public var endTime: Date
    public var durationMinutes: Int
    public var exerciseCount: Int
    public var totalSets: Int
    public var totalVolumeKg: Double
    public var notes: String?
    public var isCompleted: Bool

    /// Snapshotted day name at session start — keeps history readable even after
    /// the source `TrainingDay` is renamed or deleted (F123 Bug #2).
    public var dayName: String?

    @Relationship(deleteRule: .nullify)
    public var day: TrainingDay?

    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.session)
    public var logs: [ExerciseLog] = []

    public init(
        startTime: Date = Date(),
        endTime: Date = Date(),
        durationMinutes: Int = 0,
        exerciseCount: Int = 0,
        totalSets: Int = 0,
        totalVolumeKg: Double = 0.0,
        notes: String? = nil,
        isCompleted: Bool = false,
        dayName: String? = nil,
        day: TrainingDay? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.exerciseCount = exerciseCount
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
        self.notes = notes
        self.isCompleted = isCompleted
        self.dayName = dayName
        self.day = day
    }
}
#endif
