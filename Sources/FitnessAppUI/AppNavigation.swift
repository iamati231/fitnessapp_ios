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

    /// DEL-212, angepasst fuers Signature-Screen-Geruest (Variante 2b):
    /// NavigationPath des "Mehr"-Tabs. Rechner haengt seit dem Tab-Umbau
    /// (Abschnitt 1.11 des Handoffs) nicht mehr an einem eigenen Tab,
    /// sondern wird von `SettingsView` aus gepusht — dieser Pfad erlaubt
    /// weiterhin den Deep-Push aus der Wasser-Erinnerungs-Notification
    /// direkt bis zum WaterTracker, statt den User nur auf "Mehr" abzusetzen.
    public var morePath = NavigationPath()

    public init() {}

    /// Pop the workout stack to its root and switch to the dashboard. Used by
    /// `WorkoutSummaryView` after the user taps "Speichern & zum Dashboard".
    public func returnToDashboard() {
        workoutPath = NavigationPath()
        selectedTab = .dashboard
    }
}

#if canImport(SwiftData)
import SwiftData
import FitnessAppCore
import FitnessAppData

@available(iOS 17.0, macOS 14.0, *)
public extension AppNavigation {
    /// Startet die naechste faellige Trainingseinheit des aktiven Plans oder
    /// setzt eine bereits offene Session fort. Absichtlich einfacher als
    /// Dashboards `activeWorkoutButton`: kein Comeback-Prompt (DEL-239) und
    /// kein Konfliktdialog fuer eine zweite offene Session auf einem anderen
    /// Tag — beides haengt an View-lokalem State in `DashboardView`, den
    /// dieser globale Kurzbefehl nicht dupliziert. Sind mehrere Sessions
    /// offen, wird die zuletzt gestartete fortgesetzt.
    ///
    /// Lebt hier statt in `MainTabView`, damit JEDER Tab-Root-View (der den
    /// zentralen Aktionsknopf per `DeltiqCentralActionButton` selbst
    /// zeichnet, siehe Theme.swift) dieselbe Logik aufrufen kann, ohne sie
    /// zu duplizieren.
    func startOrResumeWorkout(modelContext: ModelContext) {
        var openDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == false && $0.isRestDay == false },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        openDescriptor.fetchLimit = 1
        if let open = try? modelContext.fetch(openDescriptor).first {
            workoutPath = NavigationPath()
            if let day = open.day, let plan = day.plan {
                workoutPath.append(plan)
                workoutPath.append(day)
            }
            workoutPath.append(ActiveSessionRoute(session: open))
            selectedTab = .plan
            return
        }

        let planDescriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let plan = try? modelContext.fetch(planDescriptor).first, !plan.days.isEmpty else {
            // Kein aktiver Plan: Plan-Tab zeigen, dort greift der Leerzustand.
            selectedTab = .plan
            return
        }

        let sortedDays = PlanNavigator.sortByWeekdayMondayFirst(plan.days)
        let completedDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true }
        )
        let completedCount = ((try? modelContext.fetch(completedDescriptor)) ?? []).filter {
            $0.day?.plan?.persistentModelID == plan.persistentModelID
        }.count
        let idx = PlanNavigator.nextScheduledIndex(
            dayCount: sortedDays.count,
            completedSessions: completedCount
        ) ?? 0
        let day = sortedDays[idx]

        guard !day.activeExercises.isEmpty else {
            selectedTab = .plan
            return
        }

        let session = WorkoutSession(
            startTime: Date(),
            endTime: Date(),
            durationMinutes: 0,
            exerciseCount: day.activeExercises.count,
            isCompleted: false,
            dayName: day.name,
            day: day
        )
        modelContext.insert(session)

        workoutPath = NavigationPath()
        workoutPath.append(plan)
        workoutPath.append(day)
        workoutPath.append(ActiveSessionRoute(session: session))
        selectedTab = .plan
    }
}
#endif

/// DEL-212: Push-Route fuer den Wassertracker-Deep-Link. Der normale,
/// getippte Weg (Mehr → Rechner → Wassertracker) laeuft ueber gewoehnliche
/// `NavigationLink(destination:)`-Pushes in `CalculatorsView` und braucht
/// diesen Typ nicht — er existiert nur fuer den programmatischen
/// Ein-Tap-Sprung aus der lokalen Erinnerungs-Notification, aufgeloest
/// von der `navigationDestination(for:)`-Registrierung in RootView.
@available(iOS 17.0, macOS 14.0, *)
public enum CalculatorsRoute: Hashable, Sendable {
    case waterTracker
}

/// Reale, sichtbare Tabs sind `dashboard`, `plan`, `measurement` und
/// `settings` ("Mehr"). `actionButton` traegt keinen Inhalt — es ist nur das
/// Tag des leeren Platzhalter-Tabs, der dem zentralen Aktionsknopf
/// (Signature-Geruest, Abschnitt 1.11) in der Tab-Leiste visuell Platz
/// schafft. Der Knopf selbst wird NICHT von `MainTabView` gezeichnet
/// (fruehere Version schwebte dadurch ueber jedem gepushten Screen und der
/// Tastatur) — jeder der vier echten Tab-Root-Views zeichnet ihn per
/// `DeltiqCentralActionButton`-Overlay selbst, siehe Theme.swift. Rechner
/// hat mit dem Tab-Umbau seinen eigenen Tab verloren und haengt jetzt
/// unter "Mehr".
@available(iOS 17.0, macOS 14.0, *)
public enum AppTab: Hashable, Sendable {
    case dashboard
    case plan
    case actionButton
    case measurement
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
