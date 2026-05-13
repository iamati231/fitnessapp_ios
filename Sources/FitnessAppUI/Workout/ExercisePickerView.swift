#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Sheet for picking an exercise: searchable list of `ExerciseTemplate`s plus an
/// inline form for adding a custom exercise. Both branches return via callbacks so
/// the caller (DayEditor) owns the actual `Exercise` insertion.
///
/// **DEL-048**: optionaler `planEnvironment`-Parameter aktiviert eine Filter-
/// Toggle "Nur Übungen für meinen Plan-Typ". Wenn gesetzt + Toggle an,
/// blendet die Liste alle Uebungen aus, deren Equipment im aktuellen Plan-
/// Env nicht funktioniert (z.B. Maschinen in einem Bodyweight-Plan).
@available(iOS 17.0, macOS 14.0, *)
public struct ExercisePickerView: View {

    public var onSelect: (ExerciseTemplate) -> Void
    public var onCreateCustom: (String) -> Void

    /// DEL-048: aktueller Plan-Env-Kontext. Nil = kein Filter (zB Open-from-
    /// Settings o.ae.). Non-nil aktiviert die Equipment-Filter-Toggle.
    public var planEnvironment: EnvironmentType?

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]

    @State private var search: String = ""
    @State private var customName: String = ""
    @State private var filterToPlanEnv: Bool = true

    public init(
        planEnvironment: EnvironmentType? = nil,
        onSelect: @escaping (ExerciseTemplate) -> Void,
        onCreateCustom: @escaping (String) -> Void
    ) {
        self.planEnvironment = planEnvironment
        self.onSelect = onSelect
        self.onCreateCustom = onCreateCustom
    }

    public var body: some View {
        NavigationStack {
            List {
                if planEnvironment != nil {
                    filterSection
                }
                customSection
                librarySection
            }
            // `.navigationBarDrawer(displayMode:)` is iOS-only; default placement
            // works on both iOS and macOS toolchains.
            .searchable(text: $search, prompt: "Suche")
            .navigationTitle("Übung wählen")
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

    /// DEL-048: Equipment-Filter-Toggle. Default an, sodass der User in einem
    /// Bodyweight-Plan gar nicht erst Maschinen-Uebungen sieht. Toggle aus =
    /// volle Bibliothek + Bottom-Up-Konflikt-Detection im Caller springt an,
    /// wenn der User trotzdem eine inkompatible Uebung waehlt.
    @ViewBuilder
    private var filterSection: some View {
        if let env = planEnvironment {
            Section {
                Toggle(isOn: $filterToPlanEnv) {
                    Label("Nur Übungen für \(environmentLabel(env))",
                          systemImage: "line.3.horizontal.decrease.circle")
                }
            } footer: {
                Text("Wenn aus, siehst du auch Übungen, die zu deinem Plan-Typ nicht passen. Die App fragt dann beim Hinzufügen nach, ob du den Plan umstellen willst.")
                    .font(.footnote)
            }
        }
    }

    private func environmentLabel(_ env: EnvironmentType) -> String {
        switch env {
        case .gym:         return "Gym"
        case .homeGym:     return "Home-Gym"
        case .noEquipment: return "Bodyweight"
        }
    }

    // MARK: Sections

    private var customSection: some View {
        Section("Eigene Übung") {
            HStack {
                TextField("Name (z.B. Bankdrücken)", text: $customName)
                Button {
                    let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onCreateCustom(trimmed)
                    customName = ""
                    dismiss()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var librarySection: some View {
        if filteredTemplates.isEmpty {
            Section("Bibliothek") {
                if search.isEmpty {
                    Text("Bibliothek ist leer — leg oben deine erste eigene Übung an.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Keine Treffer für „\(search)\".")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Section("Bibliothek") {
                ForEach(filteredTemplates) { template in
                    Button {
                        onSelect(template)
                        dismiss()
                    } label: {
                        TemplateRow(template: template)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Derived

    private var filteredTemplates: [ExerciseTemplate] {
        let trimmed = search.trimmingCharacters(in: .whitespaces)
        var list = templates
        // DEL-048: Equipment-Filter VOR Suche, damit der Suchindex die
        // Maschinen-Uebungen in einem Bodyweight-Plan gar nicht erst trifft.
        if let env = planEnvironment, filterToPlanEnv {
            list = list.filter {
                // Custom-Uebungen werden NICHT gefiltert — der User hat sie
                // bewusst angelegt und weiss, was er tut. Sonst riskieren wir,
                // dass eigene "Pull-up @ Tuerrahmen" in einem Gym-Plan
                // ausgeblendet werden.
                $0.isCustom || ExerciseLibraryData.isEquipment($0.equipment, compatibleWith: env)
            }
        }
        guard !trimmed.isEmpty else { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct TemplateRow: View {
    let template: ExerciseTemplate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: equipmentIcon(template.equipment))
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.body)
                    if template.isCustom {
                        Text("Custom")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
                Text("\(muscleLabel(template.primaryMuscle)) • \(equipmentLabel(template.equipment))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func equipmentIcon(_ e: Equipment) -> String {
        switch e {
        case .barbell:     return "scalemass"
        case .dumbbell:    return "dumbbell"
        case .bodyweight:  return "figure.walk"
        case .machine:     return "gearshape"
        case .cable:       return "cable.connector"
        case .kettlebell:  return "circle.grid.cross"
        case .band:        return "infinity"
        }
    }

    private func equipmentLabel(_ e: Equipment) -> String {
        switch e {
        case .barbell:     return "Langhantel"
        case .dumbbell:    return "Kurzhantel"
        case .bodyweight:  return "Körpergewicht"
        case .machine:     return "Maschine"
        case .cable:       return "Kabel"
        case .kettlebell:  return "Kettlebell"
        case .band:        return "Band"
        }
    }

    private func muscleLabel(_ m: MuscleGroup) -> String {
        switch m {
        case .chest:      return "Brust"
        case .back:       return "Rücken"
        case .shoulders:  return "Schultern"
        case .biceps:     return "Bizeps"
        case .triceps:    return "Trizeps"
        case .quads:      return "Quadrizeps"
        case .hamstrings: return "Hamstrings"
        case .glutes:     return "Gesäß"
        case .calves:     return "Waden"
        case .core:       return "Core"
        }
    }
}
#endif
