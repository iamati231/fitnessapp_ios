#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// TDEE / calorie calculator. Pulls age, sex, height from the singleton `UserBodyProfile`
/// — the user only adjusts current weight (defaulting to the latest measurement) and
/// activity level. BMR uses Mifflin-St Jeor; if the profile has body-fat data via the
/// latest measurement, Katch-McArdle is shown alongside as a "more accurate for athletes"
/// alternative.
@available(iOS 17.0, macOS 14.0, *)
public struct TDEEView: View {

    @Query private var profiles: [UserBodyProfile]

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var weightKg: Double?
    @State private var activity: ActivityLevel = .moderate

    public init() {}

    public var body: some View {
        Form {
            if let profile = profiles.first {
                profileSummarySection(profile)
                inputsSection(profile)
                resultsSection(profile)
            } else {
                ContentUnavailableView(
                    String(localized: "calc.tdee.noProfile.title", bundle: .module),
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("calc.tdee.noProfile.message", bundle: .module)
                )
            }
        }
        .navigationTitle(Text("calc.tdee.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .keyboardDismissToolbar()
        .onAppear {
            // Prefill with latest measured weight when the user lands on the screen.
            if weightKg == nil {
                weightKg = measurements.first?.weightKg ?? profiles.first?.goalWeightKg
            }
        }
    }

    // MARK: Sections

    private func profileSummarySection(_ profile: UserBodyProfile) -> some View {
        Section {
            LabeledContent {
                Text(profile.profile == .male ? "sex.male" : "sex.female", bundle: .module)
            } label: {
                Text("onboarding.field.sex", bundle: .module)
            }
            LabeledContent {
                Text(String(format: String(localized: "settings.profile.years", bundle: .module), ageYears(for: profile)))
            } label: {
                Text("calc.tdee.age", bundle: .module)
            }
            LabeledContent {
                Text("\(profile.heightCm.truncated(to: 2).formattedTwoDecimals) cm")
            } label: {
                Text("calc.tdee.height", bundle: .module)
            }
        } header: {
            Text("calc.tdee.section.profile", bundle: .module)
        }
    }

    private func inputsSection(_ profile: UserBodyProfile) -> some View {
        Section {
            TextField(value: $weightKg, format: .number,
                      prompt: Text(String(format: String(localized: "calc.tdee.weightPlaceholder", bundle: .module), profile.goalWeightKg.map { "\(Int($0))" } ?? "80"))) {
                Text("calc.tdee.weightLabel", bundle: .module)
            }
            .decimalKeyboard()

            Picker(selection: $activity) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Text(level.localizedName).tag(level)
                }
            } label: {
                Text("calc.tdee.activity", bundle: .module)
            }
        } header: {
            Text("calc.tdee.section.input", bundle: .module)
        } footer: {
            Text(activity.localizedDescription)
                .font(.footnote)
        }
    }

