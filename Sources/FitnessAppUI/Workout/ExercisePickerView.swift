#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Sheet for picking an exercise: searchable list of `ExerciseTemplate`s plus an
/// inline form for adding a custom exercise. Both branches return via callbacks so
/// the caller (DayEditor) owns the actual `Exercise` insertion.
@available(iOS 17.0, macOS 14.0, *)
public struct ExercisePickerView: View {

    public var onSelect: (ExerciseTemplate) -> Void
    public var onCreateCustom: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]

    @State private var search: String = ""
    @State private var customName: String = ""

    public init(
        onSelect: @escaping (ExerciseTemplate) -> Void,
        onCreateCustom: @escaping (String) -> Void
    ) {
        self.onSelect = onSelect
        self.onCreateCustom = onCreateCustom
    }

    public var body: some View {
        NavigationStack {
            List {
                customSection
                librarySection
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Suche")
            .navigationTitle("Uebung waehlen")
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

    // MARK: Sections

    private var customSection: some View {
        Section("Eigene Uebung") {
            HStack {
                TextField("Name (z.B. Bankdruecken)", text: $customName)
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
                    Text("Bibliothek ist leer — leg oben deine erste eigene Uebung an.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Keine Treffer fuer „\(search)\".")
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
        guard !trimmed.isEmpty else { return templates }
        return templates.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
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
        case .bodyweight:  return "Koerpergewicht"
        case .machine:     return "Maschine"
        case .cable:       return "Kabel"
        case .kettlebell:  return "Kettlebell"
        case .band:        return "Band"
        }
    }

    private func muscleLabel(_ m: MuscleGroup) -> String {
        switch m {
        case .chest:      return "Brust"
        case .back:       return "Ruecken"
        case .shoulders:  return "Schultern"
        case .biceps:     return "Bizeps"
        case .triceps:    return "Trizeps"
        case .quads:      return "Quadrizeps"
        case .hamstrings: return "Hamstrings"
        case .glutes:     return "Gesaess"
        case .calves:     return "Waden"
        case .core:       return "Core"
        }
    }
}
#endif
