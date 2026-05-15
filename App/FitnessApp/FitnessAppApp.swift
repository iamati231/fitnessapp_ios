import SwiftUI
import SwiftData
import FitnessAppUI
import FitnessAppData
import FitnessAppActivities

/// App entry point. Three responsibilities only:
///   1. Hand SwiftData a list of @Model types via `AppSchema.types` (single source
///      of truth in FitnessAppData — adding new models doesn't require changes here).
///   2. Render `RootView` from FitnessAppUI, which handles the Onboarding/MainTabView
///      switch internally and provides AppNavigation/HealthKit/RestTimer-Activity
///      controllers via the environment.
///   3. Forward incoming deep-links (e.g., taps on the Live Activity) to the app.
@main
struct FitnessAppApp: App {

    /// Adapter haengt den AppDelegate in den SwiftUI-App-Lifecycle. Wichtig
    /// fuer den UNUserNotificationCenterDelegate-Setup, der COLD-START-safe
    /// sein muss (siehe Kommentare in AppDelegate.swift).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                // DEL-045-Update Punkt 2: App-weite Akzentfarbe. Alle nativen
                // SwiftUI-Komponenten (Buttons, Toggles, Slider, NavigationLink-
                // Chevrons, TabView-Selection, Progress-Indikatoren) erben den
                // Tint automatisch — kein Per-View-Tinting mehr noetig.
                .tint(Color.deltiqOrange)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(for: AppSchema.types)
    }

    /// DEL-076: Custom-scheme-Handler routet jetzt via NotificationCenter-
    /// Bridge in den RootView (der `AppNavigation` haelt) — wir vermeiden
    /// den invasiveren Refactor "AppNavigation ins App-Layer hochziehen".
    ///
    /// Zwei Routes:
    ///   * `fitnessapp://workout/active` → `.deltiqOpenActiveWorkout`
    ///     RootView swappt zum Plan-Tab UND pusht die noch laufende
    ///     (`isCompleted == false`) Session auf den workoutPath.
    ///   * `fitnessapp://dashboard` → `.deltiqOpenDashboard`
    ///     RootView swappt zum Dashboard-Tab.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == FitnessAppDeepLink.scheme else { return }
        #if DEBUG
        print("FitnessApp deep-link received: \(url.absoluteString)")
        #endif

        // Pfad-Komponenten extrahieren. `host` traegt "workout"/"dashboard",
        // `path` ggf. "/active".
        let host = url.host ?? ""
        let path = url.path
        switch (host, path) {
        case ("workout", "/active"):
            NotificationCenter.default.post(name: .deltiqOpenActiveWorkout, object: nil)
        case ("dashboard", _):
            NotificationCenter.default.post(name: .deltiqOpenDashboard, object: nil)
        default:
            break
        }
    }
}
