#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth
import FitnessAppActivities
#if canImport(UIKit)
import UIKit
#endif

/// Settings hub — profile editor entry, unit toggle, HealthKit status, and the
/// destructive "Reset App" action. Everything that controls app-wide state lives
/// here; per-feature toggles stay close to their feature views.
@available(iOS 17.0, macOS 14.0, *)
public struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    @Environment(HealthKitController.self) private var healthKit
    @Environment(PRNotificationCenter.self) private var prNotifications

    @Query private var profiles: [UserBodyProfile]

    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"
    // DEL-018: Theme + Timer-Feedback + Reminder-Praeferenzen
    @AppStorage("pref_appearance") private var appearanceRaw: String = "system"   // system|light|dark
    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true
    @AppStorage("pref_timer_haptics") private var timerHapticsEnabled: Bool = true
    /// DEL-078: Global-Toggle fuer PR-Celebrations. Wenn off, werden Save-
    /// Screen-Popups, Live-Activity-Linger UND lokale PR-Notifications
    /// unterdrueckt. PR-Detection selbst (Trophy-Room) laeuft weiter — der
    /// User soll nur die "feierliche Stoerung" abschalten koennen.
    @AppStorage("pref_pr_celebrations") private var prCelebrationsEnabled: Bool = true
    @AppStorage("pref_water_reminder") private var waterReminderEnabled: Bool = true
    @AppStorage("pref_water_reminder_hours") private var waterReminderHours: Int = 3
    @AppStorage("pref_measurement_reminder") private var measurementReminderEnabled: Bool = true
    @AppStorage("pref_measurement_reminder_weekday") private var measurementWeekday: Int = 1  // 1=So, 2=Mo, ..., 7=Sa
    @AppStorage("pref_measurement_reminder_hour") private var measurementHour: Int = 8

    /// DEL-092: Globaler Opt-out fuer Warmup-/Cooldown-Uebungen im
    /// Active-Workout-Flow. Default `true` — wer schnell ohne Mobility
    /// trainieren will, kann es einmalig abschalten.
    @AppStorage("pref_show_warmups") private var showWarmups: Bool = true

    @State private var showingResetConfirm = false
    @State private var resetErrorMessage: String?

    public init() {}

    public var body: some View {
        // DEL-104: Form → ScrollView + DeltiqFormSection. Settings hat keine
        // Text-Inputs, daher genuegt `scrollDismissesKeyboard(.interactively)`
        // als defensiver Default — kein FocusState-Tracking noetig.
        ScrollView {
            VStack(spacing: 18) {
                profileSection
                preferencesSection
                appearanceSection
                timerFeedbackSection
                workoutBehaviorSection
                remindersSection
                healthKitSection
                aboutSection
                dangerZoneSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .navigationTitle(Text("settings.title", bundle: .module))
        .alert(
            "Fehler beim Zurücksetzen",
            isPresented: Binding(
                get: { resetErrorMessage != nil },
                set: { if !$0 { resetErrorMessage = nil } }
            )
        ) {
            Button("OK") { resetErrorMessage = nil }
        } message: {
            Text(resetErrorMessage ?? "")
        }
        .confirmationDialog(
            Text("settings.confirm.reset.title", bundle: .module),
            isPresented: $showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                resetApp()
            } label: {
                Text("settings.confirm.reset.action", bundle: .module)
            }
            Button(role: .cancel) {} label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("settings.confirm.reset.message", bundle: .module)
        }
    }

    // MARK: Sections

    private var profileSection: some View {
        DeltiqFormSection(header: String(localized: "settings.section.profile_goals", bundle: .module)) {
            DeltiqFormFullRow {
                profileSectionContent
            }
        }
    }

    @ViewBuilder
    private var profileSectionContent: some View {
        if let profile = profiles.first {
            NavigationLink {
                ProfileEditorView(profile: profile)
            } label: {
                profileSummary(profile)
            }
        } else {
            Text("Kein Profil vorhanden — App neu starten oder zurücksetzen.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func profileSummary(_ profile: UserBodyProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(profile.profile == .male ? "Männlich" : "Weiblich")
                    .font(.body.weight(.semibold))
                Text("•")
                Text("\(ageYears(for: profile)) Jahre")
                    .font(.body)
                Spacer()
            }
            HStack(spacing: 8) {
                Text(formattedHeight(profile.heightCm))
                if let goal = profile.goalWeightKg {
                    Text("•")
                    Text("Ziel \(formattedWeight(goal))")
                }
                Text("•")
                Text(environmentLabel(profile.environment))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// DEL-109: Reusable Nav-Row für die Dashboard-Customization. Wird in
    /// `preferencesSection` als zweite Row gerendert, damit's nicht eine
    /// eigene Section mit dupliziertem Header bekommt.
    @ViewBuilder
    private var dashboardCustomizationRow: some View {
        if let profile = profiles.first {
            DeltiqFormFullRow {
                NavigationLink {
                    DashboardSettingsView(profile: profile)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.3.group")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.deltiqOrange)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("dashboardSettings.entry", bundle: .module)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text("dashboardSettings.entry.subtitle", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var preferencesSection: some View {
        DeltiqFormSection(
            header: String(localized: "settings.section.preferences", bundle: .module)
        ) {
            DeltiqFormRow(label: String(localized: "settings.preferences.units", bundle: .module)) {
                Picker(selection: $weightUnitRaw) {
                    Text("settings.preferences.units.metric", bundle: .module).tag("kg")
                    Text("settings.preferences.units.imperial", bundle: .module).tag("lbs")
                } label: { EmptyView() }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            // DEL-084: Equipment-Tracker (Laufschuhe etc.) Submenu.
            DeltiqFormFullRow {
                NavigationLink {
                    GearListView()
                } label: {
                    HStack {
                        Label("Ausrüstung & Schuhe", systemImage: "shoe")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            // DEL-109: Dashboard-Widget-Manager.
            dashboardCustomizationRow
        } footer: {
            Text("Die DB speichert immer metrisch. Diese Einstellung steuert nur die Anzeige in Eingabe-Feldern, im Hantel-Rechner und auf den Karten.")
        }
    }

    // DEL-018: Theme-Picker
    private var appearanceSection: some View {
        DeltiqFormSection(header: "Erscheinungsbild") {
            // DEL-104: Segmented Picker spannt die ganze Row — keine
            // Label-on-left/Control-on-right Trennung, also FullRow.
            DeltiqFormFullRow {
                Picker(selection: $appearanceRaw) {
                    Text("System").tag("system")
                    Text("Hell").tag("light")
                    Text("Dunkel").tag("dark")
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        } footer: {
            Text("Greift in alle Views der App. 'System' folgt der iOS-Einstellung.")
        }
    }

    // DEL-018: Timer-Feedback (Ton + Vibration beim Pause-Ende)
    private var timerFeedbackSection: some View {
        DeltiqFormSection(header: "Pausen-Timer-Feedback") {
            // DEL-104: Toggles brauchen das volle Label inkl. Icon links —
            // FullRow weil das Label selbst eine Inline-Komposition aus
            // Image + Text ist; die DeltiqFormRow-Variante wuerde das in
            // einen `Text(label)`-String zerquetschen.
            DeltiqFormFullRow {
                Toggle(isOn: $timerSoundEnabled) {
                    Label("Ton abspielen", systemImage: "speaker.wave.2.fill")
                }
            }
            DeltiqFormFullRow {
                Toggle(isOn: $timerHapticsEnabled) {
                    Label("Vibrieren", systemImage: "iphone.radiowaves.left.and.right")
                }
            }
            // DEL-078: PR-Celebrations on/off. Separat vom Timer-Feedback —
            // PRs feiern ist ein anderer Use-Case als das Pausen-Ende
            // signalisieren.
            DeltiqFormFullRow {
                Toggle(isOn: $prCelebrationsEnabled) {
                    Label("PR-Feiern", systemImage: "trophy.fill")
                }
            }
        } footer: {
            Text("Wird beim Ablauf des Pausen-Timers ausgeloest. Vibrations-Toggle hat auf iPads keine Wirkung. 'PR-Feiern' steuert Save-Screen-Popups, Live-Activity-Headline und lokale Benachrichtigungen — die Bestleistungen werden trotzdem im Trophy-Room gespeichert.")
        }
    }

    // DEL-092: Workout-Verhalten — globaler Opt-out fuer Warmup-/Cooldown-
    // Uebungen. Filterung geschieht in `ActiveWorkoutView.orderedExercises`,
    // der gleiche Toggle wird dort via `@AppStorage("pref_show_warmups")`
    // gelesen — keine Notification-Plumbing noetig.
    private var workoutBehaviorSection: some View {
        DeltiqFormSection(header: "Workout-Verhalten") {
            DeltiqFormFullRow {
                Toggle(isOn: $showWarmups) {
                    Label("Warmup & Cooldown anzeigen", systemImage: "flame.fill")
                }
            }
        } footer: {
            Text("Wenn aus, werden Warmup- und Cooldown-Übungen während der Session ausgeblendet. Die Templates und deine Plan-Editierung bleiben unverändert — der Toggle wirkt nur auf den Live-Workout-Flow. Warmups sind ohnehin nie Pflicht: der „Workout speichern“-Button bleibt immer klickbar, auch wenn du sie nicht abhakst.")
        }
    }

    // DEL-018 + DEL-028: Reminder (Wasser-Frequenz + Mess-Wochentag/Uhrzeit).
    // Jede Aenderung triggert `rescheduleReminders()`, das ueber ReminderScheduler
    // re-schedulet — inkl. automatischem Cancel-Plus-Re-Add fuer Spam-Schutz.
    private var remindersSection: some View {
        DeltiqFormSection(header: "Erinnerungen") {
            DeltiqFormFullRow {
                Toggle(isOn: $waterReminderEnabled) {
                    Label("Wasser erinnern", systemImage: "drop.fill")
                }
                .onChange(of: waterReminderEnabled) { _, _ in
                    Task { await rescheduleReminders() }
                }
            }
            if waterReminderEnabled {
                DeltiqFormRow(label: "Häufigkeit") {
                    Picker(selection: $waterReminderHours) {
                        Text("Jede Stunde").tag(1)
                        Text("Alle 2 Stunden").tag(2)
                        Text("Alle 3 Stunden").tag(3)
                        Text("Alle 4 Stunden").tag(4)
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: waterReminderHours) { _, _ in
                        Task { await rescheduleReminders() }
                    }
                }
            }

            DeltiqFormFullRow {
                Toggle(isOn: $measurementReminderEnabled) {
                    Label("Messung erinnern", systemImage: "scalemass.fill")
                }
                .onChange(of: measurementReminderEnabled) { _, _ in
                    Task { await rescheduleReminders() }
                }
            }
            if measurementReminderEnabled {
                DeltiqFormRow(label: "Wochentag") {
                    Picker(selection: $measurementWeekday) {
                        Text("Sonntag").tag(1)
                        Text("Montag").tag(2)
                        Text("Dienstag").tag(3)
                        Text("Mittwoch").tag(4)
                        Text("Donnerstag").tag(5)
                        Text("Freitag").tag(6)
                        Text("Samstag").tag(7)
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: measurementWeekday) { _, _ in
                        Task { await rescheduleReminders() }
                    }
                }
                DeltiqFormRow(label: "Uhrzeit") {
                    Picker(selection: $measurementHour) {
                        ForEach(6..<23, id: \.self) { hour in
                            Text("\(hour):00 Uhr").tag(hour)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: measurementHour) { _, _ in
                        Task { await rescheduleReminders() }
                    }
                }
            }
        } footer: {
            Text("Lokale Benachrichtigungen — keine Server-Verbindung. Tippen auf eine Erinnerung öffnet direkt den passenden Tab.")
        }
    }

    /// Wendet alle Reminder-Praeferenzen via ReminderScheduler auf das System
    /// an. Triggert bei jedem Toggle/Picker-Wechsel UND beim SettingsView-
    /// `.task` (damit ein Reset oder ein cold-start die Schedules wieder
    /// herstellt).
    ///
    /// Spam-Schutz lebt im ReminderScheduler — pre-cancel der alten Schedules
    /// vor dem add.
    private func rescheduleReminders() async {
        // Permission anfordern wenn aktiviert und noch nicht entschieden.
        if waterReminderEnabled || measurementReminderEnabled {
            await prNotifications.refreshAuthorizationStatus()
            if prNotifications.isAuthorized == nil {
                _ = await prNotifications.requestAuthorization()
            }
        }
        // Wasser-Reminder
        if waterReminderEnabled {
            await ReminderScheduler.scheduleWaterReminders(everyHours: waterReminderHours)
        } else {
            await ReminderScheduler.cancelWaterReminders()
        }
        // Mess-Reminder
        if measurementReminderEnabled {
            await ReminderScheduler.scheduleMeasurementReminder(
                weekday: measurementWeekday,
                hour: measurementHour,
                minute: 0
            )
        } else {
            await ReminderScheduler.cancelMeasurementReminder()
        }
    }

    private var healthKitSection: some View {
        DeltiqFormSection(header: "Apple Health") {
            DeltiqFormFullRow {
                healthKitStatusRow
            }
            if healthKit.authorizationStatus == .sharingDenied {
                DeltiqFormFullRow {
                    openIOSSettingsButton
                }
            }
            if let lastSync = healthKit.lastSyncDate {
                DeltiqFormRow(label: "Letzter Sync") {
                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Bei aktivierter Verbindung wird im Messwerte-Formular das letzte Waagen-Gewicht vorausgefüllt. Beim Speichern werden Gewicht, KFA und Magere Masse zurück nach Apple Health geschrieben.")
        }
    }

    @ViewBuilder
    private var healthKitStatusRow: some View {
        switch healthKit.authorizationStatus {
        case .sharingAuthorized:
            HStack {
                Label("Verbunden", systemImage: "heart.fill")
                    .foregroundStyle(.pink)
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
            }
        case .notDetermined:
            HStack {
                Label("Nicht eingerichtet", systemImage: "heart")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Verbinden") {
                    Task { await healthKit.requestAuthorization() }
                }
                .font(.subheadline.weight(.semibold))
                .disabled(!healthKit.isAvailable)
            }
        case .sharingDenied:
            Label("Berechtigung verweigert", systemImage: "heart.slash")
                .foregroundStyle(.orange)
        case .unavailable:
            Label("Nicht verfügbar", systemImage: "heart.slash")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var openIOSSettingsButton: some View {
        #if os(iOS)
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Label("In iOS-Einstellungen öffnen", systemImage: "gear")
        }
        #endif
    }

    private var aboutSection: some View {
        DeltiqFormSection(
            header: String(localized: "settings.section.about", bundle: .module)
        ) {
            DeltiqFormRow(label: "Version") {
                Text(appVersion).foregroundStyle(.secondary)
            }
            DeltiqFormRow(label: "Bundle") {
                Text(bundleIdentifier).foregroundStyle(.secondary).font(.caption)
            }
        }
    }

    private var dangerZoneSection: some View {
        DeltiqFormSection(
            header: String(localized: "settings.section.danger_zone", bundle: .module)
        ) {
            DeltiqFormFullRow {
                Button(role: .destructive) {
                    showingResetConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Label {
                            Text("settings.action.reset", bundle: .module)
                        } icon: {
                            Image(systemName: "trash")
                        }
                        Spacer()
                    }
                }
            }
        } footer: {
            Text("Löscht Profil, Messungen, Pläne, Trainings-Templates und Workout-Sessions vollständig. Die Apple-Health-Daten bleiben erhalten — die löscht du in der Health-App selber.")
        }
    }

    // MARK: Reset

    /// Wipes all SwiftData entities and our `@AppStorage` keys, then resets navigation
    /// so the app re-renders into Onboarding. Apple-Health-Daten bleiben unangetastet
    /// (sind Eigentum des Users in einer separaten Datenbank).
    ///
    /// **Crash-safe Reset-Pattern** (v0.1.17 DEL-017-Fix): Wir leeren ERST
    /// `navigation.workoutPath` und schicken den Tab auf Dashboard — das raeumt
    /// jede `@Bindable`-Referenz auf gleich zu loeschende Models aus dem
    /// SwiftUI-View-Tree. ERST DANACH stossen wir die Loeschungen via
    /// `DispatchQueue.main.async` an. Synchrones Delete + Save HIER wuerde
    /// SwiftUI mid-render mit halb-leerem Model-Graph konfrontieren und einen
    /// EXC_BREAKPOINT-Crash ausloesen, weil @Bindable/@Query-Subscriber auf
    /// gerade geloeschte UserBodyProfile-Refs zugreifen.
    ///
    /// **Per-instance statt batch-delete** (v0.1.13 DEL-006-Fix): SwiftData's
    /// bulk `delete(model:)` baut intern ein NSBatchDeleteRequest und umgeht
    /// die @Relationship-Cascade/Nullify-Regeln → "mandatory OTO nullify
    /// inverse"-Violations. Fetch + delete-each respektiert die Regeln.
    ///
    /// Neue `@Model`-Typen MUESSEN in `deleteAll`-Sequenz unten — sonst
    /// "Geist"-Daten nach dem vermeintlichen Reset.
    private func resetApp() {
        // 1) Navigation-State sofort zuruecksetzen — entfernt @Bindable-
        //    References auf gleich-zu-loeschende UserBodyProfile/Plan/Day.
        navigation.workoutPath = NavigationPath()
        navigation.selectedTab = .dashboard

        // 2) AppStorage-Keys sofort wegwerfen (synchron OK, kein Model).
        for key in ["weight_unit", "height_unit", "unit_system"] {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 3) Die eigentlichen SwiftData-Loeschungen ans Ende des aktuellen
        //    Render-Cycles schicken. Erst wenn SwiftUI den Tab-Switch
        //    verarbeitet hat (und die alten Subscriber aufgeloest sind),
        //    fahren wir die Deletes durch und savnen — der RootView-@Query
        //    sieht dann das Empty-State und swappt sauber auf Onboarding.
        DispatchQueue.main.async {
            do {
                // Children-first ordering. Per-instance-Delete respektiert
                // @Relationship-Rules.
                try self.deleteAll(of: PersonalRecordEntry.self)
                try self.deleteAll(of: ExerciseLog.self)
                try self.deleteAll(of: WorkoutSession.self)
                try self.deleteAll(of: Exercise.self)
                try self.deleteAll(of: TrainingDay.self)
                try self.deleteAll(of: TrainingPlan.self)
                try self.deleteAll(of: ExerciseTemplate.self)
                try self.deleteAll(of: WaterEntry.self)
                try self.deleteAll(of: BodyMeasurement.self)
                try self.deleteAll(of: UserBodyProfile.self)
                try self.modelContext.save()
            } catch {
                self.resetErrorMessage = error.localizedDescription
            }
        }
    }

    /// Fetches every instance of `T` and deletes them one by one. Rule-aware
    /// alternative to `modelContext.delete(model:)`, which uses NSBatchDeleteRequest
    /// under the hood and trips constraint violations on cascade/nullify
    /// relationships.
    private func deleteAll<T: PersistentModel>(of type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
    }

    // MARK: Formatters

    private func ageYears(for profile: UserBodyProfile) -> Int {
        Calendar.current.dateComponents([.year], from: profile.birthDate, to: Date()).year ?? 0
    }

    /// Always reads cm from DB; converts to inches when the user prefers imperial.
    private func formattedHeight(_ cm: Double) -> String {
        if weightUnitRaw == "lbs" {
            let inches = cm / 2.54
            return "\(inches.truncated(to: 1).formattedTwoDecimals) in"
        }
        return "\(cm.truncated(to: 1).formattedTwoDecimals) cm"
    }

    private func formattedWeight(_ kg: Double) -> String {
        if weightUnitRaw == "lbs" {
            let lbs = kg / 0.453592
            return "\(lbs.truncated(to: 2).formattedTwoDecimals) lbs"
        }
        return "\(kg.truncated(to: 2).formattedTwoDecimals) kg"
    }

    private func environmentLabel(_ env: EnvironmentType) -> String {
        switch env {
        case .gym:         return "Gym"
        case .homeGym:     return "Home-Gym"
        case .noEquipment: return "Ohne Equipment"
        }
    }

    private var appVersion: String {
        let d = Bundle.main.infoDictionary
        let version = d?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = d?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "—"
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit Profil") {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewSeed.dashboardContainer)
    .environment(AppNavigation())
    .environment(HealthKitController())
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Ohne Profil") {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewSeed.emptyContainer)
    .environment(AppNavigation())
    .environment(HealthKitController())
}
#endif
#endif
