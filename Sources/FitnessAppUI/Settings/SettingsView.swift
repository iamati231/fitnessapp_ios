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

    /// DEL-134: Globaler Reset-Gate-Flag. Wird in `resetApp()` auf true
    /// gesetzt vor der SwiftData-Deletion, RootView checkt ihn und
    /// rendert eine sichere ProgressView statt MainTabView. Ohne den
    /// Flag kann jede View, die @Query auf gleich-zu-loeschende Objekte
    /// hat, mid-render crashen.
    @AppStorage("isResetting") private var isResetting: Bool = false

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

    /// DEL-143: User-Toggle für RIR-Bloop-Tooltips. Gleicher AppStorage-
    /// Key wie in SetRow/ExerciseEditor — Single Source of Truth, ändert
    /// das Verhalten überall sofort.
    @AppStorage("showRirTooltips") private var showRirTooltips: Bool = true

    /// DEL-238: Deload-Automatik. Default AN (siehe Begruendung an der
    /// Toggle-Zeile). Gated ausschliesslich die VORSCHLAEGE — nie einen
    /// laufenden Deload und nie den Weg zurueck.
    @AppStorage("pref_deload_enabled") private var deloadEnabled: Bool = true

    /// Rueckmeldung nach dem manuellen Zuruecksetzen.
    @State private var deloadRestoreMessage: String?

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
                privacySection
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
            Text("settings.profile.missing", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func profileSummary(_ profile: UserBodyProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(profile.profile == .male ? "sex.male" : "sex.female", bundle: .module)
                    .font(.body.weight(.semibold))
                Text("•")
                Text(String(format: String(localized: "settings.profile.years", bundle: .module), ageYears(for: profile)))
                    .font(.body)
                Spacer()
            }
            HStack(spacing: 8) {
                Text(formattedHeight(profile.heightCm))
                if let goal = profile.goalWeightKg {
                    Text("•")
                    Text(String(format: String(localized: "settings.profile.goal", bundle: .module), formattedWeight(goal)))
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
                            Text("dashboardSettings.entry.title", bundle: .module)
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
            DeltiqFormRow(label: String(localized: "settings.preferences.units.label", bundle: .module)) {
                Picker(selection: $weightUnitRaw) {
                    Text("settings.preferences.units.metric", bundle: .module).tag("kg")
                    Text("settings.preferences.units.imperial", bundle: .module).tag("lbs")
                } label: { EmptyView() }
                .pickerStyle(.menu)
                .labelsHidden()
                // DEL-119: i18n-bedingter Layout-Bug. "Metrisch (kg/cm)"
                // sprengte auf iPhone-SE / kompakten Width-Class das
                // DeltiqFormRow-Limit und brach um — sieht in Settings
                // unschoen aus. lineLimit(1) verhindert den Bruch,
                // minimumScaleFactor(0.8) verkleinert die Schrift dezent
                // bei Bedarf, statt zu truncaten. Pragmatisches i18n-
                // Sicherheitsnetz (gilt auch fuer kuenftige Sprachen).
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            // DEL-161: Globale Uebungsbibliothek.
            DeltiqFormFullRow {
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    HStack {
                        Label {
                            Text("settings.preferences.exerciseLibrary", bundle: .module)
                        } icon: {
                            Image(systemName: "figure.strengthtraining.traditional")
                        }
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            // DEL-084: Equipment-Tracker (Laufschuhe etc.) Submenu.
            DeltiqFormFullRow {
                NavigationLink {
                    GearListView()
                } label: {
                    HStack {
                        Label {
                            Text("settings.preferences.gear", bundle: .module)
                        } icon: {
                            Image(systemName: "shoe")
                        }
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
            Text("settings.units.footer", bundle: .module)
        }
    }

    // DEL-018: Theme-Picker
    private var appearanceSection: some View {
        DeltiqFormSection(header: String(localized: "settings.appearance.section", bundle: .module)) {
            // DEL-104: Segmented Picker spannt die ganze Row — keine
            // Label-on-left/Control-on-right Trennung, also FullRow.
            DeltiqFormFullRow {
                Picker(selection: $appearanceRaw) {
                    Text("settings.appearance.system", bundle: .module).tag("system")
                    Text("settings.appearance.light", bundle: .module).tag("light")
                    Text("settings.appearance.dark", bundle: .module).tag("dark")
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        } footer: {
            Text("settings.appearance.footer", bundle: .module)
        }
    }

    // DEL-018: Timer-Feedback (Ton + Vibration beim Pause-Ende)
    private var timerFeedbackSection: some View {
        DeltiqFormSection(header: String(localized: "settings.timer.section", bundle: .module)) {
            DeltiqFormFullRow {
                Toggle(isOn: $timerSoundEnabled) {
                    Label {
                        Text("settings.timer.sound", bundle: .module)
                    } icon: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                }
            }
            DeltiqFormFullRow {
                Toggle(isOn: $timerHapticsEnabled) {
                    Label {
                        Text("settings.timer.haptics", bundle: .module)
                    } icon: {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                    }
                }
            }
            // DEL-078: PR-Celebrations on/off. Separat vom Timer-Feedback.
            DeltiqFormFullRow {
                Toggle(isOn: $prCelebrationsEnabled) {
                    Label {
                        Text("settings.timer.prCelebrations", bundle: .module)
                    } icon: {
                        Image(systemName: "trophy.fill")
                    }
                }
            }
        } footer: {
            Text("settings.timer.footer", bundle: .module)
        }
    }

    // DEL-092: Workout-Verhalten — globaler Opt-out fuer Warmup-/Cooldown-
    // Uebungen. Filterung geschieht in `ActiveWorkoutView.orderedExercises`,
    // der gleiche Toggle wird dort via `@AppStorage("pref_show_warmups")`
    // gelesen — keine Notification-Plumbing noetig.
    private var workoutBehaviorSection: some View {
        DeltiqFormSection(header: String(localized: "settings.workout.section", bundle: .module)) {
            DeltiqFormFullRow {
                Toggle(isOn: $showWarmups) {
                    Label {
                        Text("settings.workout.showWarmups", bundle: .module)
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                }
            }
            // DEL-143: RIR-Tooltip-Toggle. Default true (per Ticket-Spec).
            // Power-User können den Bloop ausschalten, dann werden RIR-
            // Slider stumm bedient wie vorher.
            DeltiqFormFullRow {
                Toggle(isOn: $showRirTooltips) {
                    Label {
                        Text("settings.training.rirTooltip.title", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle.fill")
                    }
                }
            }
            // DEL-238: Deload-Automatik abschaltbar. Default AN — ein
            // ausgeliefertes Feature bei Bestandsnutzern still zu entfernen
            // waere die schlechtere Voreinstellung, und alle bestehenden
            // Praeferenzen hier sind ebenfalls `true`.
            DeltiqFormFullRow {
                Toggle(isOn: $deloadEnabled) {
                    Label {
                        Text("settings.deload.toggle", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.down.heart")
                    }
                }
            }
            // DEL-238: Ausweg aus einem laufenden Deload — bewusst UNABHAENGIG
            // vom Toggle oben.
            //
            // Der Schalter darf niemals Trainingsdaten anfassen: ein Toggle,
            // der stillschweigend Arbeitsgewichte ueberschreibt, ist falsch.
            // Umgekehrt darf das Abschalten den Nutzer auch nicht mit
            // reduzierten Gewichten einsperren. Deshalb diese eigene Zeile,
            // sichtbar solange Originale auf ihre Rueckstellung warten.
            //
            // Sie behebt in einem Zug drei Sackgassen: das Abschalten mitten
            // im Deload, das abschaltbare Coaching-Widget (bisher der EINZIGE
            // Weg zu endDeload) und die Alt-Kohorte, deren `deload_until` bei
            // einer Neuinstallation verloren ging.
            if pendingDeloadCount > 0 {
                DeltiqFormFullRow {
                    Button {
                        restoreDeloadWeights()
                    } label: {
                        HStack {
                            Label {
                                Text(String(
                                    format: String(localized: "settings.deload.endNow", bundle: .module),
                                    pendingDeloadCount
                                ))
                            } icon: {
                                Image(systemName: "arrow.uturn.up")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.deltiqOrange)
                }
            }
            if let deloadRestoreMessage {
                DeltiqFormFullRow {
                    Text(deloadRestoreMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("settings.workout.footer", bundle: .module)
                Text("settings.training.rirTooltip.description", bundle: .module)
                Text("settings.deload.description", bundle: .module)
            }
        }
    }

    /// DEL-238: Anzahl Uebungen mit gesichertem Original-Gewicht. Aus den
    /// DATEN abgeleitet, nicht aus `deload_until` — der Timer kann fehlen,
    /// die Snapshots nicht.
    private var pendingDeloadCount: Int {
        DeloadManager.pendingCount(in: modelContext)
    }

    private func restoreDeloadWeights() {
        let restored = (try? DeloadManager.endDeload(in: modelContext)) ?? 0
        guard restored > 0 else { return }
        // Timer mit aufraeumen, sonst zeigt das Dashboard weiter ein Banner
        // fuer einen Deload, den es nicht mehr gibt.
        UserDefaults.standard.removeObject(forKey: "deload_until")
        deloadRestoreMessage = String(localized: "settings.deload.endNow.done", bundle: .module)
    }

    // DEL-018 + DEL-028: Reminder (Wasser-Frequenz + Mess-Wochentag/Uhrzeit).
    // Jede Aenderung triggert `rescheduleReminders()`, das ueber ReminderScheduler
    // re-schedulet — inkl. automatischem Cancel-Plus-Re-Add fuer Spam-Schutz.
    private var remindersSection: some View {
        DeltiqFormSection(header: String(localized: "settings.reminders.section", bundle: .module)) {
            DeltiqFormFullRow {
                Toggle(isOn: $waterReminderEnabled) {
                    Label {
                        Text("settings.reminders.water", bundle: .module)
                    } icon: {
                        Image(systemName: "drop.fill")
                    }
                }
                .onChange(of: waterReminderEnabled) { _, _ in
                    Task { await rescheduleReminders() }
                }
            }
            if waterReminderEnabled {
                DeltiqFormRow(label: String(localized: "settings.reminders.frequency", bundle: .module)) {
                    Picker(selection: $waterReminderHours) {
                        Text("settings.reminders.every1h", bundle: .module).tag(1)
                        Text("settings.reminders.every2h", bundle: .module).tag(2)
                        Text("settings.reminders.every3h", bundle: .module).tag(3)
                        Text("settings.reminders.every4h", bundle: .module).tag(4)
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
                    Label {
                        Text("settings.reminders.measurement", bundle: .module)
                    } icon: {
                        Image(systemName: "scalemass.fill")
                    }
                }
                .onChange(of: measurementReminderEnabled) { _, _ in
                    Task { await rescheduleReminders() }
                }
            }
            if measurementReminderEnabled {
                DeltiqFormRow(label: String(localized: "day.editor.field.weekday", bundle: .module)) {
                    // DEL-120: Locale-aware Weekday-Symbole via Calendar.
                    let weekdaySymbols = Calendar.current.standaloneWeekdaySymbols
                    Picker(selection: $measurementWeekday) {
                        ForEach(1...7, id: \.self) { weekday in
                            Text(weekdaySymbols[weekday - 1]).tag(weekday)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: measurementWeekday) { _, _ in
                        Task { await rescheduleReminders() }
                    }
                }
                DeltiqFormRow(label: String(localized: "settings.reminders.time", bundle: .module)) {
                    Picker(selection: $measurementHour) {
                        ForEach(6..<23, id: \.self) { hour in
                            Text(String(format: String(localized: "settings.reminders.hour", bundle: .module), hour)).tag(hour)
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
            Text("settings.reminders.footer", bundle: .module)
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
        DeltiqFormSection(header: String(localized: "profile.section.health", bundle: .module)) {
            DeltiqFormFullRow {
                healthKitStatusRow
            }
            if healthKit.authorizationStatus == .sharingDenied {
                DeltiqFormFullRow {
                    openIOSSettingsButton
                }
            }
            if let lastSync = healthKit.lastSyncDate {
                DeltiqFormRow(label: String(localized: "settings.health.lastSync", bundle: .module)) {
                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("settings.health.footer", bundle: .module)
        }
    }

    @ViewBuilder
    private var healthKitStatusRow: some View {
        switch healthKit.authorizationStatus {
        case .sharingAuthorized:
            HStack {
                Label {
                    Text("onboarding.health.connected", bundle: .module)
                } icon: {
                    Image(systemName: "heart.fill")
                }
                    .foregroundStyle(.pink)
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
            }
        case .notDetermined:
            HStack {
                Label {
                    Text("settings.health.notSetup", bundle: .module)
                } icon: {
                    Image(systemName: "heart")
                }
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await healthKit.requestAuthorization() }
                } label: {
                    Text("settings.health.connect", bundle: .module)
                }
                .font(.subheadline.weight(.semibold))
                .disabled(!healthKit.isAvailable)
            }
        case .sharingDenied:
            Label {
                Text("settings.health.denied", bundle: .module)
            } icon: {
                Image(systemName: "heart.slash")
            }
                .foregroundStyle(.orange)
        case .unavailable:
            Label {
                Text("settings.health.unavailable", bundle: .module)
            } icon: {
                Image(systemName: "heart.slash")
            }
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
            Label {
                Text("settings.health.openIOSSettings", bundle: .module)
            } icon: {
                Image(systemName: "gear")
            }
        }
        #endif
    }

    // DEL-173: Privacy + Datenportabilität. Nutzer kann seine kompletten
    // Trainings-/Profil-/Mess-Daten als CSV-in-ZIP exportieren — erfüllt
    // DSGVO Art. 20 (Right to Data Portability). Re-Import folgt in einem
    // Folge-Ticket (Phase 2).
    private var privacySection: some View {
        DeltiqFormSection(
            header: String(localized: "settings.section.privacy", bundle: .module)
        ) {
            DeltiqFormFullRow {
                NavigationLink {
                    DataExportView()
                } label: {
                    HStack {
                        Label {
                            Text("settings.privacy.dataExport", bundle: .module)
                        } icon: {
                            Image(systemName: "square.and.arrow.up.on.square")
                        }
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            // DEL-229: Automatische Backup-Generationen (DEL-227/228) sichtbar
            // und wiederherstellbar machen. Steht bewusst VOR dem manuellen
            // Import: im Ernstfall ist "letzten Stand zurueckholen" der Weg,
            // den der User zuerst finden soll — nicht der Datei-Import.
            DeltiqFormFullRow {
                NavigationLink {
                    BackupListView()
                } label: {
                    HStack {
                        Label {
                            Text("settings.privacy.backups", bundle: .module)
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            // DEL-174: Daten-Import (Phase 2). Append-only mit Duplikat-
            // Erkennung — bestehende Daten bleiben unangetastet.
            DeltiqFormFullRow {
                NavigationLink {
                    DataImportView()
                } label: {
                    HStack {
                        Label {
                            Text("settings.privacy.dataImport", bundle: .module)
                        } icon: {
                            Image(systemName: "square.and.arrow.down.on.square")
                        }
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("settings.privacy.footer", bundle: .module)
        }
    }

    private var aboutSection: some View {
        DeltiqFormSection(
            header: String(localized: "settings.section.about", bundle: .module)
        ) {
            DeltiqFormRow(label: String(localized: "settings.about.version", bundle: .module)) {
                Text(appVersion).foregroundStyle(.secondary)
            }
            DeltiqFormRow(label: String(localized: "settings.about.bundle", bundle: .module)) {
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
            Text("settings.dangerZone.footer", bundle: .module)
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
        // DEL-134: isResetting-Gate. Vorher konnten Views, die zwischen
        // dem Navigation-Reset und dem async-deferred Delete neu rendern,
        // auf SwiftData-Objekte zugreifen, die im naechsten Frame
        // verschwinden — Crash mit "Object was deleted from context"
        // / Dangling-Pointer. Der AppStorage-Flag wird VOR der Deletion
        // gesetzt; RootView checkt ihn und rendert eine ProgressView
        // statt MainTabView, sodass keine Views mehr @Query-Resultate
        // beruehren.
        isResetting = true

        // 1) Navigation-State sofort zuruecksetzen — entfernt @Bindable-
        //    References auf gleich-zu-loeschende UserBodyProfile/Plan/Day.
        navigation.workoutPath = NavigationPath()
        navigation.selectedTab = .dashboard

        // 2) AppStorage-Keys sofort wegwerfen (synchron OK, kein Model).
        //    DEL-219: `deload_until` und `lastDataExportAt` kommen dazu. Beide
        //    beschreiben DATEN-Zustand, nicht Praeferenzen — nach einem Wipe
        //    behaupten sie etwas, das es nicht mehr gibt: eine laufende
        //    Deload-Woche (Banner auf einem frischen Account) bzw. ein
        //    Backup, das nie existierte (unterdrueckt den Backup-Hinweis des
        //    Coaches). Echte Praeferenzen (Erscheinungsbild, Coaching-Ton,
        //    Erinnerungen, Chart-Zeitraeume) bleiben absichtlich stehen — der
        //    User loescht seine Daten, nicht seine Einstellungen.
        for key in ["weight_unit", "height_unit", "unit_system",
                    "deload_until", "lastDataExportAt"] {
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
                // DEL-219: Gear fehlte in dieser Sequenz — Schuhe und Raeder
                // (inkl. ihrer Kilometerstaende) haben jeden "Alle Daten
                // loeschen" ueberlebt und tauchten im frischen Onboarding
                // wieder auf. Nach ExerciseLog/WorkoutSession, damit die
                // nullify-Relationship der Sessions schon aufgeloest ist.
                try self.deleteAll(of: Gear.self)
                try self.deleteAll(of: UserBodyProfile.self)
                try self.modelContext.save()
            } catch {
                self.resetErrorMessage = error.localizedDescription
            }
            // DEL-134: Release-Gate immer (Error-Pfad UND Success-Pfad).
            // RootView swappt dann automatisch zur OnboardingView (weil
            // profiles.isEmpty == true) oder zur ErrorView falls die
            // Error-Message gesetzt wurde.
            self.isResetting = false
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

    // DEL-118: route durch die zentrale .localizedName-Extension.
    private func environmentLabel(_ env: EnvironmentType) -> String {
        String(localized: env.localizedName)
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
