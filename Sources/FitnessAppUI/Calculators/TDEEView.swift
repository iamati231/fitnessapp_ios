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
                    "Kein Profil",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Lege erst dein Profil im Onboarding an.")
                )
            }
        }
        .navigationTitle("Kalorien-Rechner")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // Prefill with latest measured weight when the user lands on the screen.
            if weightKg == nil {
                weightKg = measurements.first?.weightKg ?? profiles.first?.goalWeightKg
            }
        }
    }

    // MARK: Sections

    private func profileSummarySection(_ profile: UserBodyProfile) -> some View {
        Section("Aus deinem Profil") {
            LabeledContent("Sex",
                value: profile.profile == .male ? "Maennlich" : "Weiblich")
            LabeledContent("Alter",
                value: "\(ageYears(for: profile)) Jahre")
            LabeledContent("Groesse",
                value: "\(profile.heightCm.truncated(to: 2).formattedTwoDecimals) cm")
        }
    }

    private func inputsSection(_ profile: UserBodyProfile) -> some View {
        Section {
            TextField(value: $weightKg, format: .number,
                      prompt: Text("z.B. \(profile.goalWeightKg.map { "\(Int($0))" } ?? "80")")) {
                Text("Gewicht (kg)")
            }
            .decimalKeyboard()

            Picker(selection: $activity) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Text(level.label).tag(level)
                }
            } label: {
                Text("Aktivitaet")
            }
        } header: {
            Text("Aktuelles Gewicht & Aktivitaet")
        } footer: {
            Text(activity.description)
                .font(.footnote)
        }
    }

    private func resultsSection(_ profile: UserBodyProfile) -> some View {
        Section("Energiebedarf") {
            if let weightKg, weightKg > 0 {
                let bmrMifflin = BodyCalculations.bmrMifflinStJeor(
                    weightKg: weightKg,
                    heightCm: profile.heightCm,
                    ageYears: ageYears(for: profile),
                    profile: profile.profile
                )
                let tdee = BodyCalculations.tdee(bmr: bmrMifflin, activityFactor: activity.factor)

                row("BMR (Mifflin-St-Jeor)", value: bmrMifflin)

                if let katch = katchBmr(weightKg: weightKg) {
                    row("BMR (Katch-McArdle)", value: katch)
                }

                row("TDEE", value: tdee, highlight: true)

                Divider().padding(.vertical, 4)

                row("Cut (-500)",     value: tdee - 500, secondary: true)
                row("Erhaltung",       value: tdee,       secondary: true)
                row("Bulk (+300)",     value: tdee + 300, secondary: true)
            } else {
                Text("Trag dein aktuelles Gewicht ein.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
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
        case .sedentary:  return "Buerojob (1.2)"
        case .light:      return "Leicht aktiv (1.375)"
        case .moderate:   return "Moderat (1.55)"
        case .active:     return "Aktiv (1.725)"
        case .veryActive: return "Sehr aktiv (1.9)"
        }
    }

    public var description: String {
        switch self {
        case .sedentary:  return "Buerojob, kaum Bewegung neben dem Alltag."
        case .light:      return "1-2 leichte Trainings pro Woche."
        case .moderate:   return "3-5 Trainings pro Woche (Default fuer Hobby-Lifter)."
        case .active:     return "6-7 Trainings pro Woche oder koerperlicher Beruf."
        case .veryActive: return "Tag-taeglich intensives Training oder schwere koerperliche Arbeit."
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
