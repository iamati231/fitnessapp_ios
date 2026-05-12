#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth
import FitnessAppActivities

/// First-launch profile setup as a three-step wizard:
///   1. **Apple Health verbinden** — optional Pre-Fill von Alter / Geschlecht /
///      Größe / Gewicht aus dem HK-Profil. User kann komplett überspringen.
///   2. **Persönliche Daten** — Sex / Geburtsdatum / Größe / aktuelles Gewicht
///      (Pflicht) / Zielgewicht / Trainingsort. Werte sind vorbefüllt aus
///      Schritt 1, soweit HealthKit was lieferte.
///   3. **Präferenzen + Startplan** — Toggle für Wasser- und Mess-Reminder
///      (opt-in für Local Notifications) und Auswahl eines Trainingsplan-
///      Templates (optional, "Später" möglich).
///
/// Am Ende:
///   - `UserBodyProfile` wird inserted
///   - Initial `BodyMeasurement` mit dem aktuellen Gewicht (+ derived metrics)
///   - Reminder-Präferenzen in `@AppStorage`; Notification-Permission wird
///     angefragt, wenn mindestens ein Toggle aktiv
///   - Wenn ein Plan gewählt: `ProgramInstantiator` materialisiert ihn als
///     aktiven `TrainingPlan`
///
/// `RootView`'s @Query auf UserBodyProfile löst beim Insert den Wechsel zu
/// MainTabView aus — keine explizite Navigation nach Onboarding-Finish nötig.
@available(iOS 17.0, macOS 14.0, *)
public struct OnboardingView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitController.self) private var healthKit
    @Environment(PRNotificationCenter.self) private var prNotifications

    enum Step: Int, CaseIterable {
        case healthConnect
        case personalInfo
        case preferencesAndPlan
    }

    @State private var step: Step = .healthConnect

    // Step 1 / 2 — Persönliche Daten
    @State private var profileSex: BodyFormulaProfile = .male
    @State private var birthDate: Date = Self.defaultBirthDate
    @State private var heightCm: Double?
    @State private var currentWeightKg: Double?
    @State private var goalWeightKg: Double?
    @State private var environment: EnvironmentType = .gym

    // Step 1 — Tracking ob HealthKit-Snapshot schon angefordert wurde
    @State private var healthKitFetchInProgress: Bool = false
    @State private var healthKitDataLoaded: Bool = false

    // Step 3 — Präferenzen + Plan
    @State private var enableWaterReminder: Bool = true
    @State private var enableMeasurementReminder: Bool = true
    @State private var selectedTemplate: ProgramTemplate?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                Divider()

                Group {
                    switch step {
                    case .healthConnect:      healthConnectStep
                    case .personalInfo:       personalInfoStep
                    case .preferencesAndPlan: preferencesAndPlanStep
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: step)

                Divider()

                stepNavigationBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .navigationTitle(Text("onboarding.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .keyboardDismissToolbar()
        }
    }

    // MARK: - Progress indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 1: HealthKit-Connect

    @ViewBuilder
    private var healthConnectStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.pink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple Health verbinden")
                        .font(.title2.weight(.bold))
                    Text("Wenn du Apple Health verbindest, ziehe ich Alter, Geschlecht, Größe und aktuelles Gewicht aus deinem Profil — du musst es nicht doppelt tippen. Du kannst diesen Schritt auch überspringen und alles manuell eingeben.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !healthKit.isAvailable {
                    Label("Apple Health ist auf diesem Gerät nicht verfügbar.",
                          systemImage: "heart.slash")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    healthKitActionRow
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var healthKitActionRow: some View {
        switch healthKit.authorizationStatus {
        case .sharingAuthorized:
            VStack(alignment: .leading, spacing: 12) {
                Label("Verbunden", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(.pink)

                if healthKitDataLoaded {
                    Text("Daten übernommen — du kannst sie im nächsten Schritt prüfen und anpassen.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task { await pullHealthKitSnapshot() }
                    } label: {
                        if healthKitFetchInProgress {
                            HStack { ProgressView(); Text("Lade …") }
                        } else {
                            Label("Daten aus Apple Health übernehmen", systemImage: "arrow.down.circle")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(healthKitFetchInProgress)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pink.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .notDetermined:
            Button {
                Task {
                    await healthKit.requestAuthorization()
                    // Direkt nach der Authorization den Snapshot ziehen.
                    if healthKit.authorizationStatus == .sharingAuthorized {
                        await pullHealthKitSnapshot()
                    }
                }
            } label: {
                Label("Apple Health verbinden", systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .sharingDenied:
            Label("Apple Health-Berechtigung verweigert. Du kannst sie später in iOS-Einstellungen → Datenschutz → Apple Health → Deltiq aktivieren.",
                  systemImage: "heart.slash")
                .font(.callout)
                .foregroundStyle(.orange)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))

        case .unavailable:
            EmptyView()
        }
    }

    // MARK: - Step 2: Persönliche Daten

    @ViewBuilder
    private var personalInfoStep: some View {
        Form {
            Section {
                Picker(selection: $profileSex) {
                    ForEach([BodyFormulaProfile.male, .female], id: \.self) { sex in
                        Text(sex.localizedName).tag(sex)
                    }
                } label: {
                    Text("onboarding.field.sex", bundle: .module)
                }
                .pickerStyle(.segmented)

                DatePicker(
                    selection: $birthDate,
                    in: Self.minBirthDate ... Date(),
                    displayedComponents: .date
                ) {
                    Text("onboarding.field.birthdate", bundle: .module)
                }
            } header: {
                Text("onboarding.section.profile", bundle: .module)
            }

            Section {
                decimalField("Größe (cm)", value: $heightCm)
                decimalField("Aktuelles Gewicht (kg)", value: $currentWeightKg)
            } header: {
                Text("Körperdaten")
            } footer: {
                if let weight = currentWeightKg, weight <= 0 {
                    Text("Gewicht muss > 0 sein.")
                        .foregroundStyle(.red)
                } else if currentWeightKg == nil {
                    Text("Pflichtfeld — wird als erste Messung gespeichert.")
                        .font(.footnote)
                } else {
                    Text("Wird im Hintergrund als initiale Messung gespeichert.")
                        .font(.footnote)
                }
            }

            Section {
                decimalField("Zielgewicht (kg, optional)", value: $goalWeightKg)
                Picker(selection: $environment) {
                    ForEach(EnvironmentType.allCases, id: \.self) { env in
                        Text(env.localizedName).tag(env)
                    }
                } label: {
                    Text("onboarding.field.environment", bundle: .module)
                }
            } header: {
                Text("onboarding.section.goals", bundle: .module)
            } footer: {
                Text("Trainingsort filtert später Plan-Empfehlungen und die Equipment-Auswahl beim Übungs-Tausch.")
                    .font(.footnote)
            }
        }
    }

    // MARK: - Step 3: Präferenzen + Plan

    @ViewBuilder
    private var preferencesAndPlanStep: some View {
        Form {
            Section {
                Toggle(isOn: $enableWaterReminder) {
                    Label("Wasser-Erinnerung", systemImage: "drop.fill")
                }
                Toggle(isOn: $enableMeasurementReminder) {
                    Label("Mess-Erinnerung", systemImage: "scalemass.fill")
                }
            } header: {
                Text("Benachrichtigungen")
            } footer: {
                Text("Beide nutzen lokale Notifications. Wenn du sie aktivierst, fragt iOS einmalig nach der Notification-Berechtigung.")
                    .font(.footnote)
            }

            Section {
                if filteredTemplates.isEmpty {
                    Text("Keine Templates für '\(environment.localizedName)'. Du kannst trotzdem ohne Plan starten und später einen eigenen anlegen.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredTemplates) { template in
                        Button {
                            // Toggle-Verhalten: erneut tippen deselektiert.
                            selectedTemplate = (selectedTemplate?.id == template.id) ? nil : template
                        } label: {
                            templateRow(template)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Trainingsplan für \(environment.localizedName)")
            } footer: {
                Text("Templates sind nach deinem Trainingsort gefiltert (\(environment.localizedName)) — passende Bodyweight-Pläne für 'Ohne Equipment', Hantel-/Maschinen-Pläne für 'Gym'. Optional — auch ohne Plan starten ist okay.")
                    .font(.footnote)
            }
        }
    }

    /// Templates passend zum gewaehlten Trainingsort.
    ///   - `.gym`: alle Templates (Vollgym hat alles, was alle anderen brauchen)
    ///   - `.homeGym`: homeGym + noEquipment (Bodyweight-Sachen gehen ueberall)
    ///   - `.noEquipment`: strikt nur noEquipment-Templates (sonst landet der
    ///     User in einem Plan, fuer den ihm das Equipment fehlt)
    private var filteredTemplates: [ProgramTemplate] {
        ProgramTemplates.all.filter { template in
            switch environment {
            case .gym:
                return true
            case .homeGym:
                return template.targetEnvironment == .homeGym
                    || template.targetEnvironment == .noEquipment
            case .noEquipment:
                return template.targetEnvironment == .noEquipment
            }
        }
    }

    private func templateRow(_ template: ProgramTemplate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconSystemName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.body.weight(.semibold))
                Text(template.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selectedTemplate?.id == template.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
    }

    // MARK: - Navigation buttons

    @ViewBuilder
    private var stepNavigationBar: some View {
        HStack {
            if step != .healthConnect {
                Button("Zurück") {
                    goToPreviousStep()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button {
                handlePrimaryAction()
            } label: {
                Label(primaryActionTitle, systemImage: primaryActionIcon)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvance)
        }
    }

    private var primaryActionTitle: String {
        switch step {
        case .healthConnect:      return "Weiter"
        case .personalInfo:       return "Weiter"
        case .preferencesAndPlan: return "Fertig"
        }
    }

    private var primaryActionIcon: String {
        step == .preferencesAndPlan ? "checkmark.circle.fill" : "arrow.right"
    }

    private var canAdvance: Bool {
        switch step {
        case .healthConnect:
            // HealthKit ist optional — immer weiter erlaubt.
            return true
        case .personalInfo:
            return validatePersonalInfo()
        case .preferencesAndPlan:
            // Plan + Reminder sind beide optional — immer fertig erlaubt.
            return true
        }
    }

    private func handlePrimaryAction() {
        switch step {
        case .healthConnect, .personalInfo:
            goToNextStep()
        case .preferencesAndPlan:
            finishOnboarding()
        }
    }

    private func goToNextStep() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    private func goToPreviousStep() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    // MARK: - Validation

    private func validatePersonalInfo() -> Bool {
        guard let heightCm, Self.heightRange.contains(heightCm) else { return false }
        guard let currentWeightKg, Self.weightRange.contains(currentWeightKg) else { return false }
        if let goalWeightKg, !Self.weightRange.contains(goalWeightKg) { return false }
        return true
    }

    // MARK: - HealthKit pre-fill

    private func pullHealthKitSnapshot() async {
        healthKitFetchInProgress = true
        defer { healthKitFetchInProgress = false }

        let snapshot = await healthKit.loadOnboardingSnapshot()

        // Apply snapshot — only fill fields the user hasn't already touched.
        // We're still on step 1, fields haven't been visible yet, so they're
        // all empty defaults at this point. Defensive overwrite-only-if-empty
        // keeps the code safe if this is called multiple times.
        if let dob = snapshot.dateOfBirth, birthDate == Self.defaultBirthDate {
            birthDate = dob
        }
        switch snapshot.sex {
        case .male:    profileSex = .male
        case .female:  profileSex = .female
        case .other, .notSet: break
        }
        if heightCm == nil, let hc = snapshot.heightCm { heightCm = hc }
        if currentWeightKg == nil, let wk = snapshot.weightKg { currentWeightKg = wk }

        healthKitDataLoaded = true
    }

    // MARK: - Finish + save

    private func finishOnboarding() {
        guard let heightCm, let currentWeightKg else { return }
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0

        // 1) UserBodyProfile.
        let profile = UserBodyProfile(
            birthDate: birthDate,
            heightCm: heightCm,
            profile: profileSex,
            goalWeightKg: goalWeightKg,
            environment: environment
        )
        modelContext.insert(profile)

        // 2) Initial BodyMeasurement — keeps the "first weight" visible in the
        //    Trend-Chart right after onboarding, instead of an empty dashboard
        //    until the user adds another measurement manually.
        let measurement = BodyMeasurement.makeDerived(
            ageYears: age,
            weightKg: currentWeightKg,
            heightCm: heightCm,
            profile: profileSex
        )
        modelContext.insert(measurement)

        // 3) Plan-Template (optional). ProgramInstantiator deaktiviert
        //    automatisch andere Pläne — bei einem frischen Profil eh leer.
        if let template = selectedTemplate {
            ProgramInstantiator.instantiate(template, in: modelContext)
        }

        // 4) Notification-Präferenzen persistieren. Permission wird angefordert,
        //    wenn mindestens einer der Toggles aktiv ist.
        UserDefaults.standard.set(enableWaterReminder, forKey: "pref_water_reminder")
        UserDefaults.standard.set(enableMeasurementReminder, forKey: "pref_measurement_reminder")

        if enableWaterReminder || enableMeasurementReminder {
            Task { await prNotifications.requestAuthorization() }
        }

        // RootView's @Query auf [UserBodyProfile] beobachtet die Insert
        // und swappt automatisch auf MainTabView — kein Navigation-Push nötig.
    }

    // MARK: - Helpers + constants

    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>) -> some View {
        TextField(value: value, format: .number, prompt: Text(label)) {
            Text(label)
        }
        .decimalKeyboard()
    }

    private static let heightRange: ClosedRange<Double> = 100...250
    private static let weightRange: ClosedRange<Double> = 20...400

    /// Default to "30 years ago today" — sensibler Mid-point für unbekannten User.
    private static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    /// Plausibler Lower-Bound für den DatePicker (~125 Jahre).
    private static var minBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -125, to: Date()) ?? Date.distantPast
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Onboarding (leer)") {
    OnboardingView()
        .modelContainer(PreviewSeed.emptyContainer)
        .environment(HealthKitController())
        .environment(PRNotificationCenter())
}
#endif
#endif
