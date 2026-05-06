#if canImport(SwiftUI)
import SwiftUI

/// App-wide navigation state. One per `RootView` — passed through the environment so
/// any view can switch tabs or manipulate the workout-tab navigation stack without
/// awkward callback chains.
///
/// **Tab switching**: `selectedTab` drives the root `TabView`. Mutating it from
/// anywhere swaps the visible tab.
///
/// **Workout path**: `workoutPath` is the `NavigationPath` for the workout tab.
/// `ActiveWorkoutView` pushes `SummaryRoute` onto it after a finish; `WorkoutSummaryView`
/// clears it (and the tab selection) to return to Dashboard.
@available(iOS 17.0, macOS 14.0, *)
@Observable
public final class AppNavigation {
    public var selectedTab: AppTab = .dashboard
    public var workoutPath = NavigationPath()

    public init() {}

    /// Pop the workout stack to its root and switch to the dashboard. Used by
    /// `WorkoutSummaryView` after the user taps "Speichern & zum Dashboard".
    public func returnToDashboard() {
        workoutPath = NavigationPath()
        selectedTab = .dashboard
    }
}

@available(iOS 17.0, macOS 14.0, *)
public enum AppTab: Hashable, Sendable {
    case dashboard
    case plan
    case measurement
    case calculators
    case settings
}
#endif
