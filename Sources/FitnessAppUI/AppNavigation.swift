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

    /// DEL-212, angepasst fuers Signature-Screen-Geruest (Nachtrag 6. August:
    /// "Werkzeuge"-Tab statt "Start"): NavigationPath des vierten Tabs
    /// (`CalculatorsView` als Wurzel). Erlaubt den Deep-Push aus der
    /// Wasser-Erinnerungs-Notification direkt bis zum WaterTracker, ohne den
    /// User nur auf dem Tab abzusetzen.
    public var toolsPath = NavigationPath()

    public init() {}

    /// Pop the workout stack to its root and switch to the dashboard. Used by
    /// `WorkoutSummaryView` after the user taps "Speichern & zum Dashboard".
    public func returnToDashboard() {
        workoutPath = NavigationPath()
        selectedTab = .dashboard
    }
}

/// DEL-212: Push-Route fuer den Wassertracker-Deep-Link. Der normale,
/// getippte Weg (Werkzeuge → Wassertracker) laeuft ueber eine gewoehnliche
/// `NavigationLink(destination:)`-Push in `CalculatorsView` und braucht
/// diesen Typ nicht — er existiert nur fuer den programmatischen
/// Ein-Tap-Sprung aus der lokalen Erinnerungs-Notification, aufgeloest
/// von der `navigationDestination(for:)`-Registrierung in RootView.
@available(iOS 17.0, macOS 14.0, *)
public enum CalculatorsRoute: Hashable, Sendable {
    case waterTracker
}

/// Fuenf Tabs (Signature-Screen-Geruest, Nachtrag 6. August: "der Start-Tab
/// weicht den Werkzeugen"): der vorherige `start`-Tab war die einzige
/// Tab-"Aktion" statt eines Ziels — dieselbe Aktion liegt bereits als
/// Hauptknopf auf dem Dashboard und als Banner in der Plan-Liste, ein
/// eigenes Tab-Symbol dafuer war redundant. Der frei gewordene Platz geht
/// an `tools` (Label "Werkzeuge", nicht "Rechner" — der Wassertracker misst
/// nur, rechnet nichts): `CalculatorsView` als eigene Tab-Wurzel mit
/// eigenem `NavigationStack`, statt eine Ebene tief unter "Mehr" zu haengen.
@available(iOS 17.0, macOS 14.0, *)
public enum AppTab: Hashable, Sendable {
    case dashboard
    case plan
    case measurement
    case tools
    case settings
}

// MARK: - DEL-076 Deep-Link Notifications

/// DEL-076: Notification-Bridge zwischen App-Layer-DeepLink-Handler und
/// dem RootView, das die `AppNavigation` haelt. Statt AppNavigation in
/// den App-Layer hochzuziehen, posten wir bei einem Live-Activity-Tap ein
/// NotificationCenter-Event und reagieren in RootView darauf.
///
/// Schema-Mapping:
///   * `fitnessapp://workout/active` → `.deltiqOpenActiveWorkout` — User
///     soll direkt in die laufende Session navigiert werden.
///   * `fitnessapp://dashboard` → `.deltiqOpenDashboard` — Tab-Swap auf
///     Dashboard.
public extension Notification.Name {
    static let deltiqOpenActiveWorkout = Notification.Name("Deltiq.openActiveWorkout")
    static let deltiqOpenDashboard     = Notification.Name("Deltiq.openDashboard")
}
#endif
