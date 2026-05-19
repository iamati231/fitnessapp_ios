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
            .navigationTitle(Text("picker.exercise.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("common.cancel", bundle: .module)
                    }
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
                    Label {
                        Text(String(format: String(localized: "picker.exercise.filterFor", bundle: .module), environmentLabel(env)))
                    } icon: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            } footer: {
                Text("picker.exercise.filterHint", bundle: .module)
                    .font(.footnote)
            }
        }
    }

    // DEL-118: route durch die zentrale .localizedName-Extension.
    private func environmentLabel(_ env: EnvironmentType) -> String {
        String(localized: env.localizedName)
    }

    // MARK: Sections

    private var customSection: some View {
        Section("Eigene Übung") {
            HStack {
                TextField(String(localized: "picker.exercise.namePlaceholder", bundle: .module), text: $customName)
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

    /// DEL-074: Picker-Liste jetzt in Sections aufgeteilt:
    ///   1. "Eigene" — alle Custom-Templates oben (User-Anlagen, hoch
    ///       relevant fuer Quick-Pick).
    ///   2. Alphabetische A/B/C-…/Z-Sections wie iOS-Kontakte.
    /// Leerer Filter-Treffer rendert den klassischen Empty-State.
    @ViewBuilder
    private var librarySection: some View {
        if filteredTemplates.isEmpty {
            Section("Bibliothek") {
                if search.isEmpty {
                    Text("picker.exercise.libraryEmpty", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Keine Treffer für „\(search)\".")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // Custom oben — markiert mit Stern-Symbol-Section.
            let customs = filteredTemplates.filter(\.isCustom)
            if !customs.isEmpty {
                Section {
                    ForEach(customs) { template in
                        Button {
                            onSelect(template)
                            dismiss()
                        } label: {
                            TemplateRow(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Label("Eigene", systemImage: "star.fill")
                }
            }
            // Library alphabetisch in A/B/C-Sections.
            ForEach(alphabeticalGroups, id: \.letter) { group in
                Section(group.letter) {
                    ForEach(group.templates) { template in
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
    }

    /// DEL-074: Library-Templates (non-custom) alphabetisch nach Anfangs-
    /// buchstabe gruppiert. Umlaute werden zu ihrem Basis-Buchstaben
    /// gemappt (Ä→A, Ö→O, Ü→U), damit "Übung X" sauber unter "U" landet
    /// und nicht eine eigene Ä-Section bildet.
    private var alphabeticalGroups: [AlphabetGroup] {
        let nonCustoms = filteredTemplates.filter { !$0.isCustom }
        let grouped = Dictionary(grouping: nonCustoms) { letterKey(of: $0.name) }
        return grouped.keys.sorted().map { key in
            AlphabetGroup(
                letter: key,
                templates: grouped[key]?.sorted { $0.name.localizedCompare($1.name) == .orderedAscending } ?? []
            )
        }
    }

    private struct AlphabetGroup {
        let letter: String
        let templates: [ExerciseTemplate]
    }

    private func letterKey(of name: String) -> String {
        guard let first = name.first else { return "#" }
        // Umlaut-Mapping fuer die Section-Grouping.
        let mapped: Character
        switch first {
        case "Ä", "ä": mapped = "A"
        case "Ö", "ö": mapped = "O"
        case "Ü", "ü": mapped = "U"
        case "ß":      mapped = "S"
        default:       mapped = Character(first.uppercased())
        }
        return mapped.isLetter ? String(mapped) : "#"
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
                    // DEL-111: lokalisierter Display-Name — kanonische
                    // Lifts werden in DE/EN/TR-EN gerendert; custom +
                    // unannotierte Library-Eintraege fallen auf das
                    // gespeicherte `name`-Feld zurueck.
                    Text(template.displayName)
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

    // DEL-118: route durch die zentrale .localizedName-Extension statt
    // hardcoded German hier inline. Der Catalog ist die einzige Quelle der
    // Wahrheit fuer DE/EN/TR-Mappings.
    private func equipmentLabel(_ e: Equipment) -> String {
        String(localized: e.localizedName)
    }

    private func muscleLabel(_ m: MuscleGroup) -> String {
        String(localized: m.localizedName)
    }
}
#endif
