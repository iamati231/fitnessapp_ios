#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Shown as a sheet from PlansListView when the user wants to start from a
/// program template instead of building a plan from scratch. Displays all
/// `ProgramTemplates.all` with name, tagline, focus, and day-count tiles.
/// Tapping a row instantiates the plan, dismisses the sheet, and pushes the
/// new plan onto the workout-tab navigation stack.
@available(iOS 17.0, macOS 14.0, *)
public struct ProgramTemplatePickerView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation

    /// Lesen das User-Profil, um die Templates nach passendem
    /// Trainingsort vorzufiltern (DEL-012).
    @Query private var profiles: [UserBodyProfile]

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredTemplates) { template in
                        Button {
                            instantiate(template)
                        } label: {
                            ProgramRow(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Gefiltert nach deinem Trainingsort (\(userEnvironmentLabel)). Im Profil anpassen, wenn du auch andere Plaene sehen willst.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Programm wählen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    /// Filtert nach `profile.environment`. Same Logik wie OnboardingView:
    ///   - gym: alle Templates
    ///   - homeGym: homeGym + noEquipment
    ///   - noEquipment: nur noEquipment
    /// Falls noch kein Profil existiert (sollte hier eigentlich nicht passieren
    /// — Profil ist Voraussetzung fuer MainTabView), fallen wir auf alle Plaene
    /// zurueck statt eine leere Liste zu zeigen.
    private var filteredTemplates: [ProgramTemplate] {
        guard let env = profiles.first?.environment else { return ProgramTemplates.all }
        return ProgramTemplates.all.filter { template in
            switch env {
            case .gym:         return true
            case .homeGym:     return template.targetEnvironment == .homeGym
                                     || template.targetEnvironment == .noEquipment
            case .noEquipment: return template.targetEnvironment == .noEquipment
            }
        }
    }

    private var userEnvironmentLabel: String {
        profiles.first?.environment.localizedName ?? "alle"
    }

    private func instantiate(_ template: ProgramTemplate) {
        let plan = ProgramInstantiator.instantiate(template, in: modelContext)
        dismiss()
        // Defer the navigation to the next runloop — gives the sheet's dismiss
        // animation time to start before the workout-stack mutation lands.
        // Without this small delay, the dismiss + navigationDestination(for:)
        // stack-update can race and the editor sometimes doesn't appear.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigation.workoutPath.append(plan)
        }
    }
}

// MARK: - Subview

@available(iOS 17.0, macOS 14.0, *)
private struct ProgramRow: View {
    let template: ProgramTemplate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconSystemName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.blue.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.body.weight(.semibold))
                    Text("·")
                    Text(template.focus)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(template.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(template.descriptionText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    ProgramTemplatePickerView()
        .modelContainer(PreviewSeed.maleProfileContainer)
        .environment(AppNavigation())
}
#endif
#endif