    private func resultsSection(_ profile: UserBodyProfile) -> some View {
        Section {
            if let weightKg, weightKg > 0 {
                let bmrMifflin = BodyCalculations.bmrMifflinStJeor(
                    weightKg: weightKg,
                    heightCm: profile.heightCm,
                    ageYears: ageYears(for: profile),
                    profile: profile.profile
                )
                let tdee = BodyCalculations.tdee(bmr: bmrMifflin, activityFactor: activity.factor)

                row(String(localized: "calc.tdee.bmrMifflin", bundle: .module), value: bmrMifflin)

                if let katch = katchBmr(weightKg: weightKg) {
                    row(String(localized: "calc.tdee.bmrKatch", bundle: .module), value: katch)
                }

                row(String(localized: "calc.tdee.tdee", bundle: .module), value: tdee, highlight: true)

                Divider().padding(.vertical, 4)

                row(String(localized: "calc.tdee.cut", bundle: .module),         value: tdee - 500, secondary: true)
                row(String(localized: "calc.tdee.maintenance", bundle: .module), value: tdee,       secondary: true)
                row(String(localized: "calc.tdee.bulk", bundle: .module),        value: tdee + 300, secondary: true)
            } else {
                Text("calc.tdee.weightRequired", bundle: .module)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        } header: {
            Text("calc.tdee.section.results", bundle: .module)
        }
    }

    // MARK: Helpers

    private func ageYears(for profile: UserBodyProfile) -> Int {
        Calendar.current.dateComponents([.year], from: profile.birthDate, to: Date()).year ?? 0
    }

    /// Katch-McArdle uses fat-free mass — we use the FFM from the latest measurement
    /// IF its weight matches the user's current entry within ~1 kg. Otherwise we'd be
    /// mixing weights and the result becomes meaningless.
    private func katchBmr(weightKg currentWeight: Double) -> Double? {
        guard let latest = measurements.first,
              let ffm = latest.fatFreeMassKg,
              abs(latest.weightKg - currentWeight) < 1.0
        else { return nil }
        return BodyCalculations.bmrKatchMcArdle(fatFreeMassKg: ffm)
    }

    private func row(
        _ label: String,
        value: Double,
        highlight: Bool = false,
        secondary: Bool = false
    ) -> some View {
        LabeledContent {
            Text("\(value.truncated(to: 0).formattedTwoDecimals) kcal")
                .fontWeight(highlight ? .semibold : .regular)
                .foregroundStyle(secondary ? .secondary : .primary)
                .monospacedDigit()
        } label: {
            Text(label)
                .fontWeight(highlight ? .semibold : .regular)
                .foregroundStyle(secondary ? .secondary : .primary)
        }
    }
}

// MARK: - Activity levels

@available(iOS 17.0, macOS 14.0, *)
public enum ActivityLevel: String, CaseIterable, Sendable {
    case sedentary  = "sedentary"
    case light      = "light"
    case moderate   = "moderate"
    case active     = "active"
    case veryActive = "very_active"

    /// Physical Activity Level multipliers — the standard Harris/Mifflin scale.
    public var factor: Double {
        switch self {
        case .sedentary:  return 1.2
        case .light:      return 1.375
        case .moderate:   return 1.55
        case .active:     return 1.725
        case .veryActive: return 1.9
        }
    }

    public var label: String {
        switch self {
        case .sedentary:  return "Bürojob (1.2)"
        case .light:      return "Leicht aktiv (1.375)"
        case .moderate:   return "Moderat (1.55)"
        case .active:     return "Aktiv (1.725)"
        case .veryActive: return "Sehr aktiv (1.9)"
        }
    }

    public var description: String {
        switch self {
        case .sedentary:  return "Bürojob, kaum Bewegung neben dem Alltag."
        case .light:      return "1-2 leichte Trainings pro Woche."
        case .moderate:   return "3-5 Trainings pro Woche (Default für Hobby-Lifter)."
        case .active:     return "6-7 Trainings pro Woche oder körperlicher Beruf."
        case .veryActive: return "Tag-täglich intensives Training oder schwere körperliche Arbeit."
        }
    }

    // DEL-120: lokalisierte Varianten von label + description.
    public var localizedName: LocalizedStringResource {
        switch self {
        case .sedentary:  LocalizedStringResource("activity.sedentary.label",  bundle: .module)
        case .light:      LocalizedStringResource("activity.light.label",      bundle: .module)
        case .moderate:   LocalizedStringResource("activity.moderate.label",   bundle: .module)
        case .active:     LocalizedStringResource("activity.active.label",     bundle: .module)
        case .veryActive: LocalizedStringResource("activity.veryActive.label", bundle: .module)
        }
    }

    public var localizedDescription: LocalizedStringResource {
        switch self {
        case .sedentary:  LocalizedStringResource("activity.sedentary.description",  bundle: .module)
        case .light:      LocalizedStringResource("activity.light.description",      bundle: .module)
        case .moderate:   LocalizedStringResource("activity.moderate.description",   bundle: .module)
        case .active:     LocalizedStringResource("activity.active.description",     bundle: .module)
        case .veryActive: LocalizedStringResource("activity.veryActive.description", bundle: .module)
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit 6 Wochen Daten") {
    NavigationStack {
        TDEEView()
    }
    .modelContainer(PreviewSeed.dashboardContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit Profil, ohne Messung") {
    NavigationStack {
        TDEEView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Ohne Profil") {
    NavigationStack {
        TDEEView()
    }
    .modelContainer(PreviewSeed.emptyContainer)
}
#endif
#endif
