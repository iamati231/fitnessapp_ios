#if canImport(SwiftUI)
import SwiftUI
import DeltiqCore
import DeltiqData

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

    /// DEL-212, main-navigation Plan Task 3 (2026-10-22): NavigationPath der
    /// Settings-("Mehr")-Tab-NavigationStack, unter der `CalculatorsView`
    /// jetzt eine Ebene tief haengt (statt einer eigenen Tab-Wurzel vor
    /// diesem Task). Erlaubt den Deep-Push aus der Wasser-Erinnerungs-
    /// Notification direkt bis zum WaterTracker, ohne den User nur auf dem
    /// Tab abzusetzen.
    public var toolsPath = NavigationPath()
    public var nutritionPath = NavigationPath()
    public var showingTour: Bool = false
    public var tourStartsFromInvitation: Bool = false
    public var scrollToTopTrigger: [AppTab: UUID] = [:]

    public init() {}

    public func triggerScrollToTop(for tab: AppTab) {
        scrollToTopTrigger[tab] = UUID()
    }

    /// Pop the workout stack to its root and switch to the dashboard. Used by
    /// `WorkoutSummaryView` after the user taps "Speichern & zum Dashboard".
    public func returnToDashboard() {
        workoutPath = NavigationPath()
        selectedTab = .dashboard
    }
}

/// Nav-Unification (2026-10-31): Push-Navigation fuer alle Nutrition-Screens.
/// `.planner` — MealPlannerView; `.goals` — NutritionGoalsView.
/// Phase 4.3 (2026-10-31): `.recipeDetail` — RecipeDetailView mit Portionsanpassung.
/// Phase 4.4 (2026-10-31): `date` mitgefuehrt fuer den Tagebucheintrag.
/// Phase 5.0 (2026-11-01): `.nutritionPreferences` — NutritionPreferencesView.
/// Phase 5.1 (2026-11-01): `.weekOverview` — WeekPlannerView; `.plannerDay` — MealPlannerView mit initialem Datum.
@available(iOS 17.0, macOS 14.0, *)
public enum MealPlannerRoute: Hashable, Sendable {
    case planner
    case weekOverview
    case plannerDay(Date)
    case goals
    case nutritionPreferences
    case recipeDetail(recipeID: String, mealType: MealType, portionMultiplier: Double, date: Date)
}

/// Issue #5 (2026-10-31): Push-Navigation fuer AddMealView aus NutritionDayView.
/// Folgt dem ActiveSessionRoute-Muster — kein Sendable, MealEntry direkt gespeichert.
@available(iOS 17.0, macOS 14.0, *)
public enum AddMealRoute: Hashable {
    case addMeal(date: Date, mealType: MealType)
    case editMeal(MealEntry)
}

/// DEL-212, main-navigation Plan Task 3 Fix-Runde 1 (2026-10-22): Wertbasierte
/// Pushes fuer den Teilpfad SettingsView → CalculatorsView → WaterTrackerView,
/// registriert als `navigationDestination(for: CalculatorsRoute.self)` auf
/// der Settings-NavigationStack in RootView (`toolsPath`). Sowohl der getippte
/// Weg (Mehr → Werkzeuge-Zeile → `.calculators` → Wassertracker-Zeile →
/// `.waterTracker`) als auch der programmatische Ein-Tap-Sprung aus der
/// Wasser-Erinnerungs-Notification (Reset + Append von `.waterTracker` direkt,
/// ohne `.calculators`) laufen ueber dieselbe Route-Maschinerie — bewusst KEIN
/// Mix aus wert- und view-basierten Pushes auf diesem Teilpfad mehr, damit ein
/// `toolsPath`-Reset zuverlaessig jeden vorherigen Navigationszustand aufraeumt,
/// bevor der Deep-Link seinen eigenen Push anhaengt.
@available(iOS 17.0, macOS 14.0, *)
public enum CalculatorsRoute: Hashable, Sendable {
    /// SettingsView → CalculatorsView (die "Werkzeuge"-Zeile unter "Mehr").
    case calculators
    /// CalculatorsView → WaterTrackerView, auch via Deep-Link direkt aus
    /// SettingsView erreichbar (Reset + alleiniges Append dieses Falls).
    case waterTracker
}

/// UI-Ticket ("Tab-Leiste vereinfachen", 2026-11-06): Fortschritt &
/// Messungen zieht vom entfallenen `AppTab.measurement`-Tab eine Ebene tief
/// unter "Mehr" (Settings) — analog zu `CalculatorsRoute`, dieselbe
/// Route-Maschinerie fuer Deep-Links (Erinnerungs-Notification UND
/// Dashboard-Trend-Empty-State landen jetzt hier statt auf einem eigenen
/// Tab). Eigener Enum statt eines dritten `CalculatorsRoute`-Falls — klarere
/// Trennung, "Calculators" passt semantisch nicht zu einer Fortschritts-
/// uebersicht, obwohl beide auf demselben `toolsPath` haengen.
@available(iOS 17.0, macOS 14.0, *)
public enum ProgressRoute: Hashable, Sendable {
    case overview
    case prHistory
    case workoutHistory
}

/// Vier Tabs (UI-Ticket "Tab-Leiste vereinfachen", 2026-11-06, loest den
/// Fuenf-Tab-Stand vom main-navigation Plan 2026-10-22 ab): Heute/Training/
/// Ernaehrung/Mehr. `measurement` ist entfallen — Koerpermessungen werden
/// seltener erfasst als die anderen Hauptbereiche und brauchen deshalb
/// keinen dauerhaft sichtbaren eigenen Tab mehr; `ProgressOverviewView`
/// haengt stattdessen eine Ebene tief unter "Mehr" (siehe `ProgressRoute`).
@available(iOS 17.0, macOS 14.0, *)
public enum AppTab: Hashable, Sendable {
    case dashboard
    case plan
    case nutrition
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
