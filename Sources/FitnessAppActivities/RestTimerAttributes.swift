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
    ///
    /// **`prMessage`** is the post-finish celebration: when the user ends a workout
    /// with at least one PR, we push a final state with this set, replacing the
    /// timer surface with a trophy headline like "🏆 100 kg Bankdruecken". The
    /// activity dismisses itself ~8s later via `.after(...)` policy.
    public struct ContentState: Codable, Hashable {
        public let endDate: Date
        public let originalSeconds: Int
        public let isFinished: Bool
        public let prMessage: String?

        public init(
            endDate: Date,
            originalSeconds: Int,
            isFinished: Bool = false,
            prMessage: String? = nil
        ) {
            self.endDate = endDate
            self.originalSeconds = originalSeconds
            self.isFinished = isFinished
            self.prMessage = prMessage
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
