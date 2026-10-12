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
    /// Zeitformat-Laeufe (AMRAP/EMOM/Auf Zeit/Zirkel) bei gesperrtem Bildschirm oder
    /// in einer anderen App weiterlaufen lassen: stilles Hintergrund-Audio haelt die
    /// App am Leben, damit Signaltoene erklingen und die Live Activity aktuell
    /// bleibt (siehe `BackgroundAudioKeepAlive`). Gelesen ueber
    /// `TimedWorkoutBackground.audioPreferenceEnabled()`, Standard: an.
    @AppStorage("pref_timer_background_audio") private var timerBackgroundAudioEnabled: Bool = true
    /// README 2.15/23b-23c: Laenge der Vorlauf-Phase vor AMRAP/EMOM/Auf-Zeit-
    /// Laeufen, global fuer alle drei Player (kein Pro-Tag-Override - die
    /// gleiche Begruendung wie bei den anderen Timer-Feedback-Prefs hier:
    /// ein Wert, ueberall wirksam). 0 = deaktiviert, entspricht dem
    /// bisherigen Verhalten ohne Vorlauf.
    @AppStorage("pref_preroll_seconds") private var prerollSeconds: Int = 10
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

    /// Automatischer Import von Lauf-/Rad-Workouts, die eine ANDERE App
    /// (z.B. Adidas Running) nach Apple Health geschrieben hat. Bewusst ein
    /// eigener Toggle statt an `healthKit.authorizationStatus` gekoppelt. Der
    /// Zugriff wird ueber `requestWorkoutReadAuthorization` angefragt: "Trainings"
    /// immer fuer Schreiben UND Lesen zusammen und nur, wenn iOS ueberhaupt noch
    /// fragen wuerde (sonst kein Dialog und keine Aenderung einer vorhandenen
    /// Freigabe).
    @AppStorage("pref_healthkit_workout_import") private var externalWorkoutImportEnabled: Bool = false

    /// Kraft-/Cardio-Schalter des Schreibens nach Apple Health (Vorgaben aus
    /// Core). Hier nur fuer den Wert der Zeile "Trainings in Health" gelesen —
    /// bearbeitet wird in `HealthWorkoutWriteView`; als `@AppStorage`, damit die
    /// Zeile nach der Rueckkehr sofort den neuen Stand zeigt.
    @AppStorage(HealthWritePreferences.strengthEnabledKey)
    private var healthWriteStrengthEnabled: Bool = HealthWritePreferences.defaultStrengthEnabled
    @AppStorage(HealthWritePreferences.cardioEnabledKey)
    private var healthWriteCardioEnabled: Bool = HealthWritePreferences.defaultCardioEnabled

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
        // DEL-104, umgestellt auf Signature-Geruest: ScrollView +
        // DeltiqSection statt DeltiqFormSection - Letzteres ist inzwischen
        // komplett entfernt (Theme/DeltiqFormSection.swift), nachdem auch
        // DataExportView/DataImportView auf DeltiqSection migriert wurden.
        // Settings hat keine Text-Inputs, daher genuegt
        // `scrollDismissesKeyboard(.interactively)` als defensiver Default —
        // kein FocusState-Tracking noetig.
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.title", bundle: .module)
            )

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
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        // Signature-Geruest: eigene DeltiqHeader-Kopfzone ersetzt die native
        // Navigationsleiste - dieser Ausblend-Aufruf fehlte bislang komplett
        // (im Gegensatz zu allen anderen umgestellten Screens), wodurch auf
        // iOS eine leere native Leiste zusaetzlich zur DeltiqHeader gerendert
        // wurde.
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
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
        DeltiqSection(String(localized: "settings.section.profile_goals", bundle: .module).uppercased()) {
            profileSectionContent
        }
    }

    @ViewBuilder
    private var profileSectionContent: some View {
        if let profile = profiles.first {
            NavigationLink {
                ProfileEditorView(profile: profile)
            } label: {
                DeltiqRow(
                    icon: "person.crop.circle",
                    label: profileHeadline(profile),
                    subtitle: profileSubtitle(profile),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        } else {
            DeltiqRow(
                label: String(localized: "settings.profile.missing", bundle: .module),
                showsDivider: false
            )
        }
    }

    private func profileHeadline(_ profile: UserBodyProfile) -> String {
        let sex = String(localized: profile.profile == .male ? "sex.male" : "sex.female", bundle: .module)
        let years = String(format: String(localized: "settings.profile.years", bundle: .module), ageYears(for: profile))
        return "\(sex) • \(years)"
    }

    private func profileSubtitle(_ profile: UserBodyProfile) -> String {
        var parts = [formattedHeight(profile.heightCm)]
        if let goal = profile.goalWeightKg {
            parts.append(String(format: String(localized: "settings.profile.goal", bundle: .module), formattedWeight(goal)))
        }
        parts.append(environmentLabel(profile.environment))
        return parts.joined(separator: " • ")
    }

    /// DEL-109: Reusable Nav-Row für die Dashboard-Customization. Wird in
    /// `preferencesSection` als zweite Row gerendert, damit's nicht eine
    /// eigene Section mit dupliziertem Header bekommt.
    @ViewBuilder
    private var dashboardCustomizationRow: some View {
        if let profile = profiles.first {
            NavigationLink {
                DashboardSettingsView(profile: profile)
            } label: {
                DeltiqRow(
                    icon: "rectangle.3.group",
                    label: String(localized: "dashboardSettings.entry.title", bundle: .module),
                    subtitle: String(localized: "dashboardSettings.entry.subtitle", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        }
    }

    private var preferencesSection: some View {
        DeltiqSection(String(localized: "settings.section.preferences", bundle: .module).uppercased()) {
            // Kein sinnvolles Symbol fuer eine reine Einheiten-Wahl (Handoff
            // 2.4: Zeilen ohne Icon ruecken den Text auf den normalen Rand).
            DeltiqControlRow(label: String(localized: "settings.preferences.units.label", bundle: .module)) {
                Picker(selection: $weightUnitRaw) {
                    Text("settings.preferences.units.metric", bundle: .module).tag("kg")
                    Text("settings.preferences.units.imperial", bundle: .module).tag("lbs")
                } label: { EmptyView() }
                .pickerStyle(.menu)
                .labelsHidden()
                // DEL-119: i18n-bedingter Layout-Bug. "Metrisch (kg/cm)"
                // sprengte auf iPhone-SE / kompakten Width-Class das
                // Zeilen-Limit und brach um — sieht in Settings unschoen
                // aus. lineLimit(1) verhindert den Bruch,
                // minimumScaleFactor(0.8) verkleinert die Schrift dezent
                // bei Bedarf, statt zu truncaten. Pragmatisches i18n-
                // Sicherheitsnetz (gilt auch fuer kuenftige Sprachen).
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            // DEL-161: Globale Uebungsbibliothek.
            NavigationLink {
                ExerciseLibraryView()
            } label: {
                DeltiqRow(
                    icon: "figure.strengthtraining.traditional",
                    label: String(localized: "settings.preferences.exerciseLibrary", bundle: .module),
                    showsChevron: true
                )
            }
            // DEL-084: Equipment-Tracker (Laufschuhe etc.) Submenu.
            NavigationLink {
                GearListView()
            } label: {
                DeltiqRow(
                    icon: "shoe",
                    label: String(localized: "settings.preferences.gear", bundle: .module),
                    showsChevron: true
                )
            }
            // DEL-109: Dashboard-Widget-Manager.
            dashboardCustomizationRow
            hintRow(String(localized: "settings.units.footer", bundle: .module))
        }
    }

    /// Abschnitt 1.6: Hinweistext unter einer Zeile, wie es bereits
    /// `DeltiqFormSection`s Footer-Slot vorsah — nur jetzt IN der Karte
    /// als letzte Zeile statt darunter. 12pt, sekundaerer Text, keine
    /// Trennlinie darueber.
    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // DEL-018: Theme-Picker
    private var appearanceSection: some View {
        DeltiqSection(String(localized: "settings.appearance.section", bundle: .module).uppercased()) {
            // Handoff 2.4: Systemgrau-Segment -> aktives Segment Orange mit
            // #1A1A1A-Schrift. DeltiqSegmentedPicker spannt die ganze Row,
            // eigenes Padding statt DeltiqRow/DeltiqControlRow.
            DeltiqSegmentedPicker(
                options: [
                    DeltiqSegmentedOption("system", label: String(localized: "settings.appearance.system", bundle: .module)),
                    DeltiqSegmentedOption("light", label: String(localized: "settings.appearance.light", bundle: .module)),
                    DeltiqSegmentedOption("dark", label: String(localized: "settings.appearance.dark", bundle: .module))
                ],
                selection: $appearanceRaw
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            hintRow(String(localized: "settings.appearance.footer", bundle: .module))
        }
    }

    // DEL-018: Timer-Feedback (Ton + Vibration beim Pause-Ende)
    private var timerFeedbackSection: some View {
        DeltiqSection(String(localized: "settings.timer.section", bundle: .module).uppercased()) {
            DeltiqControlRow(icon: "speaker.wave.2.fill", label: String(localized: "settings.timer.sound", bundle: .module)) {
                Toggle(isOn: $timerSoundEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
            }
            DeltiqControlRow(icon: "iphone.radiowaves.left.and.right", label: String(localized: "settings.timer.haptics", bundle: .module)) {
                Toggle(isOn: $timerHapticsEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
            }
            // Zeitformate im Hintergrund: Ton + Live Activity bei gesperrtem Bildschirm.
            DeltiqControlRow(icon: "lock.fill", label: String(localized: "settings.timer.backgroundAudio", bundle: .module)) {
                Toggle(isOn: $timerBackgroundAudioEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
            }
            // DEL-078: PR-Celebrations on/off. Separat vom Timer-Feedback.
            DeltiqControlRow(
                icon: "trophy.fill",
                label: String(localized: "settings.timer.prCelebrations", bundle: .module)
            ) {
                Toggle(isOn: $prCelebrationsEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
            }
            // README 2.15/23b-23c: Vorlauf-Laenge vor Zeitformat-Laeufen -
            // Picker statt Toggle, weil vier Werte (aus/5/10/15s) statt zwei.
            DeltiqControlRow(
                icon: "timer",
                label: String(localized: "settings.timer.preroll", bundle: .module),
                showsDivider: false
            ) {
                Picker(selection: $prerollSeconds) {
                    Text("settings.timer.preroll.off", bundle: .module).tag(0)
                    Text("settings.timer.preroll.5s", bundle: .module).tag(5)
                    Text("settings.timer.preroll.10s", bundle: .module).tag(10)
                    Text("settings.timer.preroll.15s", bundle: .module).tag(15)
                } label: { EmptyView() }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            hintRow(String(localized: "settings.timer.footer", bundle: .module))
        }
    }

    // DEL-092: Workout-Verhalten — globaler Opt-out fuer Warmup-/Cooldown-
    // Uebungen. Filterung geschieht in `ActiveWorkoutView.orderedExercises`,
    // der gleiche Toggle wird dort via `@AppStorage("pref_show_warmups")`
    // gelesen — keine Notification-Plumbing noetig.
    private var workoutBehaviorSection: some View {
        DeltiqSection(String(localized: "settings.workout.section", bundle: .module).uppercased()) {
            DeltiqControlRow(icon: "flame.fill", label: String(localized: "settings.workout.showWarmups", bundle: .module)) {
                Toggle(isOn: $showWarmups) { EmptyView() }
                    .tint(Color.deltiqOrange)
            }
            // DEL-143: RIR-Tooltip-Toggle. Default true (per Ticket-Spec).
            // Power-User können den Bloop ausschalten, dann werden RIR-
            // Slider stumm bedient wie vorher.
            DeltiqControlRow(icon: "info.circle.fill", label: String(localized: "settings.training.rirTooltip.title", bundle: .module)) {
                Toggle(isOn: $showRirTooltips) { EmptyView() }
                    .tint(Color.deltiqOrange)
            }
            // DEL-238: Deload-Automatik abschaltbar. Default AN — ein
            // ausgeliefertes Feature bei Bestandsnutzern still zu entfernen
            // waere die schlechtere Voreinstellung, und alle bestehenden
            // Praeferenzen hier sind ebenfalls `true`.
            DeltiqControlRow(
                icon: "arrow.down.heart",
                label: String(localized: "settings.deload.toggle", bundle: .module),
                showsDivider: pendingDeloadCount > 0 || deloadRestoreMessage != nil
            ) {
                Toggle(isOn: $deloadEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
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
                Button {
                    restoreDeloadWeights()
                } label: {
                    DeltiqRow(
                        icon: "arrow.uturn.up",
                        label: String(
                            format: String(localized: "settings.deload.endNow", bundle: .module),
                            pendingDeloadCount
                        ),
                        showsDivider: deloadRestoreMessage != nil
                    )
                }
                .buttonStyle(.plain)
            }
            if let deloadRestoreMessage {
                Text(deloadRestoreMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Deltiq.success)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            hintRow(
                [
                    String(localized: "settings.workout.footer", bundle: .module),
                    String(localized: "settings.training.rirTooltip.description", bundle: .module),
                    String(localized: "settings.deload.description", bundle: .module)
                ].joined(separator: "\n")
            )
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
        DeltiqSection(String(localized: "settings.reminders.section", bundle: .module).uppercased()) {
            DeltiqControlRow(
                icon: "drop.fill",
                label: String(localized: "settings.reminders.water", bundle: .module),
                showsDivider: waterReminderEnabled
            ) {
                Toggle(isOn: $waterReminderEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .onChange(of: waterReminderEnabled) { _, _ in
                        Task { await rescheduleReminders() }
                    }
            }
            if waterReminderEnabled {
                DeltiqControlRow(label: String(localized: "settings.reminders.frequency", bundle: .module)) {
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

            DeltiqControlRow(
                icon: "scalemass.fill",
                label: String(localized: "settings.reminders.measurement", bundle: .module),
                showsDivider: measurementReminderEnabled
            ) {
                Toggle(isOn: $measurementReminderEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .onChange(of: measurementReminderEnabled) { _, _ in
                        Task { await rescheduleReminders() }
                    }
            }
            if measurementReminderEnabled {
                DeltiqControlRow(label: String(localized: "day.editor.field.weekday", bundle: .module)) {
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
                DeltiqControlRow(
                    label: String(localized: "settings.reminders.time", bundle: .module),
                    showsDivider: false
                ) {
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
            hintRow(String(localized: "settings.reminders.footer", bundle: .module))
        }
    }

    /// Wendet alle Reminder-Praeferenzen via ReminderScheduler auf das System
    /// an. Triggert bei jedem Toggle/Picker-Wechsel. Cold-Start, Onboarding und
    /// Imports gleichen die Schedules ueber `ReminderPreferencesApplier` ab
    /// (RootView, OnboardingView, DataImportView) — das hier frueher genannte
    /// SettingsView-`.task` gab es nie, weshalb Erinnerungen nach dem
    /// Onboarding nicht geplant wurden.
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
        DeltiqSection(String(localized: "profile.section.health", bundle: .module).uppercased()) {
            healthKitStatusRow
            if healthKit.authorizationStatus == .sharingDenied {
                openHealthAppButton
            }
            if let lastSync = healthKit.lastSyncDate {
                DeltiqControlRow(
                    label: String(localized: "settings.health.lastSync", bundle: .module)
                ) {
                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
            }
            // Automatischer Import von Fremd-App-Workouts (Adidas Running,
            // Strava, ...) aus Apple Health. Eigener Toggle statt an den
            // healthKitStatusRow-State gekoppelt, siehe Kommentar an der
            // AppStorage-Deklaration oben.
            DeltiqControlRow(
                icon: "figure.run.circle",
                label: String(localized: "settings.health.workoutImport", bundle: .module),
                showsDivider: healthKit.isAvailable
            ) {
                Toggle(isOn: $externalWorkoutImportEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .disabled(!healthKit.isAvailable)
                    .onChange(of: externalWorkoutImportEnabled) { _, enabled in
                        guard enabled else { return }
                        Task {
                            await healthKit.requestWorkoutReadAuthorization()
                            await ExternalWorkoutImportService.syncExternalWorkouts(
                                healthKit: healthKit,
                                context: modelContext
                            )
                        }
                    }
            }
            // Trainings nach Apple Health schreiben + frueheren Verlauf
            // exportieren. Eigene Zeile statt Teil des Verbinden-Flows:
            // Bestandsnutzer sehen "Verbinden" nie wieder und koennen die
            // Trainings-Freigabe nur hier nachholen.
            if healthKit.isAvailable {
                NavigationLink {
                    HealthWorkoutWriteView()
                } label: {
                    DeltiqRow(
                        icon: "heart.text.square",
                        label: String(localized: "settings.healthWrite.row", bundle: .module),
                        value: healthWriteValue,
                        showsChevron: true,
                        showsDivider: false
                    )
                }
            }
            hintRow(
                [
                    String(localized: "settings.health.footer", bundle: .module),
                    String(localized: "settings.health.workoutImport.footer", bundle: .module)
                ].joined(separator: "\n")
            )
        }
    }

    /// Zustand der Zeile "Trainings in Health": nicht freigegeben / aus /
    /// Kraft / Kraft + Cardio.
    private var healthWriteValue: String {
        guard healthKit.workoutWriteAuthorization.workout == .sharingAuthorized else {
            return String(localized: "settings.healthWrite.valueNoAccess", bundle: .module)
        }
        switch (healthWriteStrengthEnabled, healthWriteCardioEnabled) {
        case (true, true):
            return String(localized: "settings.healthWrite.valueBoth", bundle: .module)
        case (true, false):
            return String(localized: "settings.healthWrite.valueStrength", bundle: .module)
        case (false, true):
            return String(localized: "settings.healthWrite.valueCardio", bundle: .module)
        case (false, false):
            return String(localized: "settings.healthWrite.valueOff", bundle: .module)
        }
    }

    /// Anders als der explizite Health-Rot-Hinweis in Messung (2.5, dort
    /// vom Handoff ausdruecklich als Fremdmarken-Ausnahme erlaubt) ist das
    /// bisherige Pink hier nur eine System-Farbwahl ohne Erwaehnung im
    /// Handoff - faellt daher unter die normale 1.7-Regel und wird Orange
    /// wie jede andere Zeile.
    @ViewBuilder
    private var healthKitStatusRow: some View {
        switch healthKit.authorizationStatus {
        case .sharingAuthorized:
            DeltiqControlRow(icon: "heart.fill", label: String(localized: "onboarding.health.connected", bundle: .module)) {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.Deltiq.success)
            }
        case .notDetermined:
            DeltiqControlRow(icon: "heart", label: String(localized: "settings.health.notSetup", bundle: .module)) {
                Button {
                    Task { await healthKit.requestAuthorization() }
                } label: {
                    Text("settings.health.connect", bundle: .module)
                }
                .font(.system(size: 14, weight: .semibold))
                .tint(Color.deltiqOrange)
                .disabled(!healthKit.isAvailable)
            }
        case .sharingDenied:
            DeltiqControlRow(icon: "heart.slash", label: String(localized: "settings.health.denied", bundle: .module)) {
                EmptyView()
            }
        case .unavailable:
            DeltiqControlRow(icon: "heart.slash", label: String(localized: "settings.health.unavailable", bundle: .module), showsDivider: false) {
                EmptyView()
            }
        }
    }

    /// Die Health-Berechtigungen einer App stehen in der Health-App (Profil →
    /// Apps → Deltiq), nicht auf der iOS-Einstellungsseite von Deltiq.
    @ViewBuilder
    private var openHealthAppButton: some View {
        #if os(iOS)
        Button {
            HealthAppLink.open()
        } label: {
            DeltiqRow(icon: "heart.text.square", label: String(localized: "settings.healthWrite.openHealthApp", bundle: .module), showsDivider: false)
        }
        .buttonStyle(.plain)
        #endif
    }

    // DEL-173: Privacy + Datenportabilität. Nutzer kann seine kompletten
    // Trainings-/Profil-/Mess-Daten als CSV-in-ZIP exportieren — erfüllt
    // DSGVO Art. 20 (Right to Data Portability). Re-Import folgt in einem
    // Folge-Ticket (Phase 2).
    private var privacySection: some View {
        DeltiqSection(String(localized: "settings.section.privacy", bundle: .module).uppercased()) {
            NavigationLink {
                DataExportView()
            } label: {
                DeltiqRow(
                    icon: "square.and.arrow.up.on.square",
                    label: String(localized: "settings.privacy.dataExport", bundle: .module),
                    showsChevron: true
                )
            }
            // DEL-229: Automatische Backup-Generationen (DEL-227/228) sichtbar
            // und wiederherstellbar machen. Steht bewusst VOR dem manuellen
            // Import: im Ernstfall ist "letzten Stand zurueckholen" der Weg,
            // den der User zuerst finden soll — nicht der Datei-Import.
            NavigationLink {
                BackupListView()
            } label: {
                DeltiqRow(
                    icon: "clock.arrow.circlepath",
                    label: String(localized: "settings.privacy.backups", bundle: .module),
                    showsChevron: true
                )
            }
            // DEL-174: Daten-Import (Phase 2). Append-only mit Duplikat-
            // Erkennung — bestehende Daten bleiben unangetastet.
            NavigationLink {
                DataImportView()
            } label: {
                DeltiqRow(
                    icon: "square.and.arrow.down.on.square",
                    label: String(localized: "settings.privacy.dataImport", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
            hintRow(String(localized: "settings.privacy.footer", bundle: .module))
        }
    }

    private var aboutSection: some View {
        DeltiqSection(String(localized: "settings.section.about", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "settings.about.version", bundle: .module)) {
                Text(appVersion)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            DeltiqControlRow(label: String(localized: "settings.about.bundle", bundle: .module)) {
                Text(bundleIdentifier)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            NavigationLink {
                ExerciseMediaCreditsView()
            } label: {
                DeltiqRow(
                    icon: "photo.on.rectangle.angled",
                    label: String(localized: "settings.about.exerciseMediaCredit", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        }
    }

    private var dangerZoneSection: some View {
        DeltiqSection(String(localized: "settings.section.danger_zone", bundle: .module).uppercased()) {
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
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Deltiq.error)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            hintRow(String(localized: "settings.dangerZone.footer", bundle: .module))
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

        // Ein laufender Zeitformat-Lauf (stilles Hintergrund-Audio + Live Activity)
        // hat danach keinen Player mehr, der ihn beendete - nach einem Tab-Wechsel
        // kam bei dessen Abbau auch kein `onDisappear` mehr. Hier explizit beenden.
        TimedWorkoutBackground.shared.endAll()

        // 1) Navigation-State sofort zuruecksetzen — entfernt @Bindable-
        //    References auf gleich-zu-loeschende UserBodyProfile/Plan/Day.
        // Bugfix (Audit): `toolsPath` fehlte hier - ohne Reset konnte der
        // Werkzeuge-Tab nach einem Reset in einer veralteten Detail-Ansicht
        // (z.B. Wassertracker) statt der Uebersicht landen, weil
        // `AppNavigation` als langlebiges @State den Onboarding<->Main-Swap
        // ueberlebt.
        navigation.workoutPath = NavigationPath()
        navigation.toolsPath = NavigationPath()
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
        // DEL-239: Die beiden Absenz-Deload-Keys sind DATEN-Zustand (wann
        // wurde reduziert, bei welcher Luecke wurde abgelehnt) und gehoeren
        // damit hierher — nicht in die SettingsPortability-Whitelist. Nach
        // einem Wipe gibt es keine Trainings-Historie mehr, also auch keine
        // Absenz, auf die sie sich beziehen koennten.
        for key in ["weight_unit", "height_unit", "unit_system",
                    "deload_until", "lastDataExportAt",
                    AbsenceDeload.lastAppliedKey, AbsenceDeload.suppressedUntilGapKey] {
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
                // Die System-Uebungsbibliothek gehoert zum frischen Zustand:
                // RootView seedet sie nur beim App-START, ohne das blieben
                // Bibliothek und Uebungs-Picker bis zum naechsten Neustart
                // leer (auch im Onboarding direkt nach dem Reset). `try?`
                // mit Absicht: Das Zuruecksetzen selbst ist gelungen, und
                // scheitert nur das Speichern der Bibliothek, seedet
                // RootView.task sie beim naechsten Start nach.
                _ = LibrarySeeder.seedIfNeeded(in: self.modelContext)
                try? self.modelContext.save()
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
