#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppData
import FitnessAppHealth
import FitnessAppActivities

/// App entry point. Reads the singleton `UserBodyProfile` via `@Query`; when none
/// exists yet, shows `OnboardingView` so the user can create one. Once SwiftData
/// fires the @Query update with the inserted profile, the view re-renders and we
/// drop into the main app — no manual navigation push needed.
///
/// Owns the singleton `AppNavigation` and provides it to the environment so any
/// child view can switch tabs / manipulate the workout-tab navigation stack.
@available(iOS 17.0, macOS 14.0, *)
public struct RootView: View {

    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserBodyProfile]

    @State private var navigation = AppNavigation()
    @State private var healthKit = HealthKitController()
    @State private var restTimerActivity = RestTimerActivityController()
    @State private var prNotifications = PRNotificationCenter()

    /// DEL-018: User-Praeferenz fuer Hell/Dunkel/System. Wird in SettingsView
    /// per Picker gesetzt und hier global via .preferredColorScheme() auf die
    /// ganze App angewandt. "system" → nil (folgt iOS-Einstellung).
    @AppStorage("pref_appearance") private var appearanceRaw: String = "system"

    public init() {}

    public var body: some View {
        Group {
            if profiles.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        // Crossfade when the @Query result flips from empty to non-empty (and vice
        // versa, e.g. after a Settings reset).
        .animation(.easeInOut(duration: 0.25), value: profiles.isEmpty)
        .environment(navigation)
        .environment(healthKit)
        .environment(restTimerActivity)
        .environment(prNotifications)
        .preferredColorScheme(preferredColorScheme)
        // DEL-076: Deep-Link-Bridge. App-Layer-Handler posted Notifications,
        // wir routen hier auf AppNavigation. `.onReceive` mit
        // `NotificationCenter.default.publisher(for:)` ist die kanonische
        // SwiftUI-Form fuer Foundation-Notifications.
        .onReceive(NotificationCenter.default.publisher(for: .deltiqOpenActiveWorkout)) { _ in
            handleOpenActiveWorkout()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deltiqOpenDashboard)) { _ in
            navigation.returnToDashboard()
        }
        .task {
            // Refresh per-launch availability for native integrations. Both checks
            // are cheap; both are no-ops when their frameworks aren't present.
            await healthKit.refreshAuthorizationStatus()
            restTimerActivity.refreshAvailability()
            await prNotifications.refreshAuthorizationStatus()

            // Seed the canonical exercise library on first launch (idempotent
            // — fetchCount short-circuits when rows already exist).
            LibrarySeeder.seedIfNeeded(in: modelContext)
            // DEL-051: Snapshot-Backfill fuer Pre-DEL-051-Logs. Idempotent —
            // FetchDescriptor filtert auf nil-Snapshot, also lauft das nach
            // dem ersten Erfolg leer durch.
            LibrarySeeder.backfillLogSnapshotsIfNeeded(in: modelContext)
            // DEL-123: localizationKey-Backfill fuer Pre-DEL-123 Plans + Days.
            // Idempotent — Predicate filtert auf nil-Key. User mit
            // Custom-renamen Plaenen bleibt unangetastet (Match-Check).
            LibrarySeeder.backfillPlanLocalizationKeysIfNeeded(in: modelContext)
            // DEL-125: customName-Backfill — User-renamte Eintraege werden
            // aus `name` nach `customName` migriert, damit die System-Name/
            // User-Name Trennung sauber wird. Idempotent.
            LibrarySeeder.backfillCustomNamesIfNeeded(in: modelContext)
        }
    }

    /// DEL-076: User hat in der Live-Activity getappt → wir wollen ihn in
    /// die laufende Session zurueck navigieren. Pfad:
    ///   1. Swap zur Plan-Tab (`selectedTab = .plan`).
    ///   2. Wenn eine offene Session existiert (`isCompleted == false`),
    ///      `ActiveSessionRoute` auf den workoutPath pushen — die
    ///      Navigation-Destination in WorkoutRootView nimmt von dort uebernommen.
    ///   3. Wenn keine offene Session da ist (z.B. App-Cold-Start aus alter
    ///      Live-Activity nach Crash), bleiben wir auf der Plan-Liste.
    private func handleOpenActiveWorkout() {
        navigation.selectedTab = .plan
        // Aktive Session pullen. Defensive: FetchDescriptor auf nicht-
        // completed, nicht-rest-day Sessions, neueste zuerst.
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == false && $0.isRestDay == false },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let session = try? modelContext.fetch(descriptor).first {
            // Pfad zuruecksetzen + Session pushen. Ohne Reset wuerde der
            // User bei nested-Plan-Editor-Screens landen.
            navigation.workoutPath = NavigationPath()
            navigation.workoutPath.append(ActiveSessionRoute(session: session))
        }
    }

    /// Mappt den AppStorage-String auf SwiftUI's ColorScheme?. `nil` =
    /// "System" (folgt iOS-Einstellung), `.light` = forciert hell,
    /// `.dark` = forciert dunkel.
    private var preferredColorScheme: ColorScheme? {
        switch appearanceRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

/// Top-level container for the post-onboarding flow. Tab order:
/// Dashboard (overview at app launch) → Plan (training) → Messung (daily entry)
/// → Rechner (utilities). Cross-tab navigation runs through `AppNavigation`.
@available(iOS 17.0, macOS 14.0, *)
struct MainTabView: View {
    @Environment(AppNavigation.self) private var navigation

    /// DEL-028: Beobachtet den NotificationRouter und routet Notification-Taps
    /// (Cold-Start + Background) auf die richtige Tab. Eine `@State`-Property,
    /// damit SwiftUI das @Observable-Tracking automatisch einrichtet.
    @State private var notificationRouter = NotificationRouter.shared

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label {
                    Text("tab.dashboard", bundle: .module)
                } icon: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
            }
            .tag(AppTab.dashboard)

            // WorkoutRootView owns its own NavigationStack via AppNavigation.workoutPath
            // so finish-flows can clear the stack from anywhere in the workout tab.
            WorkoutRootView()
                .tabItem {
                    Label {
                        Text("tab.plan", bundle: .module)
                    } icon: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                    }
                }
                .tag(AppTab.plan)

            NavigationStack {
                MeasurementView()
            }
            .tabItem {
                Label {
                    Text("tab.measurement", bundle: .module)
                } icon: {
                    Image(systemName: "ruler")
                }
            }
            .tag(AppTab.measurement)

            NavigationStack {
                CalculatorsView()
            }
            .tabItem {
                Label {
                    Text("tab.calculators", bundle: .module)
                } icon: {
                    Image(systemName: "function")
                }
            }
            .tag(AppTab.calculators)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label {
                    Text("tab.more", bundle: .module)
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
            .tag(AppTab.settings)
        }
        // DEL-028 — Notification-Tap-Routing. Wird sowohl beim Cold-Start
        // (Router-Set vor MainTabView-First-Render) als auch im Background-
        // Path (Router-Set waehrend App schon laeuft) sauber gehandelt.
        .onAppear { applyPendingRouteIfAny() }
        .onChange(of: notificationRouter.pendingRoute) { _, _ in
            applyPendingRouteIfAny()
        }
    }

    private func applyPendingRouteIfAny() {
        guard let route = notificationRouter.consumePendingRoute() else { return }
        switch route {
        case .waterTracker:
            navigation.selectedTab = .calculators
            // TODO: Sub-Push WaterTracker — aktuell landet User auf Calculators-
            // Tab, der WaterTracker als Tile zeigt. Deep-Push waere ein
            // CalculatorsRoute, der's gezielt oeffnet — kommt mit DEL-014.
        case .measurement:
            navigation.selectedTab = .measurement
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit Profil (Main)") {
    RootView()
        .modelContainer(PreviewSeed.maleProfileContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Ohne Profil (Onboarding)") {
    RootView()
        .modelContainer(PreviewSeed.emptyContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit PPL-Plan + Historie") {
    RootView()
        .modelContainer(PreviewSeed.activeSessionContainer)
}
#endif
#endif
