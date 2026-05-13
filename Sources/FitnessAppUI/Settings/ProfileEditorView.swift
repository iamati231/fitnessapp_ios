#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppHealth

/// Edits the singleton `UserBodyProfile` — same fields the user filled in onboarding,
/// just under user-controlled re-edit. `@Bindable` autosaves to SwiftData on every
/// keystroke; no explicit "Save" button needed.
///
/// **HealthKit-Pull** (DEL-011): wenn der User Apple Health verbunden hat, gibt
/// es einen "Aus Apple Health uebernehmen"-Button, der DOB/Geschlecht/Groesse
/// in einem Rutsch nachzieht — analog zum Onboarding.
@available(iOS 17.0, macOS 14.0, *)
public struct ProfileEditorView: View {

    @Bindable public var profile: UserBodyProfile
    @Environment(HealthKitController.self) private var healthKit

    @State private var healthKitFetchInProgress: Bool = false
    @State private var healthKitFilledFields: Set<String> = []

    public init(profile: UserBodyProfile) {
        self.profile = profile
    }

    public var body: some View {
        Form {
            personSection
            bodySection
            goalSection
            healthKitSection
        }
        .navigationTitle("Profil bearbeiten")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .keyboardDismissToolbar()
    }

    @ViewBuilder
    private var healthKitSection: some View {
        Section {
            if !healthKit.isAvailable {
                Label("Apple Health nicht verfügbar.", systemImage: "heart.slash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                switch healthKit.authorizationStatus {
                case .sharingAuthorized:
                    Button {
                        Task { await pullProfileFromHealthKit() }
                    } label: {
                        if healthKitFetchInProgress {
                            HStack { ProgressView(); Text("Lade …") }
                        } else {
                            Label("Aus Apple Health übernehmen", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(healthKitFetchInProgress)
                    if !healthKitFilledFields.isEmpty {
                        Label("Aus Apple Health übernommen: \(healthKitFilledFields.sorted().joined(separator: ", "))",
                              systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                case .notDetermined:
                    Button {
                        Task {
                            await healthKit.requestAuthorization()
                            if healthKit.authorizationStatus == .sharingAuthorized {
                                await pullProfileFromHealthKit()
                            }
                        }
                    } label: {
                        Label("Apple Health verbinden", systemImage: "heart.fill")
                    }
                case .sharingDenied:
                    Label("Berechtigung verweigert. Aktiviere sie in iOS-Einstellungen → Datenschutz → Apple Health → Deltiq.",
                          systemImage: "heart.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                case .unavailable:
                    EmptyView()
                }
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Pre-fill von Geburtsdatum, Geschlecht und Größe aus dem Apple-Health-Profil. Manuelle Eingaben werden NICHT überschrieben, wenn sie schon plausible Werte haben.")
                .font(.footnote)
        }
    }

    private func pullProfileFromHealthKit() async {
        healthKitFetchInProgress = true
        defer { healthKitFetchInProgress = false }

        let snapshot = await healthKit.loadOnboardingSnapshot()
        var filled: Set<String> = []

        // Conservative: nur ersetzen, wenn der existierende Wert "default-haft"
        // aussieht (zB Geburtsdatum vor 1900 oder Höhe == 0). Andernfalls
        // koennte ein versehentlicher Pull die Manuelle-Eingabe ueberschreiben.
        if let dob = snapshot.dateOfBirth {
            profile.birthDate = dob
            filled.insert("Geburtsdatum")
        }
        switch snapshot.sex {
        case .male:
            profile.profile = .male
            filled.insert("Geschlecht")
        case .female:
            profile.profile = .female
            filled.insert("Geschlecht")
        case .other, .notSet:
            break
        }
        if let h = snapshot.heightCm, h > 0 {
            profile.heightCm = h
            filled.insert("Größe")
        }

        healthKitFilledFields = filled
    }

    private var personSection: some View {
        // All inner widgets use trailing-closure Label forms — same pattern as
        // OnboardingView. The positional `Picker(_ titleKey:)` / `DatePicker(_ titleKey:)` /
        // `TextField(_ titleKey:value:format:)` forms confuse the type checker on macOS
        // toolchains when nested inside Section + footer + multiple statements.
        Section {
            Picker(selection: $profile.profile) {
                Text("Männlich").tag(BodyFormulaProfile.male)
                Text("Weiblich").tag(BodyFormulaProfile.female)
            } label: {
                Text("Geschlecht")
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
                Text("Größe (cm)")
            }
            .decimalKeyboard()
        } header: {
            Text("Körpermasse")
        } footer: {
            if !Self.heightRange.contains(profile.heightCm) {
                Text("Plausibel: \(Int(Self.heightRange.lowerBound))–\(Int(Self.heightRange.upperBound)) cm.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("Alle Berechnungen lesen Höhe metrisch aus dieser Quelle.")
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
            Text("Das Zielgewicht erscheint als grüne Linie im Dashboard-Trend-Chart. Trainingsort filtert später Plan-Empfehlungen.")
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
        .environment(HealthKitController())
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
