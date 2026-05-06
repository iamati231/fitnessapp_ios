#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Edits the singleton `UserBodyProfile` — same fields the user filled in onboarding,
/// just under user-controlled re-edit. `@Bindable` autosaves to SwiftData on every
/// keystroke; no explicit "Save" button needed.
@available(iOS 17.0, macOS 14.0, *)
public struct ProfileEditorView: View {

    @Bindable public var profile: UserBodyProfile

    public init(profile: UserBodyProfile) {
        self.profile = profile
    }

    public var body: some View {
        Form {
            personSection
            bodySection
            goalSection
        }
        .navigationTitle("Profil bearbeiten")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var personSection: some View {
        Section("Person") {
            Picker("Sex", selection: $profile.profile) {
                Text("Maennlich").tag(BodyFormulaProfile.male)
                Text("Weiblich").tag(BodyFormulaProfile.female)
            }
            .pickerStyle(.segmented)

            DatePicker(
                "Geburtsdatum",
                selection: $profile.birthDate,
                in: Self.minBirthDate ... Date(),
                displayedComponents: .date
            )
        } footer: {
            Text("Sex steuert die Navy/Deurenberg-Formeln; das Alter geht in Mifflin-St-Jeor-BMR und Deurenberg ein.")
                .font(.footnote)
        }
    }

    private var bodySection: some View {
        Section("Koerpermasse") {
            TextField("Groesse (cm)",
                      value: $profile.heightCm, format: .number,
                      prompt: Text("z.B. 180"))
                .decimalKeyboard()
        } footer: {
            if !Self.heightRange.contains(profile.heightCm) {
                Text("Plausibel: \(Int(Self.heightRange.lowerBound))–\(Int(Self.heightRange.upperBound)) cm.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("Alle Berechnungen lesen Hoehe metrisch aus dieser Quelle.")
                    .font(.footnote)
            }
        }
    }

    private var goalSection: some View {
        Section("Ziel & Training") {
            TextField("Zielgewicht (kg, optional)",
                      value: $profile.goalWeightKg, format: .number,
                      prompt: Text("z.B. 75"))
                .decimalKeyboard()

            Picker("Trainingsort", selection: $profile.environment) {
                Text("Gym").tag(EnvironmentType.gym)
                Text("Home-Gym").tag(EnvironmentType.homeGym)
                Text("Ohne Equipment").tag(EnvironmentType.noEquipment)
            }
        } footer: {
            Text("Das Zielgewicht erscheint als gruene Linie im Dashboard-Trend-Chart. Trainingsort filtert spaeter Plan-Empfehlungen.")
                .font(.footnote)
        }
    }

    private static let heightRange: ClosedRange<Double> = 100...250

    private static var minBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -125, to: Date()) ?? Date.distantPast
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    ProfileEditorPreviewWrapper()
        .modelContainer(PreviewSeed.maleProfileContainer)
}

@available(iOS 17.0, macOS 14.0, *)
private struct ProfileEditorPreviewWrapper: View {
    @Query private var profiles: [UserBodyProfile]

    var body: some View {
        if let profile = profiles.first {
            NavigationStack {
                ProfileEditorView(profile: profile)
            }
        } else {
            Text("Kein Profil im Preview-Container")
        }
    }
}
#endif
#endif
