#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
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

    /// DEL-134: Globaler Reset-Gate-Flag. SettingsView.resetApp() setzt
    /// das auf true VOR der SwiftData-Deletion. Solange true, rendern
    /// wir eine sichere ProgressView statt MainTabView/OnboardingView —
    /// kein Sub-View kann waehrend der Deletion-Async-Phase auf stale
    /// @Query-Refs zugreifen + crashen. Wenn `resetApp()` fertig ist
    /// (Success oder Error), wird der Flag wieder auf false gesetzt
    /// und RootView swappt automatisch zur passenden View (Onboarding
    /// wenn profiles leer, sonst Main).
    @AppStorage("isResetting") private var isResetting: Bool = false

    public init() {}

    public var body: some View {
        Group {
            if isResetting {
                resettingPlaceholder
            } else if profiles.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        // Crossfade when the @Query result flips from empty to non-empty (and vice
        // versa, e.g. after a Settings reset).
        .animation(.easeInOut(duration: 0.25), value: profiles.isEmpty)
        .animation(.easeInOut(duration: 0.25), value: isResetting)
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
            // DEL-134-Recovery: wenn der vorige Reset-Versuch mid-flight
            // crashed (sehr selten — z.B. iOS-Background-Termination kurz
            // nach `modelContext.save`), bleibt `isResetting=true` in
            // AppStorage stehen. Beim naechsten Launch wuerde RootView
            // dann auf der ProgressView haengen. Defensive reset.
            if isResetting { isResetting = false }

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
            // DEL-149: Foreign-Locale-Exercise-Name-Repair. Eintraege die
            // unter einer anderen Locale gespeichert wurden (z.B. "Koşu
            // Bandı" statt "Laufband"), werden via Reverse-Lookup auf den
            // DE-Base umgeschrieben. MUSS NACH backfillCustomNamesIfNeeded
            // laufen, damit der dort potenziell faelschlich gesetzte
            // `customName` hier wieder bereinigt werden kann. Idempotent.
            ExerciseNameBackfill.runIfNeeded(in: modelContext)
            // DEL-150: Ad-Hoc-Workout-Titel-Repair. Spontane Sessions, deren
            // ephemerer TrainingDay noch ohne localizationKey gespeichert
            // wurde, bekommen `session.adHoc.dayName` nachgezogen — damit
            // rendert der Verlauf sprachfest. Idempotent.
            LibrarySeeder.backfillAdHocDayLocalizationIfNeeded(in: modelContext)
            // DEL-163: Custom-Exercise-Metadaten-Repair. Bereits adoptierte
            // Custom-Uebungen ohne Muskel/Equipment-Override bekommen die
            // Werte aus ihrem Custom-Template nachgezogen. Idempotent.
            LibrarySeeder.backfillCustomExerciseMetadataIfNeeded(in: modelContext)
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

    /// DEL-134: Safe-Mode-Placeholder waehrend der App-Reset-Sequenz.
    /// Alle @Query-basierten Sub-Views sind hier komplett ausgeklinkt —
    /// damit es keine dangling-pointer-crash mehr beim Reset gibt.
    /// Sobald SettingsView.resetApp() den isResetting-Flag wieder auf
    /// false setzt (nach erfolgreichem oder gescheiterten save), swappt
    /// RootView automatisch auf OnboardingView oder MainTabView.
    private var resettingPlaceholder: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("root.resetting.label", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Deltiq.background.ignoresSafeArea())
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

/// Top-level container for the post-onboarding flow. Tab order (Signature-
/// Geruest, Variante 2b): Dashboard → Plan → [zentraler Aktionsknopf] →
/// Messung → Mehr (Rechner haengt seit dem Tab-Umbau dort, siehe
/// `SettingsView`). Cross-tab navigation runs through `AppNavigation`.
@available(iOS 17.0, macOS 14.0, *)
struct MainTabView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.modelContext) private var modelContext

    /// DEL-028: Beobachtet den NotificationRouter und routet Notification-Taps
    /// (Cold-Start + Background) auf die richtige Tab. Eine `@State`-Property,
    /// damit SwiftUI das @Observable-Tracking automatisch einrichtet.
    @State private var notificationRouter = NotificationRouter.shared

    /// Faengt den Fall ab, dass der leere Platzhalter-Tab (`.actionButton`)
    /// doch mal getroffen wird (Tap knapp neben dem ueberlagernden Knopf) —
    /// springt sofort zurueck auf den zuletzt sichtbaren echten Tab, statt
    /// eine leere Flaeche zu zeigen.
    @State private var lastRealTab: AppTab = .dashboard

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

            // Signature-Geruest 1.11: TabView kann keinen ueberstehenden
            // Mittelknopf. Uebliche Loesung — mittleren Tab-Eintrag als
            // leeres Platzhalter-Item fuehren, den Knopf per .overlay
            // darueberzeichnen (siehe actionButton/.overlay unten).
            Color.clear
                .tabItem { Text("") }
                .tag(AppTab.actionButton)

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

            // DEL-212, angepasst: Path-Binding fuers "Mehr"-Tab, damit die
            // Wasser-Erinnerungs-Notification weiterhin in einem Sprung bis
            // zum WaterTracker durchpushen kann, obwohl Rechner keinen
            // eigenen Tab mehr hat. Der normale, getippte Weg (Mehr →
            // Rechner → Wassertracker) laeuft unabhaengig davon ueber
            // CalculatorsView's eigene NavigationLink(destination:)-Zeilen.
            NavigationStack(path: $navigation.morePath) {
                SettingsView()
                    .navigationDestination(for: CalculatorsRoute.self) { route in
                        switch route {
                        case .waterTracker:
                            WaterTrackerView()
                        }
                    }
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
        .overlay(alignment: .bottom) {
            actionButton
                .offset(y: -18)
        }
        // DEL-028 — Notification-Tap-Routing. Wird sowohl beim Cold-Start
        // (Router-Set vor MainTabView-First-Render) als auch im Background-
        // Path (Router-Set waehrend App schon laeuft) sauber gehandelt.
        .onAppear {
            applyPendingRouteIfAny()
            configureTabBarAppearance()
        }
        .onChange(of: notificationRouter.pendingRoute) { _, _ in
            applyPendingRouteIfAny()
        }
        .onChange(of: navigation.selectedTab) { _, newValue in
            if newValue == .actionButton {
                navigation.selectedTab = lastRealTab
            } else {
                lastRealTab = newValue
            }
        }
    }

    /// Zentraler Aktionsknopf (Abschnitt 1.11): 56×56, Kreis, Akzent-Verlauf.
    /// Bewusst NICHT kontextabhaengig — loest ueberall dieselbe Aktion aus
    /// (Rueckfallebene der im Handoff offen gelassenen Produktentscheidung).
    private var actionButton: some View {
        Button(action: startOrResumeWorkout) {
            Image(systemName: "play.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.Deltiq.primaryGradient)
                .clipShape(Circle())
                .shadow(color: Color.deltiqOrange.opacity(0.4), radius: 16, x: 0, y: 6)
        }
        .accessibilityLabel(Text("dashboard.action.startDirect", bundle: .module))
    }

    private func applyPendingRouteIfAny() {
        guard let route = notificationRouter.consumePendingRoute() else { return }
        switch route {
        case .waterTracker:
            // DEL-212: Tab-Swap + Deep-Push direkt in den WaterTracker.
            // Path wird ersetzt (nicht appended), damit wiederholte Taps
            // keinen Stack aus mehreren Tracker-Screens aufbauen.
            navigation.selectedTab = .settings
            navigation.morePath = NavigationPath([CalculatorsRoute.waterTracker])
        case .measurement:
            navigation.selectedTab = .measurement
        }
    }

    /// Startet die naechste faellige Trainingseinheit des aktiven Plans oder
    /// setzt eine bereits offene Session fort. Absichtlich einfacher als
    /// Dashboards `activeWorkoutButton`: kein Comeback-Prompt (DEL-239) und
    /// kein Konfliktdialog fuer eine zweite offene Session auf einem anderen
    /// Tag — beides haengt an View-lokalem State in `DashboardView`, den
    /// dieser globale Kurzbefehl nicht dupliziert. Sind mehrere Sessions
    /// offen, wird die zuletzt gestartete fortgesetzt.
    private func startOrResumeWorkout() {
        var openDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == false && $0.isRestDay == false },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        openDescriptor.fetchLimit = 1
        if let open = try? modelContext.fetch(openDescriptor).first {
            navigation.workoutPath = NavigationPath()
            if let day = open.day, let plan = day.plan {
                navigation.workoutPath.append(plan)
                navigation.workoutPath.append(day)
            }
            navigation.workoutPath.append(ActiveSessionRoute(session: open))
            navigation.selectedTab = .plan
            return
        }

        let planDescriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let plan = try? modelContext.fetch(planDescriptor).first, !plan.days.isEmpty else {
            // Kein aktiver Plan: Plan-Tab zeigen, dort greift der Leerzustand.
            navigation.selectedTab = .plan
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
            navigation.selectedTab = .plan
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

        navigation.workoutPath = NavigationPath()
        navigation.workoutPath.append(plan)
        navigation.workoutPath.append(day)
        navigation.workoutPath.append(ActiveSessionRoute(session: session))
        navigation.selectedTab = .plan
    }

    /// Signature-Geruest 1.11: Hintergrund #1C1C1E @ 92%, aktiver Tab Orange,
    /// inaktiv Weiss ~35%. Native `TabView`/`Label`-Styling laesst sich nur
    /// bis zu einem gewissen Grad treffen — `UITabBarAppearance` kommt der
    /// Vorgabe deutlich naeher als reines SwiftUI-`.tint()`, aber Blur-Radius
    /// und die 1pt-Oberkante aus dem Handoff sind damit nicht exakt
    /// erreichbar. Braucht Sichtpruefung im Simulator.
    private func configureTabBarAppearance() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.Deltiq.surface).withAlphaComponent(0.92)

        let normalColor = UIColor.white.withAlphaComponent(0.35)
        let selectedColor = UIColor(Color.deltiqOrange)
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
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
