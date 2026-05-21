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

    /// DEL-136 Part D: Multi-Select-Filter fuer Library-Suche. Sets sind
    /// leer = kein Filter aktiv, sonst werden nur Templates angezeigt deren
    /// Equipment / primaryMuscle im jeweiligen Set sind.
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var showingFilterSheet: Bool = false

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
            // DEL-135: i18n des Search-Prompts.
            .searchable(text: $search,
                        prompt: Text("picker.exercise.searchPlaceholder", bundle: .module))
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
                // DEL-136 Part D: Filter-Button mit Badge wenn Filter aktiv.
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(hasActiveFilters
                                             ? Color.deltiqOrange
                                             : Color.primary)
                    }
                    .accessibilityLabel(Text("picker.exercise.filter.button.a11y", bundle: .module))
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    selectedEquipment: $selectedEquipment,
                    selectedMuscles: $selectedMuscles
                )
            }
        }
    }

    /// DEL-136 Part D: True wenn mindestens ein Filter gesetzt ist (faerbt
    /// das Filter-Icon orange + macht es zur fill-Variante mit Punkt).
    private var hasActiveFilters: Bool {
        !selectedEquipment.isEmpty || !selectedMuscles.isEmpty
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
        // DEL-135: lokalisierter Section-Header via xcstrings.
        Section {
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
        } header: {
            Text("picker.exercise.section.customTitle", bundle: .module)
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
            // DEL-135: lokalisierter Section-Header + No-Match-Text.
            Section {
                if search.isEmpty {
                    Text("picker.exercise.libraryEmpty", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    // %@ wird zur eingegebenen Such-Phrase
                    Text(String(format: String(localized: "picker.exercise.noMatchFormat",
                                                bundle: .module),
                                search))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("picker.exercise.section.library", bundle: .module)
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
                    // DEL-135: lokalisierter Header.
                    Label {
                        Text("picker.exercise.section.customs", bundle: .module)
                    } icon: {
                        Image(systemName: "star.fill")
                    }
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
    ///
    /// DEL-135 i18n-Fix: Gruppierung + Sortierung laufen jetzt auf
    /// `template.displayName` (lokalisierter Anzeige-Name) statt
    /// `template.name` (deutscher Base-Key). Vorher landete "Kolay Koşu"
    /// (TR) unter "E" (weil base="Easy Run") — jetzt korrekt unter "K".
    /// `localizedStandardCompare` macht die sprachspezifisch korrekte
    /// Alphabetisierung (z.B. TR: i/İ Sortierung anders als EN).
    private var alphabeticalGroups: [AlphabetGroup] {
        let nonCustoms = filteredTemplates.filter { !$0.isCustom }
        let grouped = Dictionary(grouping: nonCustoms) { letterKey(of: $0.displayName) }
        return grouped.keys.sorted().map { key in
            AlphabetGroup(
                letter: key,
                templates: grouped[key]?.sorted {
                    $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
                } ?? []
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
        // DEL-136 Part D: User-Filter (Equipment + Muscle Group). Logic:
        //   * Leerer Filter-Set → kein Filter aktiv fuer diese Dimension
        //   * Non-leer → Template muss in der Menge sein
        //   * Custom-Templates werden bewusst MIT gefiltert (anders als der
        //     planEnv-Filter oben) — User-Filter sind explizite Wahl, da
        //     soll der Custom-Status nicht zur Ausnahme werden.
        if !selectedEquipment.isEmpty {
            list = list.filter { selectedEquipment.contains($0.equipment) }
        }
        if !selectedMuscles.isEmpty {
            list = list.filter { selectedMuscles.contains($0.primaryMuscle) }
        }
        guard !trimmed.isEmpty else { return list }
        // DEL-135 i18n-Fix: Suche im lokalisierten Anzeige-Namen statt
        // im deutschen Base-Key. Vorher musste ein türkischer User
        // nach "Easy Run" suchen, um den Lauf-Eintrag zu finden, der
        // im UI als "Kolay Koşu" angezeigt wird.
        // `localizedCaseInsensitiveContains` ist sprach-aware: matched
        // TR "İ" auf "i", DE "ß" auf "ss", etc. — korrekt fuer alle
        // drei App-Sprachen.
        return list.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
    }
}

// MARK: - Subviews

@available(iOS 17.0, macOS 14.0, *)
private struct TemplateRow: View {
    let template: ExerciseTemplate

    var body: some View {
        HStack(spacing: 12) {
            // DEL-135 i18n-Fix Bug 3: vorher `Color.accentColor` (= das
            // Asset-Catalog AccentColor, in unserem Setup blau). Beim
            // Aktivieren der Search-Bar rendert iOS die Results-Liste in
            // einem separaten View-Container, der den vom Parent gesetzten
            // accent-Tint NICHT erbt → Icons sprangen plötzlich auf
            // System-Blau statt Brand-Orange. Explizit `Color.deltiqOrange`
            // hartgekoppelt → bleibt konsistent, egal in welchem
            // searchable-Sub-Container die Row gerendert wird.
            Image(systemName: equipmentIcon(template.equipment))
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.deltiqOrange.gradient)
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
                        // DEL-135: lokalisierter Custom-Badge.
                        Text("picker.exercise.customBadge", bundle: .module)
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

// MARK: - DEL-136 Part D: Library Filter Sheet

/// Multi-Select-Filter für Equipment + Muscle Group. Zwei Sections,
/// jeweils mit allen verfuegbaren Cases als Toggle-Rows. Per-row Tap
/// macht das Toggle smooth + spring-animiert. Footer-Button raeumt alle
/// Filter weg. Dismissal via Drag-down oder "Fertig"-Toolbar-Button.
@available(iOS 17.0, macOS 14.0, *)
private struct FilterSheet: View {
    @Binding var selectedEquipment: Set<Equipment>
    @Binding var selectedMuscles: Set<MuscleGroup>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        FilterToggleRow(
                            label: String(localized: equipment.localizedName),
                            isOn: Binding(
                                get: { selectedEquipment.contains(equipment) },
                                set: { newValue in
                                    if newValue { selectedEquipment.insert(equipment) }
                                    else        { selectedEquipment.remove(equipment) }
                                }
                            )
                        )
                    }
                } header: {
                    Text("picker.exercise.filter.section.equipment", bundle: .module)
                }

                Section {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        FilterToggleRow(
                            label: String(localized: muscle.localizedName),
                            isOn: Binding(
                                get: { selectedMuscles.contains(muscle) },
                                set: { newValue in
                                    if newValue { selectedMuscles.insert(muscle) }
                                    else        { selectedMuscles.remove(muscle) }
                                }
                            )
                        )
                    }
                } header: {
                    Text("picker.exercise.filter.section.muscle", bundle: .module)
                }

                // Reset-Button am Ende. Disabled wenn schon nichts ausgewaehlt.
                Section {
                    Button(role: .destructive) {
                        selectedEquipment.removeAll()
                        selectedMuscles.removeAll()
                    } label: {
                        HStack {
                            Spacer()
                            Text("picker.exercise.filter.reset", bundle: .module)
                                .font(.body.weight(.semibold))
                            Spacer()
                        }
                    }
                    .disabled(selectedEquipment.isEmpty && selectedMuscles.isEmpty)
                }
            }
            .navigationTitle(Text("picker.exercise.filter.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text("common.done", bundle: .module)
                    }
                }
            }
        }
    }
}

/// Kleine Helper-Row mit Checkmark-Indikator statt iOS-Toggle-Switch.
/// Tap toggled den Bool und triggered die Animation; visuell aufgeraeumter
/// als Switch fuer multi-select Listen.
@available(iOS 17.0, macOS 14.0, *)
private struct FilterToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        } label: {
            HStack {
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.deltiqOrange : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif
