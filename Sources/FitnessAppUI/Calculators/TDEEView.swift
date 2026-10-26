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

    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserBodyProfile]

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var weightKg: Double?
    @State private var activity: ActivityLevel = .moderate

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Signature-Geruest 1.2: Eyebrow zeigt den Elternscreen (Rechner-Hub),
            // nicht den Tab - selbes Muster wie WaterTrackerView.
            DeltiqHeader(
                eyebrow: String(localized: "calc.index.title", bundle: .module).uppercased(),
                title: String(localized: "calc.tdee.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                if let profile = profiles.first {
                    profileSummaryCard(profile)
                    inputsCard(profile)
                    resultsCard(profile)
                } else {
                    DashboardEmptyState(
                        icon: "person.crop.circle.badge.exclamationmark",
                        title: "calc.tdee.noProfile.title",
                        description: "calc.tdee.noProfile.message"
                    )
                    .deltiqCardStyle()
                }
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift.
        .deltiqSwipeBackEnabled()
        .keyboardDismissToolbar()
        .onAppear {
            // Prefill with latest measured weight when the user lands on the screen.
            if weightKg == nil {
                weightKg = measurements.first?.weightKg ?? profiles.first?.goalWeightKg
            }
        }
    }

    // MARK: Sections

    private func profileSummaryCard(_ profile: UserBodyProfile) -> some View {
        DeltiqSection(String(localized: "calc.tdee.section.profile", bundle: .module).uppercased()) {
            DeltiqRow(
                label: String(localized: "onboarding.field.sex", bundle: .module),
                value: profile.profile == .male
                    ? String(localized: "sex.male", bundle: .module)
                    : String(localized: "sex.female", bundle: .module)
            )
            DeltiqRow(
                label: String(localized: "calc.tdee.age", bundle: .module),
                value: String(format: String(localized: "settings.profile.years", bundle: .module), profile.ageYears)
            )
            DeltiqRow(
                label: String(localized: "calc.tdee.height", bundle: .module),
                value: "\(profile.heightCm.truncated(to: 2).formattedTwoDecimals) cm",
                showsDivider: false
            )
        }
    }

    private func inputsCard(_ profile: UserBodyProfile) -> some View {
        DeltiqSection(String(localized: "calc.tdee.section.input", bundle: .module).uppercased()) {
            let weightLabel = String(localized: "calc.tdee.weightLabel", bundle: .module)
            DeltiqControlRow(label: weightLabel) {
                decimalField(
                    weightLabel,
                    value: $weightKg,
                    placeholder: String(
                        format: String(localized: "calc.tdee.weightPlaceholder", bundle: .module),
                        profile.goalWeightKg.map { "\(Int($0))" } ?? "80"
                    )
                )
            }
            DeltiqControlRow(label: String(localized: "calc.tdee.activity", bundle: .module), showsDivider: false) {
                Picker(selection: $activity) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.localizedName).tag(level)
                    }
                } label: { EmptyView() }
                .pickerStyle(.menu)
            }
            hintRow(String(localized: activity.localizedDescription))
        }
    }

    private func resultsCard(_ profile: UserBodyProfile) -> some View {
        DeltiqSection(String(localized: "calc.tdee.section.results", bundle: .module).uppercased()) {
            if let weightKg, weightKg > 0 {
                let bmrMifflin = BodyCalculations.bmrMifflinStJeor(
                    weightKg: weightKg,
                    heightCm: profile.heightCm,
                    ageYears: profile.ageYears,
                    profile: profile.profile
                )
                let tdee = BodyCalculations.tdee(bmr: bmrMifflin, activityFactor: activity.factor)

                VStack(spacing: 4) {
                    Text(String(localized: "calc.tdee.tdee", bundle: .module).uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.deltiqOrange)
                    Text("\(tdee.truncated(to: 0).formattedTwoDecimals) kcal")
                        .font(.system(size: 26, weight: .heavy))
                        .fitnessNumberStyle()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)

                resultRow(String(localized: "calc.tdee.bmrMifflin", bundle: .module), value: bmrMifflin)

                if let katch = katchBmr(weightKg: weightKg) {
                    resultRow(String(localized: "calc.tdee.bmrKatch", bundle: .module), value: katch)
                }

                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
                    .padding(.vertical, 4)

                resultRow(String(localized: "calc.tdee.cut", bundle: .module), value: Double(CalorieGoalType.cut.dailyGoalKcal(tdee: tdee)), secondary: true)
                resultRow(String(localized: "calc.tdee.maintenance", bundle: .module), value: Double(CalorieGoalType.maintenance.dailyGoalKcal(tdee: tdee)), secondary: true)
                resultRow(String(localized: "calc.tdee.bulk", bundle: .module), value: Double(CalorieGoalType.bulk.dailyGoalKcal(tdee: tdee)), secondary: true, showsDivider: false)
            } else {
                Text("calc.tdee.weightRequired", bundle: .module)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: Row helpers

    /// DEL-106-Muster (siehe MeasurementView.decimalField): TextField mit Decimal-Keyboard,
    /// rechtsbuendig, `fitnessNumberStyle()`. Kein FocusState/Feld-Enum noetig — dieser
    /// Screen hat keine Previous/Next-Tastatur-Navigation zwischen Feldern.
    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>, placeholder: String) -> some View {
        TextField(label, value: value, format: .number, prompt: Text(placeholder))
            .decimalKeyboard()
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    private func resultRow(_ label: String, value: Double, secondary: Bool = false, showsDivider: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(secondary ? Color.Deltiq.textSecondary : Color.primary)
                Spacer()
                Text("\(value.truncated(to: 0).formattedTwoDecimals) kcal")
                    .font(.system(size: 15))
                    .foregroundStyle(secondary ? Color.Deltiq.textSecondary : Color.primary)
                    .monospacedDigit()
                    .fitnessNumberStyle()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }

    /// DEL-106-Muster (siehe SettingsView.hintRow): Inline-Caption am Fuss einer Section.
    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Deltiq.textSecondary)
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // MARK: Helpers

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

// MARK: - Calorie goal type (Bulk / Cut / Maintenance)

/// writing-block.md Punkt 5 ("Tagesziel-Rechner um Bulk/Cut ergaenzen"): the
/// cut (-500 kcal)/maintenance/bulk (+300 kcal) adjustment was previously
/// three magic numbers inline in `resultsCard` below, with no way to pick
/// one of them as the actual daily goal in `NutritionGoalsView` — that
/// screen could only ever adopt the plain maintenance TDEE. Centralizing it
/// here (same file/module as the already-established `ActivityLevel`
/// precedent, which has the identical case+factor+localizedName shape)
/// means both screens share one definition instead of duplicating the
/// adjustment values.
@available(iOS 17.0, macOS 14.0, *)
public enum CalorieGoalType: String, CaseIterable, Sendable {
    case cut
    case maintenance
    case bulk

    /// kcal/day added to TDEE. Negative for `.cut` — a moderate, widely-used
    /// deficit/surplus (not a clinical recommendation), matching the values
    /// this calculator already showed before this ticket.
    public var adjustmentKcal: Int {
        switch self {
        case .cut:         return -500
        case .maintenance: return 0
        case .bulk:        return 300
        }
    }

    /// Final-review ruling: project-wide truncate-not-round convention
    /// (DoubleFormatting.swift) applies here too, not just rounding.
    public func dailyGoalKcal(tdee: Double) -> Int {
        Int(tdee.truncated(to: 0)) + adjustmentKcal
    }

    public var localizedName: LocalizedStringResource {
        switch self {
        case .cut:         LocalizedStringResource("calc.tdee.cut",         bundle: .module)
        case .maintenance: LocalizedStringResource("calc.tdee.maintenance", bundle: .module)
        case .bulk:        LocalizedStringResource("calc.tdee.bulk",        bundle: .module)
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
