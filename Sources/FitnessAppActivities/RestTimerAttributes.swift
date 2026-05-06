#if os(iOS)
import Foundation
import ActivityKit

/// Live Activity attributes for the rest timer. Static fields are set when the
/// Activity is requested and never change for that lifetime; `ContentState` is the
/// dynamic part that gets `.update`-d as time elapses or the user skips ahead.
///
/// The widget extension target (added in Xcode, separate bundle) imports this
/// type from `FitnessAppActivities` and renders it via `ActivityConfiguration(for:)`.
public struct RestTimerAttributes: ActivityAttributes {

    /// Dynamic part — the only thing that changes during the activity's life.
    /// `endDate` lets the widget render a self-updating timer via `Text(timerInterval:)`
    /// without us pushing every second from the app side.
    public struct ContentState: Codable, Hashable {
        public let endDate: Date
        public let originalSeconds: Int
        public let isFinished: Bool

        public init(endDate: Date, originalSeconds: Int, isFinished: Bool = false) {
            self.endDate = endDate
            self.originalSeconds = originalSeconds
            self.isFinished = isFinished
        }
    }

    /// Static metadata — frozen at activity-start.
    public let exerciseName: String
    public let setNumber: Int
    public let totalSets: Int

    public init(exerciseName: String, setNumber: Int, totalSets: Int) {
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.totalSets = totalSets
    }
}
#endif
