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

    /// Siehe SettingsView — Opt-in fuer den automatischen Import von Lauf-/
    /// Rad-Workouts aus Fremd-Apps via Apple Health.
    @AppStorage("pref_healthkit_workout_import") private var externalWorkoutImportEnabled: Bool = false

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
            // Paket-3a-Geraetenachweis (docs/DELTIQ_DEVICE_ACCEPTANCE.md):
            // No-Op in jedem regulaeren Start — siehe Typ-Doku dort fuer die
            // beiden Bedingungen (Debug-Build UND explizites Launch-Argument).
            #if DEBUG
            DeviceAcceptanceFixturePaket3a.seedIfRequested(in: modelContext)
            #endif

            // DEL-134-Recovery: wenn der vorige Reset-Versuch mid-flight
            // crashed (sehr selten — z.B. iOS-Background-Termination kurz
            // nach `modelContext.save`), bleibt `isResetting=true` in
            // AppStorage stehen. Beim naechsten Launch wuerde RootView
            // dann auf der ProgressView haengen. Defensive reset.
            if isResetting { isResetting = false }

            // Eine Live Activity, die ein frueherer Prozess zurueckgelassen hat (App
            // waehrend eines AMRAP/EMOM/Auf-Zeit/Zirkel-Laufs beendet), hat keinen
            // Player mehr, der sie fuehrt - wegraeumen. Ein schon laufender Lauf (z.B.
            // per Tipp auf die Live Activity geoeffnet) bleibt unberuehrt.
            TimedWorkoutBackground.shared.endOrphans()

            // Refresh per-launch availability for native integrations. Both checks
            // are cheap; both are no-ops when their frameworks aren't present.
            await healthKit.refreshAuthorizationStatus()
            restTimerActivity.refreshAvailability()
            await prNotifications.refreshAuthorizationStatus()

            // Bugfix (Geraetetest): raeumt vor jedem weiteren Seeder-Aufruf
            // bereits entstandene System-Template-Dubletten auf (siehe Doc
            // dort fuer die Ursache). MUSS vor `seedIfNeeded`/
            // `backfillNewLibraryEntriesIfNeeded` laufen — sonst wuerden
            // bestehende Dubletten jeden Start als "schon vorhanden" gelten,
            // ohne je bereinigt zu werden. Idempotent.
            LibrarySeeder.deduplicateTemplatesIfNeeded(in: modelContext)
            // Seed the canonical exercise library on first launch (idempotent
            // — fetchCount short-circuits when rows already exist).
            LibrarySeeder.seedIfNeeded(in: modelContext)
            // Final-review fix (critical): was only ever called from
            // AddMealView's #Preview and tests, so on a real device
            // @Query FoodCatalogEntry stayed empty forever and no food
            // could ever be added. Idempotent — fetchCount short-circuits
            // when rows already exist, same as LibrarySeeder above.
            FoodCatalogSeeder.seedIfNeeded(in: modelContext)
            // UX-Katalog-Erweiterung: Backfill fuer System-Katalogeintraege,
            // die NACH dem ersten Seed hinzugekommen sind (130 -> 234
            // Eintraege) — ohne das waeren sie fuer jeden Bestandsnutzer
            // dauerhaft unsichtbar, weil `seedIfNeeded` einen nicht-leeren
            // Katalog nie erneut befuellt. Idempotent — Diff gegen bereits
            // vorhandene `.seeded`-catalogIDs.
            FoodCatalogSeeder.backfillNewCatalogEntriesIfNeeded(in: modelContext)
            // README 2.35: Backfill fuer Library-Eintraege, die NACH dem
            // ersten Seed hinzugekommen sind (z.B. "Lauf-Intervall"/
            // "Rad-Intervall") - ohne das waeren sie fuer jeden
            // Bestandsnutzer dauerhaft unsichtbar im Bibliotheks-Picker.
            // Idempotent — Diff gegen bereits vorhandene System-Namen.
            LibrarySeeder.backfillNewLibraryEntriesIfNeeded(in: modelContext)
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
            // Settings-Epic Phase 6 (EXLIB-07/09): stabile Vorlagen-ID
            // rueckwirkend verknuepfen, wo eindeutig moeglich. MUSS NACH
            // ExerciseNameBackfill laufen (siehe dortige Begruendung) —
            // sonst wuerden Fremdsprach-Namens-Snapshots faelschlich als
            // unaufloesbar durchfallen. Idempotent.
            ExerciseTemplateIDBackfill.runIfNeeded(in: modelContext)
            // DEL-150: Ad-Hoc-Workout-Titel-Repair. Spontane Sessions, deren
            // ephemerer TrainingDay noch ohne localizationKey gespeichert
            // wurde, bekommen `session.adHoc.dayName` nachgezogen — damit
            // rendert der Verlauf sprachfest. Idempotent.
            LibrarySeeder.backfillAdHocDayLocalizationIfNeeded(in: modelContext)
            // DEL-163: Custom-Exercise-Metadaten-Repair. Bereits adoptierte
            // Custom-Uebungen ohne Muskel/Equipment-Override bekommen die
            // Werte aus ihrem Custom-Template nachgezogen. Idempotent.
            LibrarySeeder.backfillCustomExerciseMetadataIfNeeded(in: modelContext)
            // Settings-Epic Phase 2: Bereinigt bereits gespeicherte, aus einem
            // BMI-Naeherungswert erfundene KFA/FFM/FFMI-Werte (keine echten
            // Umfaenge vorhanden). Idempotent — Predicate filtert auf
            // vorhandenen Deurenberg-Wert, der nach dem Nullen verschwindet.
            BodyMeasurementMigrator.backfillFabricatedBodyCompositionIfNeeded(in: modelContext)
            // Nachgetragene Laeufe mit der Wanduhr-Dauer von ein, zwei Minuten
            // bekommen die eingetragene Laufzeit. Einmalig, nur die Dauer.
            SessionDurationRepair.runIfNeeded(in: modelContext)
            // Smart-Onboarding-Epic: Bestandsnutzer ohne OnboardingProfile-
            // Antwort bekommen einmalig einen aus der Trainingshistorie
            // genaeherten ExperienceTrack statt dauerhaft eines blinden
            // Defaults. Idempotent — Predicate filtert auf
            // experienceTrackRaw == nil.
            ExperienceTrackBackfill.runIfNeeded(in: modelContext)

            // Erinnerungen gegen die gespeicherten Schalter abgleichen: Die
            // geplanten Benachrichtigungen liegen im System und gehen z.B. bei
            // einer Geraete-Wiederherstellung verloren, die Schalter in
            // UserDefaults dagegen nicht. Ohne Profil laeuft noch das
            // Onboarding, dort wird erst nach der Berechtigungsabfrage
            // geplant. Bewusst VOR dem HealthKit-Sync: der Abgleich ist billig
            // und soll nicht hinter einer potenziell langen Abfrage warten.
            if !profiles.isEmpty {
                await ReminderPreferencesApplier.applyStoredSchedules()
            }

            // Auto-Sync externer HealthKit-Workouts (z.B. Adidas Running) —
            // nur wenn der User das in Settings explizit aktiviert hat. Nach
            // den Library-Backfills oben, damit die "Freier Lauf"/"Radfahren
            // (outdoor)"-Templates fuer die synthetischen Exercises sicher
            // existieren.
            if externalWorkoutImportEnabled {
                await ExternalWorkoutImportService.syncExternalWorkouts(
                    healthKit: healthKit,
                    context: modelContext
                )
            }
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
        // Bugfix (Audit): Pfad-Reset galt bisher nur im gefundenen-Session-
        // Zweig unten - bei einem veralteten/spaeten Live-Activity-Tap ohne
        // noch existierende Session (z.B. App-Cold-Start nach Crash) blieb
        // ein bereits vorhandener verschachtelter Pfad stehen, obwohl der
        // Kommentar unten genau das verhindern soll. Reset gilt jetzt fuer
        // beide Faelle: Session gefunden -> Route wird angehaengt; Session
        // nicht gefunden -> User landet auf der Plan-Liste.
        navigation.workoutPath = NavigationPath()
        // Aktive Session pullen. Defensive: FetchDescriptor auf nicht-
        // completed, nicht-rest-day Sessions, neueste zuerst.
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == false && $0.isRestDay == false },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let session = try? modelContext.fetch(descriptor).first {
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

/// Top-level container for the post-onboarding flow. Tab order (main-
/// navigation Plan, 2026-10-22, Task 1): Heute → Training → Ernaehrung →
/// Fortschritt → Mehr. Cross-tab navigation runs through `AppNavigation`.
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

            // main-navigation Plan, 2026-10-22, Task 1: eigener Ernaehrungs-
            // Tab zwischen Training und Fortschritt, statt nur ueber die
            // Dashboard-Kachel erreichbar zu sein.
            // Phase 4.1 (2026-10-31): path-bound auf `nutritionPath` analog zu
            // `toolsPath`; navigationDestination leitet `.planner` → MealPlannerView.
            NavigationStack(path: $navigation.nutritionPath) {
                NutritionDayView(isTabRoot: true)
                    .navigationDestination(for: MealPlannerRoute.self) { _ in
                        MealPlannerView()
                    }
            }
            .tabItem {
                Label {
                    Text("tab.nutrition", bundle: .module)
                } icon: {
                    Image(systemName: "fork.knife")
                }
            }
            .tag(AppTab.nutrition)

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

            // main-navigation Plan, 2026-10-22, Task 3 (Fix-Runde 1: komplett
            // wertbasiert statt mit view-basierten NavigationLinks gemischt,
            // siehe `CalculatorsRoute`-Doku): path-bound auf `toolsPath`. Die
            // "Werkzeuge"-Zeile in SettingsView pusht `.calculators`, die
            // Wassertracker-Zeile in CalculatorsView pusht `.waterTracker` —
            // beide ueber dieselbe hier registrierte `navigationDestination`.
            // Der Deep-Link (`applyPendingRouteIfAny`) resettet `toolsPath`
            // und haengt `.waterTracker` direkt an, landet also unabhaengig
            // vom vorherigen Navigationszustand garantiert im WaterTracker.
            NavigationStack(path: $navigation.toolsPath) {
                SettingsView()
                    .navigationDestination(for: CalculatorsRoute.self) { route in
                        switch route {
                        case .calculators:
                            CalculatorsView()
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
    }

    private func applyPendingRouteIfAny() {
        guard let route = notificationRouter.consumePendingRoute() else { return }
        switch route {
        case .waterTracker:
            // main-navigation Plan, 2026-10-22, Task 3: CalculatorsView haengt
            // jetzt eine Ebene tief unter "Mehr" statt einer eigenen Tab-
            // Wurzel. Reset + Push auf `toolsPath` (gebunden an die Settings-
            // NavigationStack) landet ueber die oben registrierte
            // `navigationDestination(for: CalculatorsRoute.self)` weiterhin
            // in einem einzigen Schritt direkt im WaterTracker, ohne
            // CalculatorsView sichtbar zu durchlaufen — derselbe Ein-Tap-
            // Sprung wie vor dem Werkzeuge-Tab (Nachtrag 6. August).
            navigation.selectedTab = .settings
            navigation.toolsPath = NavigationPath()
            navigation.toolsPath.append(CalculatorsRoute.waterTracker)
        case .measurement:
            navigation.selectedTab = .measurement
        }
    }

    /// Signature-Geruest 1.11: Hintergrund #1C1C1E @ 92%, aktiver Tab Orange,
    /// inaktiv Weiss ~35%. Native `TabView`/`Label`-Styling laesst sich nur
    /// bis zu einem gewissen Grad treffen — `UITabBarAppearance` kommt der
    /// Vorgabe deutlich naeher als reines SwiftUI-`.tint()`, aber Blur-Radius
    /// und die 1pt-Oberkante aus dem Handoff sind damit nicht exakt
    /// erreichbar. Braucht Sichtpruefung im Simulator.
    ///
    /// Geraete-Abnahme (Runde 10, docs/DELTIQ_DEVICE_ACCEPTANCE.md): die
    /// "Weiss ~35%"-Vorgabe oben ging von einem IMMER dunklen Hintergrund
    /// aus (#1C1C1E, wie im Kommentar explizit benannt) - `Color.Deltiq.
    /// surface` ist aber hell/dunkel-adaptiv (reines Weiss im Light Mode,
    /// siehe Theme.swift). Weiss-auf-Weiss machte die vier inaktiven
    /// Tab-Icons im Light Mode de facto unsichtbar (nur der aktive, orange
    /// Tab blieb erkennbar) - exakt das vom Nutzer gemeldete "fehlende
    /// untere Menuepunkte", abhaengig vom Farbschema. Fix: dieselbe
    /// hell/dunkel-Verzweigung wie `Color.init(deltiqLight:deltiqDark:)`
    /// oben im Theme, nicht die Oberflaechenfarbe selbst anfassen.
    private func configureTabBarAppearance() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.Deltiq.surface).withAlphaComponent(0.92)

        // Dieselbe Hell/Dunkel-Verzweigung wie `Color.Deltiq.surface`
        // (Theme.swift) — der Tab-Bar-Hintergrund ist adaptiv, die
        // Icon-Farbe muss es also ebenfalls sein.
        let normalColor = UIColor(Color(deltiqLight: .black.opacity(0.35), deltiqDark: .white.opacity(0.35)))
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
