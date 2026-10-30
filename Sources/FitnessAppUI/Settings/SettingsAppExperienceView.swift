#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppActivities

/// Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md, Teil 3): Gruppe
/// "App & Trainingserlebnis" — Dashboard-Anpassung, Einheiten,
/// Erscheinungsbild, Timer-Feedback, Workout-Verhalten (inkl. Deload) und
/// Erinnerungen. Reine Verschiebung aus `SettingsView.swift` in eine eigene
/// Gruppen-Seite — Logik, `@AppStorage`-Keys und Verhalten unveraendert.
@available(iOS 17.0, macOS 14.0, *)
public struct SettingsAppExperienceView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PRNotificationCenter.self) private var prNotifications

    @Query private var profiles: [UserBodyProfile]
    /// P7.3: reiner Lesezugriff für die passive "Fällig"-Anzeige an
    /// `fourWeekReviewRow` — siehe `isFourWeekReviewDue`. Dieselbe Kategorie
    /// `@Query` wie `profiles` oben, bereits durch Befund 3
    /// (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md, P7.2) als NICHT ursächlich für
    /// den dort gefundenen Stillstand ausgeschlossen — die eigentliche
    /// Ursache war Befund 9 (zwei unconditional Sibling-NavigationLinks),
    /// nicht `@Query` an sich.
    @Query(filter: #Predicate<TrainingPlan> { $0.isActive == true }) private var activePlans: [TrainingPlan]

    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"
    @AppStorage("pref_appearance") private var appearanceRaw: String = "system"
    @AppStorage("pref_timer_sound") private var timerSoundEnabled: Bool = true
    @AppStorage("pref_timer_haptics") private var timerHapticsEnabled: Bool = true
    @AppStorage("pref_timer_background_audio") private var timerBackgroundAudioEnabled: Bool = true
    @AppStorage("pref_preroll_seconds") private var prerollSeconds: Int = 10
    @AppStorage("pref_pr_celebrations") private var prCelebrationsEnabled: Bool = true
    @AppStorage("pref_water_reminder") private var waterReminderEnabled: Bool = true
    @AppStorage("pref_water_reminder_hours") private var waterReminderHours: Int = 3
    @AppStorage("pref_measurement_reminder") private var measurementReminderEnabled: Bool = true
    @AppStorage("pref_measurement_reminder_weekday") private var measurementWeekday: Int = 1
    @AppStorage("pref_measurement_reminder_hour") private var measurementHour: Int = 8
    @AppStorage("pref_show_warmups") private var showWarmups: Bool = true
    @AppStorage("showRirTooltips") private var showRirTooltips: Bool = true
    @AppStorage("pref_deload_enabled") private var deloadEnabled: Bool = true
    @AppStorage("pref_plateau_detection_enabled") private var plateauDetectionEnabled: Bool = true

    @State private var deloadRestoreMessage: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.group.appExperience", bundle: .module),
                onBack: { dismiss() }
            )
            ScrollView {
                VStack(spacing: 18) {
                    preferencesSection
                    appearanceSection
                    timerFeedbackSection
                    workoutBehaviorSection
                    remindersSection
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
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .deltiqSwipeBackEnabled()
        // Settings-Epic Phase 4 (REM-01): Status BEIM OEFFNEN aktualisieren —
        // reiner Lesezugriff (`refreshAuthorizationStatus`), fragt nie eine
        // Berechtigung an (das macht ausschliesslich `rescheduleReminders()`,
        // ausgeloest durch einen echten Toggle-Tap).
        .task { await prNotifications.refreshAuthorizationStatus() }
        // P7.3: legt bei Bedarf EINMALIG den Beobachtungs-Fallback für
        // aktive Pläne ohne `activatedAt` an (siehe
        // `FourWeekReviewDueStatus`-Dokumentation) — bewusst in einem
        // eigenen, einmaligen `.task` statt in der `isFourWeekReviewDue`-
        // Berechnung selbst, damit die `@Query`-beobachtete `TrainingPlan`-
        // Mutation NIE aus einer `body`-Auswertung heraus passiert (genau
        // die Fehlerklasse, die P6.3/P7.2 bereits zu Render-Endlosschleifen
        // führte).
        .task { FourWeekReviewDueStatus.establishObservationAnchorsIfNeeded(in: modelContext) }
        // ...und nach Rueckkehr aus den Systemeinstellungen — gleiches
        // grobkoerniges, aber bereits im Health-Bereich bewaehrtes Muster
        // (jedes Foregrounding re-checkt, nicht nur ein gezielter "kam von
        // den Settings zurueck"-Fall).
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await prNotifications.refreshAuthorizationStatus() }
        }
    }

    // MARK: Sections

    private var preferencesSection: some View {
        DeltiqSection(String(localized: "settings.section.preferences", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "settings.preferences.units.label", bundle: .module)) {
                Picker(selection: $weightUnitRaw) {
                    Text("settings.preferences.units.metric", bundle: .module).tag("kg")
                    Text("settings.preferences.units.imperial", bundle: .module).tag("lbs")
                } label: { EmptyView() }
                .pickerStyle(.menu)
                .labelsHidden()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityLabel(Text("settings.preferences.units.label", bundle: .module))
            }
            dashboardCustomizationRow
            hintRow(String(localized: "settings.units.footer", bundle: .module))
        }
    }

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

    private var appearanceSection: some View {
        DeltiqSection(String(localized: "settings.appearance.section", bundle: .module).uppercased()) {
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

    private var timerFeedbackSection: some View {
        DeltiqSection(String(localized: "settings.timer.section", bundle: .module).uppercased()) {
            DeltiqControlRow(icon: "speaker.wave.2.fill", label: String(localized: "settings.timer.sound", bundle: .module)) {
                Toggle(isOn: $timerSoundEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.timer.sound", bundle: .module))
            }
            DeltiqControlRow(icon: "iphone.radiowaves.left.and.right", label: String(localized: "settings.timer.haptics", bundle: .module)) {
                Toggle(isOn: $timerHapticsEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.timer.haptics", bundle: .module))
            }
            DeltiqControlRow(icon: "lock.fill", label: String(localized: "settings.timer.backgroundAudio", bundle: .module)) {
                Toggle(isOn: $timerBackgroundAudioEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.timer.backgroundAudio", bundle: .module))
            }
            DeltiqControlRow(
                icon: "trophy.fill",
                label: String(localized: "settings.timer.prCelebrations", bundle: .module)
            ) {
                Toggle(isOn: $prCelebrationsEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.timer.prCelebrations", bundle: .module))
            }
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
                .accessibilityLabel(Text("settings.timer.preroll", bundle: .module))
            }
            hintRow(String(localized: "settings.timer.footer", bundle: .module))
        }
    }

    // P7.2-Nachbesserung: eigene @ViewBuilder-Properties statt zwei direkt
    // nebeneinanderstehender `NavigationLink`s unterschiedlichen Ziel-Typs im
    // selben ViewBuilder-Block — siehe docs/NEUE_SPEZIFIKATION_P0_AUDIT.md,
    // Befund 9 (Gegenprobe 1): das Entfernen eines der beiden Siblings hat
    // den TestingBot-Hang beseitigt. Faktorisierung nach dem bereits
    // funktionierenden Muster von `dashboardCustomizationRow` behebt das,
    // ohne Container/Navigation/Verhalten zu aendern.
    @ViewBuilder
    private var periodicCheckInRow: some View {
        // P6.3: Einstiegspunkt fuer den kurzen, ueberspringbaren Alltags-
        // Rueckblick (Dok03 §4) — eigenstaendige Seite, kein zweiter
        // Start-Check.
        NavigationLink {
            PeriodicCheckInView()
        } label: {
            DeltiqRow(
                icon: "bubble.left.and.text.bubble.right",
                label: String(localized: "settings.periodicCheckIn.row", bundle: .module),
                showsChevron: true
            )
        }
    }

    /// P7.3: rein passive Anzeige — `true`, sobald MINDESTENS EIN aktiver
    /// Plan fällig ist (`FourWeekReviewDueStatus.isAnyDue`, wertet JEDEN
    /// aktiven Plan einzeln aus, keine stillschweigende Auswahl nur eines
    /// Plans). Löst nichts aus, navigiert nichts automatisch — ausdrücklich
    /// kein Snooze/Benachrichtigung in dieser Stufe (Produktentscheidung,
    /// siehe `FourWeekReviewDueCalculator`).
    private var isFourWeekReviewDue: Bool {
        FourWeekReviewDueStatus.isAnyDue(among: activePlans)
    }

    @ViewBuilder
    private var fourWeekReviewRow: some View {
        // P7.2: Manueller Einstiegspunkt fuer den Vier-Wochen-Rueckblick.
        // P7.3 ergaenzt eine rein passive "Fällig"-Anzeige — weiterhin nur
        // ein jederzeit erreichbarer, manueller Zugang, kein automatisches
        // Verhalten.
        NavigationLink {
            FourWeekReviewEntryView()
        } label: {
            DeltiqRow(
                icon: "calendar.badge.clock",
                label: String(localized: "settings.fourWeekReview.row", bundle: .module),
                value: isFourWeekReviewDue ? String(localized: "fourWeekReview.status.due", bundle: .module) : nil,
                showsChevron: true
            )
        }
    }

    private var workoutBehaviorSection: some View {
        DeltiqSection(String(localized: "settings.workout.section", bundle: .module).uppercased()) {
            DeltiqControlRow(icon: "flame.fill", label: String(localized: "settings.workout.showWarmups", bundle: .module)) {
                Toggle(isOn: $showWarmups) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.workout.showWarmups", bundle: .module))
            }
            DeltiqControlRow(icon: "info.circle.fill", label: String(localized: "settings.training.rirTooltip.title", bundle: .module)) {
                Toggle(isOn: $showRirTooltips) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.training.rirTooltip.title", bundle: .module))
            }
            periodicCheckInRow
            fourWeekReviewRow
            DeltiqControlRow(
                icon: "arrow.down.heart",
                label: String(localized: "settings.deload.toggle", bundle: .module),
                showsDivider: pendingDeloadCount > 0 || deloadRestoreMessage != nil
            ) {
                Toggle(isOn: $deloadEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.deload.toggle", bundle: .module))
            }
            DeltiqControlRow(
                icon: "chart.line.flattrend.xyaxis",
                label: String(localized: "settings.plateau.toggle", bundle: .module)
            ) {
                Toggle(isOn: $plateauDetectionEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.plateau.toggle", bundle: .module))
            }
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
                    String(localized: "settings.deload.description", bundle: .module),
                    String(localized: "settings.plateau.description", bundle: .module)
                ].joined(separator: "\n")
            )
        }
    }

    private var pendingDeloadCount: Int {
        DeloadManager.pendingCount(in: modelContext)
    }

    private func restoreDeloadWeights() {
        let restored = (try? DeloadManager.endDeload(in: modelContext)) ?? 0
        guard restored > 0 else { return }
        UserDefaults.standard.removeObject(forKey: "deload_until")
        deloadRestoreMessage = String(localized: "settings.deload.endNow.done", bundle: .module)
    }

    private var remindersSection: some View {
        DeltiqSection(String(localized: "settings.reminders.section", bundle: .module).uppercased()) {
            reminderPermissionStatusRow
            DeltiqControlRow(
                icon: "drop.fill",
                label: String(localized: "settings.reminders.water", bundle: .module),
                showsDivider: waterReminderEnabled
            ) {
                Toggle(isOn: $waterReminderEnabled) { EmptyView() }
                    .tint(Color.deltiqOrange)
                    .accessibilityLabel(Text("settings.reminders.water", bundle: .module))
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
                    .accessibilityLabel(Text("settings.reminders.frequency", bundle: .module))
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
                    .accessibilityLabel(Text("settings.reminders.measurement", bundle: .module))
                    .onChange(of: measurementReminderEnabled) { _, _ in
                        Task { await rescheduleReminders() }
                    }
            }
            if measurementReminderEnabled {
                DeltiqControlRow(label: String(localized: "day.editor.field.weekday", bundle: .module)) {
                    let weekdaySymbols = Calendar.current.standaloneWeekdaySymbols
                    Picker(selection: $measurementWeekday) {
                        ForEach(1...7, id: \.self) { weekday in
                            Text(weekdaySymbols[weekday - 1]).tag(weekday)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityLabel(Text("day.editor.field.weekday", bundle: .module))
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
                    .accessibilityLabel(Text("settings.reminders.time", bundle: .module))
                    .onChange(of: measurementHour) { _, _ in
                        Task { await rescheduleReminders() }
                    }
                }
            }
            hintRow(String(localized: "settings.reminders.footer", bundle: .module))
        }
    }

    /// Settings-Epic Phase 4 (REM-01): zeigt den TATSAECHLICHEN OS-
    /// Benachrichtigungsstatus — unabhaengig von den gespeicherten
    /// App-Praeferenzen (den Toggles unten), die bei verweigerter
    /// Berechtigung bewusst unveraendert und eingeschaltet bleiben koennen
    /// (Vorgabe: Praeferenz und Zustellung sind zwei verschiedene Dinge).
    /// `PRNotificationCenter.isAuthorized` ist bereits die geteilte Quelle
    /// fuer den App-weiten Benachrichtigungsstatus (dieselbe
    /// `UNUserNotificationCenter`-Berechtigung wie PR-Celebrations) — keine
    /// zweite Status-Abfrage noetig. `.provisional`/`.ephemeral` zaehlen dort
    /// bereits korrekt als "erlaubt" (leise Zustellung ist fuer einen
    /// Wasser-/Mess-Reminder kein Unterschied, der eine eigene UI-Stufe
    /// braucht).
    @ViewBuilder
    private var reminderPermissionStatusRow: some View {
        switch NotificationPermissionDisplayState(isAuthorized: prNotifications.isAuthorized) {
        case .granted:
            DeltiqControlRow(
                icon: "bell.badge",
                label: String(localized: "settings.reminders.permission.granted", bundle: .module)
            ) {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.Deltiq.success)
            }
        case .denied:
            VStack(alignment: .leading, spacing: 0) {
                DeltiqControlRow(
                    icon: "bell.slash",
                    label: String(localized: "settings.reminders.permission.denied", bundle: .module),
                    showsDivider: false
                ) {
                    EmptyView()
                }
                hintRow(String(localized: "settings.reminders.permission.deniedHint", bundle: .module))
                #if os(iOS)
                Button {
                    AppSettingsLink.open()
                } label: {
                    DeltiqRow(
                        icon: "gearshape",
                        label: String(localized: "settings.reminders.permission.openSettings", bundle: .module),
                        showsDivider: false
                    )
                }
                .buttonStyle(.plain)
                #endif
            }
        case .notDetermined:
            DeltiqControlRow(
                icon: "bell",
                label: String(localized: "settings.reminders.permission.notDetermined", bundle: .module),
                showsDivider: false
            ) {
                EmptyView()
            }
        }
    }

    private func rescheduleReminders() async {
        if waterReminderEnabled || measurementReminderEnabled {
            await prNotifications.refreshAuthorizationStatus()
            if prNotifications.isAuthorized == nil {
                _ = await prNotifications.requestAuthorization()
            }
        }
        if waterReminderEnabled {
            await ReminderScheduler.scheduleWaterReminders(everyHours: waterReminderHours)
        } else {
            await ReminderScheduler.cancelWaterReminders()
        }
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
}
#endif
