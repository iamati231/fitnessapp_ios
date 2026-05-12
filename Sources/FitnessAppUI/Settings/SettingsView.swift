#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth
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

    @Query private var profiles: [UserBodyProfile]

    @AppStorage("weight_unit") private var weightUnitRaw: String = "kg"

    @State private var showingResetConfirm = false
    @State private var resetErrorMessage: String?

    public init() {}

    public var body: some View {
        List {
            profileSection
            preferencesSection
            healthKitSection
            aboutSection
            dangerZoneSection
        }
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
        Section {
            profileSectionContent
        } header: {
            Text("settings.section.profile_goals", bundle: .module)
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

    private var preferencesSection: some View {
        Section {
            Picker(selection: $weightUnitRaw) {
                Text("settings.preferences.units.metric", bundle: .module).tag("kg")
                Text("settings.preferences.units.imperial", bundle: .module).tag("lbs")
            } label: {
                Text("settings.preferences.units", bundle: .module)
            }
        } header: {
            Text("settings.section.preferences", bundle: .module)
        } footer: {
            Text("Die DB speichert immer metrisch. Diese Einstellung steuert nur die Anzeige in Eingabe-Feldern, im Hantel-Rechner und auf den Karten.")
                .font(.footnote)
        }
    }

    private var healthKitSection: some View {
        Section {
            healthKitStatusRow
            if healthKit.authorizationStatus == .sharingDenied {
                openIOSSettingsButton
            }
            if let lastSync = healthKit.lastSyncDate {
                LabeledContent("Letzter Sync",
                    value: lastSync.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Bei aktivierter Verbindung wird im Messwerte-Formular das letzte Waagen-Gewicht vorausgefüllt. Beim Speichern werden Gewicht, KFA und Magere Masse zurück nach Apple Health geschrieben.")
                .font(.footnote)
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
        Section {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Bundle", value: bundleIdentifier)
        } header: {
            Text("settings.section.about", bundle: .module)
        }
    }

    private var dangerZoneSection: some View {
        Section {
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
        } header: {
            Text("settings.section.danger_zone", bundle: .module)
        } footer: {
            Text("Löscht Profil, Messungen, Pläne, Trainings-Templates und Workout-Sessions vollständig. Die Apple-Health-Daten bleiben erhalten — die löscht du in der Health-App selber.")
                .font(.footnote)
        }
    }

    // MARK: Reset

    /// Wipes all SwiftData entities and our `@AppStorage` keys, then resets navigation
    /// so the app re-renders into Onboarding. Apple-Health-Daten bleiben unangetastet
    /// (sind Eigentum des Users in einer separaten Datenbank).
    ///
    /// Add new `@Model` types to the delete sequence below — missing entries leave
    /// orphan rows that surface as "ghost data" after the supposed reset.
    ///
    /// **Why fetch-then-delete-each instead of `delete(model:)`** (v0.1.13 bugfix):
    /// SwiftData's bulk `delete(model:)` builds an NSBatchDeleteRequest under
    /// the hood. That bypasses the @Relationship cascade/nullify rules and trips
    /// "mandatory OTO nullify inverse"-violations when models reference each
    /// other (here: ExerciseLog.exercise as the inverse of Exercise.logs).
    /// Fetching each instance and calling `modelContext.delete(item)` triggers
    /// the proper rule-aware deletion path.
    private func resetApp() {
        do {
            // Children-first ordering. With per-instance deletes the cascade/nullify
            // rules from each @Relationship fire correctly, so this order is
            // belt-and-suspenders rather than strictly required.
            try deleteAll(of: PersonalRecordEntry.self)
            try deleteAll(of: ExerciseLog.self)
            try deleteAll(of: WorkoutSession.self)
            try deleteAll(of: Exercise.self)
            try deleteAll(of: TrainingDay.self)
            try deleteAll(of: TrainingPlan.self)
            try deleteAll(of: ExerciseTemplate.self)
            try deleteAll(of: WaterEntry.self)
            try deleteAll(of: BodyMeasurement.self)
            try deleteAll(of: UserBodyProfile.self)
            // Explicit save is the trigger that flushes the deletes to the store
            // AND fires the @Query change-notification that swaps RootView from
            // MainTabView back to OnboardingView. Without this save, the deletes
            // live in memory until the next implicit autosave.
            try modelContext.save()

            // Clear our AppStorage keys — leave system defaults alone.
            for key in ["weight_unit", "height_unit", "unit_system"] {
                UserDefaults.standard.removeObject(forKey: key)
            }

            // Reset navigation: workoutPath may hold references to now-deleted models,
            // and the user should land on the Dashboard tab once Onboarding completes.
            navigation.workoutPath = NavigationPath()
            navigation.selectedTab = .dashboard
        } catch {
            resetErrorMessage = error.localizedDescription
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
