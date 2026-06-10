#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// DEL-161: Globale Uebungsbibliothek — bildschirmfuellendes Nachschlagewerk
/// aller Templates (System + Custom), erreichbar aus dem "Mehr"-Tab.
///
///   * Durchsuchbar; Custom oben, danach nach Muskelgruppe gruppiert.
///   * Tap → `ExerciseLibraryEditorSheet` (Custom editierbar, System read-only).
///   * Toolbar-"+" → neue Custom-Uebung anlegen.
///   * Swipe-Delete (mit Confirm) NUR fuer Custom-Eintraege.
@available(iOS 17.0, macOS 14.0, *)
public struct ExerciseLibraryView: View {

    // MARK: - DEL-210 Picker-Modus
    //
    // EINE Komponente für Bibliothek (Settings) UND Übungs-Auswahl
    // (DayEditor, Ad-Hoc-Workout, Summary-Edit). Der Modus hängt am
    // Callback:
    //   * onExerciseSelected == nil → Bibliotheks-Modus: Tap öffnet den
    //     Metadaten-Editor, alles wie bisher.
    //   * onExerciseSelected != nil → Picker-Modus: Tap feuert den
    //     Callback; der Sheet-Wrapper (ExerciseLibraryPickerSheet)
    //     dismissed. Such-/Filter-/Verlauf-Features bleiben identisch —
    //     genau die geforderte UI-Konsistenz.

