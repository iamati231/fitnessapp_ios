#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppActivities

/// First-launch profile setup. Captures the inputs that drive every body-composition
/// formula downstream: sex (Navy/Deurenberg/Mifflin), birth date (age in BMR), height
/// (BMI/FFMI), goal weight (Fat-Loss target), and environment (plan recommendations).
///
/// Saving inserts a single `UserBodyProfile` and ends — `RootView` swaps to the main
/// app automatically via SwiftData's `@Query` reactivity.
@available(iOS 17.0, macOS 14.0, *)
public struct OnboardingView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(PRNotificationCenter.self) private var prNotifications

    @State private var profileSex: BodyFormulaProfile = .male
    @State private var birthDate: Date = Self.defaultBirthDate
    @State private var heightCm: Double?
    @State private var goalWeightKg: Double?
    @State private var environment: EnvironmentType = .gym

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                introSection
                profileSection
                bodySection
                goalSection
                actionsSection
            }
            .navigationTitle(Text("onboarding.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .keyboardDismissToolbar()
        }
    }

    // MARK: Sections

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("onboarding.intro.title", bundle: .module)
                    .font(.title3.weight(.semibold))
                Text("onboarding.intro.body", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var profileSection: some View {
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
        } footer: {
            Text("Sex steuert die Navy/Deurenberg-Formeln; das Alter geht in den Mifflin-St-Jeor-BMR ein.")
                .font(.footnote)
        }
    }

    private var bodySection: some View {
        Section {
            TextField(value: $heightCm, format: .number,
                      prompt: Text("z.B. 180")) {
                Text("onboarding.field.height", bundle: .module)
            }
            .decimalKeyboard()
        } header: {
            Text("onboarding.section.body", bundle: .module)
        } footer: {
            if let heightCm, !Self.heightRange.contains(heightCm) {
                Text("Größe zwischen \(Int(Self.heightRange.lowerBound)) und \(Int(Self.heightRange.upperBound)) cm.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("Wird gespeichert wie eingegeben — die App rechnet bei lbs/in-Anzeige nur für die UI um.")
                    .font(.footnote)
            }
        }
    }

    private var goalSection: some View {
        Section {
            TextField(value: $goalWeightKg, format: .number,
                      prompt: Text("z.B. 75")) {
                Text("onboarding.field.goal_weight", bundle: .module)
            }
            .decimalKeyboard()

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

    private var actionsSection: some View {
        Section {
            Button {
                save()
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text("onboarding.action.create", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(.headline)
                    Spacer()
                }
            }
            .disabled(!canSave)
        }
    }

    // MARK: Validation + Save

    private var canSave: Bool {
        guard let heightCm, Self.heightRange.contains(heightCm) else { return false }
        if let goalWeightKg, !Self.weightRange.contains(goalWeightKg) { return false }
        // birthDate is constrained by the DatePicker range, no extra check needed.
        return true
    }

    private func save() {
        guard let heightCm else { return }
        let profile = UserBodyProfile(
            birthDate: birthDate,
            heightCm: heightCm,
            profile: profileSex,
            goalWeightKg: goalWeightKg,
            environment: environment
        )
        modelContext.insert(profile)
        // No navigation push — RootView's @Query observes profiles and swaps to MainTabView
        // automatically as soon as this insert is visible to the context.

        // Graceful first-touch authorization for PR-celebration notifications.
        // Asking right after the user committed to the app is the calmest moment
        // — they have context, they've already invested. The system prompt
        // appears once; a denied user just gets silent celebrations later.
        Task { await prNotifications.requestAuthorization() }
    }

    // MARK: Static helpers

    private static let heightRange: ClosedRange<Double> = 100...250
    private static let weightRange: ClosedRange<Double> = 20...400

    /// Default to "30 years ago today" — sensible mid-point for an unknown user.
    private static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    /// Plausible lower bound for a date picker (~125 years ago).
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
}
#endif
#endif
