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
        // All inner widgets use trailing-closure Label forms — same pattern as
        // OnboardingView. The positional `Picker(_ titleKey:)` / `DatePicker(_ titleKey:)` /
        // `TextField(_ titleKey:value:format:)` forms confuse the type checker on macOS
        // toolchains when nested inside Section + footer + multiple statements.
        Section {
            Picker(selection: $profile.profile) {
                Text("Maennlich").tag(BodyFormulaProfile.male)
                Text("Weiblich").tag(BodyFormulaProfile.female)
            } label: {
                Text("Sex")
            }
            .pickerStyle(.segmented)

            DatePicker(
                selection: $profile.birthDate,
                in: Self.minBirthDate ... Date(),
                displayedComponents: .date
            ) {
                Text("Geburtsdatum")
            }
        } header: {
            Text("Person")
        } footer: {
            Text("Sex steuert die Navy/Deurenberg-Formeln; das Alter geht in Mifflin-St-Jeor-BMR und Deurenberg ein.")
                .font(.footnote)
        }
    }

    private var bodySection: some View {
        Section {
            TextField(value: $profile.heightCm, format: .number,
                      prompt: Text("z.B. 180")) {
                Text("Groesse (cm)")
            }
            .decimalKeyboard()
        } header: {
            Text("Koerpermasse")
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
        Section {
            TextField(value: $profile.goalWeightKg, format: .number,
                      prompt: Text("z.B. 75")) {
                Text("Zielgewicht (kg, optional)")
            }
            .decimalKeyboard()

            Picker(selection: $profile.environment) {
                Text("Gym").tag(EnvironmentType.gym)
                Text("Home-Gym").tag(EnvironmentType.homeGym)
                Text("Ohne Equipment").tag(EnvironmentType.noEquipment)
            } label: {
                Text("Trainingsort")
            }
        } header: {
            Text("Ziel & Training")
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
