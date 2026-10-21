#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Deltiq-Nutrition v1 (Task 5): Settings-Screen für die vier flachen,
/// optionalen Tagesziel-Felder auf `UserBodyProfile`. Jedes Feld ist direkt
/// an das (bereits `@Query`-geladene) Singleton-Profil gebunden — SwiftData
/// persistiert Aenderungen wie ueberall sonst im Repo automatisch, kein
/// eigenes ViewModel/Draft-Objekt noetig (Projekt-Konvention bei einfachen
/// Settings-Formularen ohne mehrstufige Validierung).
///
/// "Aus TDEE übernehmen" repliziert TDEEViews BMR/TDEE-Formel 1:1
/// (`BodyCalculations.bmrMifflinStJeor` → `BodyCalculations.tdee`) mit den
/// eigenen, kleinen Gewicht-/Aktivitätslevel-Eingaben dieses Screens und
/// schreibt das Ergebnis als EINMALIGEN Snapshot in `dailyCalorieGoalKcal` —
/// bewusst kein Live-Binding an eine reaktive TDEE-Berechnung, sonst würde
/// jede spätere Gewichts-/Aktivitätsänderung anderswo das bereits gesetzte
/// Kalorienziel unbemerkt verschieben.
@available(iOS 17.0, macOS 14.0, *)
public struct NutritionGoalsView: View {

    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserBodyProfile]

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var tdeeWeightKg: Double?
    @State private var tdeeActivity: ActivityLevel = .moderate

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "calc.index.title", bundle: .module).uppercased(),
                title: String(localized: "nutrition.goals.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 18) {
                if let profile = profiles.first {
                    goalsCard(profile)
                    tdeeAdoptionCard(profile)
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
            // Gleiches Prefill-Muster wie TDEEView: letzte Messung, sonst
            // Ziel-Gewicht aus dem Profil.
            if tdeeWeightKg == nil {
                tdeeWeightKg = measurements.first?.weightKg ?? profiles.first?.goalWeightKg
            }
        }
    }

    // MARK: Sections

    private func goalsCard(_ profile: UserBodyProfile) -> some View {
        let calorieLabel = String(localized: "nutrition.goals.calorie.label", bundle: .module)
        let proteinLabel = String(localized: "nutrition.goals.protein.label", bundle: .module)
        let carbsLabel = String(localized: "nutrition.goals.carbs.label", bundle: .module)
        let fatLabel = String(localized: "nutrition.goals.fat.label", bundle: .module)
        return DeltiqSection(String(localized: "nutrition.goals.title", bundle: .module).uppercased()) {
            DeltiqControlRow(label: calorieLabel) {
                intField(calorieLabel, value: Binding(
                    get: { profile.dailyCalorieGoalKcal },
                    set: { profile.dailyCalorieGoalKcal = $0 }
                ))
            }
            DeltiqControlRow(label: proteinLabel) {
                decimalField(proteinLabel, value: Binding(
                    get: { profile.dailyProteinGoalG },
                    set: { profile.dailyProteinGoalG = $0 }
                ))
            }
            DeltiqControlRow(label: carbsLabel) {
                decimalField(carbsLabel, value: Binding(
                    get: { profile.dailyCarbGoalG },
                    set: { profile.dailyCarbGoalG = $0 }
                ))
            }
            DeltiqControlRow(label: fatLabel, showsDivider: false) {
                decimalField(fatLabel, value: Binding(
                    get: { profile.dailyFatGoalG },
                    set: { profile.dailyFatGoalG = $0 }
                ))
            }
        }
    }

    private func tdeeAdoptionCard(_ profile: UserBodyProfile) -> some View {
        let canAdopt = (tdeeWeightKg ?? 0) > 0
        return DeltiqSection(String(localized: "calc.tdee.section.input", bundle: .module).uppercased()) {
            let weightLabel = String(localized: "calc.tdee.weightLabel", bundle: .module)
            DeltiqControlRow(label: weightLabel) {
                decimalField(
                    weightLabel,
                    value: $tdeeWeightKg,
                    placeholder: String(
                        format: String(localized: "calc.tdee.weightPlaceholder", bundle: .module),
                        profile.goalWeightKg.map { "\(Int($0))" } ?? "80"
                    )
                )
            }
            DeltiqControlRow(
                label: String(localized: "calc.tdee.activity", bundle: .module),
                showsDivider: canAdopt
            ) {
                Picker(selection: $tdeeActivity) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.localizedName).tag(level)
                    }
                } label: { EmptyView() }
                .pickerStyle(.menu)
            }
            if canAdopt, let tdeeWeightKg {
                Button {
                    adoptFromTDEE(profile: profile, weightKg: tdeeWeightKg)
                } label: {
                    HStack {
                        Text("nutrition.goals.adoptFromTDEE.button", bundle: .module)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.deltiqOrange)
            }
        }
    }

    // MARK: Actions

    /// Repliziert exakt TDEEViews Berechnung (BMR Mifflin-St Jeor → TDEE mit
    /// Aktivitätsfaktor) mit den eigenen Eingaben dieses Screens und schreibt
    /// das Ergebnis als EINMALIGEN Snapshot — kein Live-Binding, siehe
    /// Typ-Dokumentation oben.
    private func adoptFromTDEE(profile: UserBodyProfile, weightKg: Double) {
        let bmr = BodyCalculations.bmrMifflinStJeor(
            weightKg: weightKg,
            heightCm: profile.heightCm,
            ageYears: ageYears(for: profile),
            profile: profile.profile
        )
        let tdee = BodyCalculations.tdee(bmr: bmr, activityFactor: tdeeActivity.factor)
        profile.dailyCalorieGoalKcal = Int(tdee.rounded())
    }

    private func ageYears(for profile: UserBodyProfile) -> Int {
        Calendar.current.dateComponents([.year], from: profile.birthDate, to: Date()).year ?? 0
    }

    // MARK: Field helpers (DEL-106-Muster, identisch zu TDEEView/CardioGoalEditorView)

    @ViewBuilder
    private func decimalField(_ label: String, value: Binding<Double?>, placeholder: String = "") -> some View {
        TextField(label, value: value, format: .number, prompt: placeholder.isEmpty ? nil : Text(placeholder))
            .decimalKeyboard()
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }

    @ViewBuilder
    private func intField(_ label: String, value: Binding<Int?>) -> some View {
        TextField(label, value: value, format: .number)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .fitnessNumberStyle()
            .frame(maxWidth: 140)
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Mit Profil") {
    NavigationStack {
        NutritionGoalsView()
    }
    .modelContainer(PreviewSeed.maleProfileContainer)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Ohne Profil") {
    NavigationStack {
        NutritionGoalsView()
    }
    .modelContainer(PreviewSeed.emptyContainer)
}
#endif
#endif