    /// DEL-048-Feature (portiert aus dem alten ExercisePickerView):
    /// Plan-Env-Kontext aktiviert die "Nur Übungen für meinen Plan-Typ"-
    /// Toggle. Nil = kein Env-Filter (Settings-Bibliothek).
    public var planEnvironment: EnvironmentType?
    /// Picker-Modus-Schalter + Auswahl-Callback.
    public var onExerciseSelected: ((ExerciseTemplate) -> Void)?
    /// DEL-159-Flow (portiert): Custom-Übung anlegen liefert den Draft an
    /// den Caller, der Template + Plan-Exercise baut. Nur im Picker-Modus
    /// relevant; nil → "+"-Button nutzt den normalen Library-Editor.
    public var onCreateCustom: ((CustomExerciseDraft) -> Void)?

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]

    @State private var search: String = ""
    /// Tap auf eine Zeile → Editor-Sheet fuer dieses Template.
    @State private var selectedTemplate: ExerciseTemplate?
    /// DEL-201: Leading-Swipe "Verlauf" → Push auf den Übungs-Detail-Screen.
    @State private var historyTemplate: ExerciseTemplate?
    /// Toolbar-"+" → Create-Sheet.
    @State private var showingCreate: Bool = false
    /// Swipe-Delete → Confirm-Gate.
    @State private var pendingDelete: ExerciseTemplate?

    // DEL-162: Equipment-/Muskel-Filter — gespiegelt vom ExercisePicker, damit
    // die Bibliothek dieselben Filter-Affordances bietet.
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var showingFilterSheet: Bool = false

    private var hasActiveFilters: Bool {
        !selectedEquipment.isEmpty || !selectedMuscles.isEmpty
    }

    /// DEL-048 (portiert): Default an — im Bodyweight-Plan sieht der User
    /// Maschinen-Übungen gar nicht erst.
    @State private var filterToPlanEnv: Bool = true
    /// DEL-210: Draft-Erstell-Sheet im Picker-Modus.
    @State private var showingDraftSheet: Bool = false

    private var isPickerMode: Bool { onExerciseSelected != nil }

    public init(
        planEnvironment: EnvironmentType? = nil,
        onExerciseSelected: ((ExerciseTemplate) -> Void)? = nil,
        onCreateCustom: ((CustomExerciseDraft) -> Void)? = nil
    ) {
        self.planEnvironment = planEnvironment
        self.onExerciseSelected = onExerciseSelected
        self.onCreateCustom = onCreateCustom
    }

    public var body: some View {
        List {
            // DEL-210: Plan-Env-Filter-Toggle (DEL-048, portiert) — nur
            // wenn ein Plan-Kontext mitkommt.
            if planEnvironment != nil {
                planEnvFilterSection
            }
            customSection
            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                muscleSection(muscle)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .searchable(text: $search,
                    prompt: Text("library.searchPlaceholder", bundle: .module))
        .navigationTitle(Text("library.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            // DEL-162: Filter-Button (Equipment/Muskel) — wie im Picker, mit
            // Badge-Variante wenn ein Filter aktiv ist.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingFilterSheet = true
                } label: {
                    Image(systemName: hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(hasActiveFilters ? Color.deltiqOrange : Color.primary)
                }
                .accessibilityLabel(Text("picker.exercise.filter.button.a11y", bundle: .module))
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // DEL-210: Picker-Modus mit Draft-Callback → DEL-159-
                    // Flow (Caller baut Template + Exercise). Sonst der
                    // normale Library-Editor.
                    if isPickerMode && onCreateCustom != nil {
                        showingDraftSheet = true
                    } else {
                        showingCreate = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("library.newExercise", bundle: .module))
            }
        }
        .sheet(item: $selectedTemplate) { template in
            ExerciseLibraryEditorSheet(template: template)
        }
        // DEL-201: Übungs-Detail-Push. Leading-Swipe auf einer Zeile setzt
        // historyTemplate; der Detail-Screen identifiziert die Historie
        // über den System-Namen (Snapshot-Matching, DEL-051).
        .navigationDestination(item: $historyTemplate) { template in
            ExerciseDetailView(
                systemName: template.name,
                displayName: template.displayName,
                isCardio: template.isCardio
            )
        }
        .sheet(isPresented: $showingCreate) {
            ExerciseLibraryEditorSheet(template: nil)
        }
        // DEL-210: Custom-Draft-Sheet im Picker-Modus (DEL-159-Flow). Der
        // Suchtext wird als Start-Name übernommen — typischer Pfad: User
        // sucht, findet nichts, legt genau das an.
        .sheet(isPresented: $showingDraftSheet) {
            NewCustomExerciseSheet(initialName: search) { draft in
                onCreateCustom?(draft)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(
                selectedEquipment: $selectedEquipment,
                selectedMuscles: $selectedMuscles
            )
        }
        .confirmationDialog(
            Text("editor.exercise.deleteConfirmTitle", bundle: .module),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                if let t = pendingDelete { deleteTemplate(t) }
                pendingDelete = nil
            } label: {
                Text("editor.exercise.deleteConfirmCta", bundle: .module)
            }
            Button(role: .cancel) { pendingDelete = nil } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("editor.exercise.deleteConfirmMessage", bundle: .module)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var customSection: some View {
        let customs = filtered.filter(\.isCustom)
        if !customs.isEmpty {
            Section {
                ForEach(customs) { template in
                    row(template)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingDelete = template
                            } label: {
                                Label {
                                    Text("editor.exercise.delete", bundle: .module)
                                } icon: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                }
            } header: {
                Label {
                    Text("picker.exercise.section.customs", bundle: .module)
                } icon: {
                    Image(systemName: "star.fill")
                }
            }
        }
    }

    @ViewBuilder
    private func muscleSection(_ muscle: MuscleGroup) -> some View {
        let items = filtered.filter { !$0.isCustom && $0.primaryMuscle == muscle }
        if !items.isEmpty {
            Section {
                ForEach(items) { template in
                    row(template)
                }
            } header: {
                Text(muscle.localizedName)
            }
        }
    }

    // MARK: Row

    private func row(_ template: ExerciseTemplate) -> some View {
        rowContent(template)
            // DEL-201: Leading-Swipe öffnet den Verlaufs-Screen. Auf der
            // Row selbst (nicht im Section-ForEach), damit System- UND
            // Custom-Übungen den Swipe bekommen.
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    historyTemplate = template
                } label: {
                    Label {
                        Text("library.row.history", bundle: .module)
                    } icon: {
                        Image(systemName: "chart.xyaxis.line")
                    }
                }
                .tint(Color.deltiqOrange)
            }
    }

    private func rowContent(_ template: ExerciseTemplate) -> some View {
        Button {
            // DEL-210: Picker-Modus → Auswahl-Callback statt Editor.
            if let onExerciseSelected {
                onExerciseSelected(template)
            } else {
                selectedTemplate = template
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: equipmentIcon(template.equipment))
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.deltiqOrange.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(template.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if template.isCustom {
                            Text("picker.exercise.customBadge", bundle: .module)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.15))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(String(localized: template.primaryMuscle.localizedName)) • \(String(localized: template.equipment.localizedName))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Derived + actions

    /// Such- + Filter-gefilterte Templates: Volltext (Display-Name + roher
    /// DE-Name) UND die Equipment-/Muskel-Multi-Select-Filter (DEL-162).
    /// DEL-048 (portiert): "Nur Übungen für meinen Plan-Typ"-Toggle.
    @ViewBuilder
    private var planEnvFilterSection: some View {
        if let env = planEnvironment {
            Section {
                Toggle(isOn: $filterToPlanEnv) {
                    Label {
                        Text(String(format: String(localized: "picker.exercise.filterFor", bundle: .module),
                                    String(localized: env.localizedName)))
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

    private var filtered: [ExerciseTemplate] {
        var list = templates
        // DEL-048 (portiert): Env-Filter VOR der Suche. Custom-Übungen
        // sind ausgenommen — die hat der User bewusst angelegt.
        if let env = planEnvironment, filterToPlanEnv {
            list = list.filter {
                $0.isCustom || ExerciseLibraryData.isEquipment($0.equipment, compatibleWith: env)
            }
        }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.displayName.lowercased().contains(q) || $0.name.lowercased().contains(q)
            }
        }
        if !selectedEquipment.isEmpty {
            list = list.filter { selectedEquipment.contains($0.equipment) }
        }
        if !selectedMuscles.isEmpty {
            list = list.filter { selectedMuscles.contains($0.primaryMuscle) }
        }
        return list
    }

    /// Loescht ein Custom-Template (System-Eintraege erreichen den Swipe nicht).
    /// Safe: Exercise/Log halten keine Relationship aufs Template (Match by
    /// name, Felder kopiert) — es wird nichts kaskadiert.
    private func deleteTemplate(_ template: ExerciseTemplate) {
        guard template.isCustom else { return }
        modelContext.delete(template)
        try? modelContext.save()
    }

    /// DEL-210: Bibliothek + Picker SIND jetzt dieselbe View — die
    /// frühere Spiegelung zum separaten ExercisePickerView entfällt.
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
}

// MARK: - DEL-210 Picker-Sheet-Wrapper

/// Drop-in-Ersatz für den gelöschten `ExercisePickerView`: dieselbe
/// Signatur (planEnvironment / onSelect / onCreateCustom), aber innen
/// rendert die ECHTE Übungsbibliothek im Picker-Modus — identisches
/// Layout, Suche, Filter und Verlaufs-Swipe wie unter Einstellungen.
///
/// Eigene NavigationStack + Abbrechen-Button, dismissed sich selbst
/// nach Auswahl/Erstellung — Call-Sites brauchen nur den Typnamen zu
/// tauschen.
@available(iOS 17.0, macOS 14.0, *)
public struct ExerciseLibraryPickerSheet: View {

    public let planEnvironment: EnvironmentType?
    public let onSelect: (ExerciseTemplate) -> Void
    public let onCreateCustom: (CustomExerciseDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    public init(
        planEnvironment: EnvironmentType? = nil,
        onSelect: @escaping (ExerciseTemplate) -> Void,
        onCreateCustom: @escaping (CustomExerciseDraft) -> Void
    ) {
        self.planEnvironment = planEnvironment
        self.onSelect = onSelect
        self.onCreateCustom = onCreateCustom
    }

    public var body: some View {
        NavigationStack {
            ExerciseLibraryView(
                planEnvironment: planEnvironment,
                onExerciseSelected: { template in
                    onSelect(template)
                    dismiss()
                },
                onCreateCustom: { draft in
                    onCreateCustom(draft)
                    dismiss()
                }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
            }
        }
    }
}
#endif
