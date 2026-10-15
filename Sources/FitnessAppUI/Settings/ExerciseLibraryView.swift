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
///   * Kopfzeilen-"+" → neue Custom-Uebung anlegen.
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
    @Environment(\.dismiss) private var dismiss

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
        // Signature-Geruest: eigene Kopfzone statt navigationTitle/Toolbar.
        // `List` bleibt Container - beide Swipe-Richtungen (Verlauf links,
        // Loeschen rechts) sind fuer diese Liste funktional wesentlich,
        // anders als bei Rechner/Wassertracker. `.searchable` faellt weg:
        // haengt sich normalerweise an die native Navigationsleiste, die
        // hier ausgeblendet ist - eigenes `searchField` bleibt stattdessen
        // fix zwischen Kopfzone und Liste sichtbar (kein Wegscrollen bei
        // einer potenziell langen Bibliothek).
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "library.title", bundle: .module),
                onBack: { dismiss() },
                actions: [
                    // DEL-162: Filter-Button (Equipment/Muskel) — Akzent-
                    // Highlight wenn ein Filter aktiv ist.
                    DeltiqHeaderAction(
                        systemImage: hasActiveFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle",
                        isHighlighted: hasActiveFilters
                    ) {
                        showingFilterSheet = true
                    },
                    DeltiqHeaderAction(systemImage: "plus") {
                        // DEL-210: Picker-Modus mit Draft-Callback → DEL-159-
                        // Flow (Caller baut Template + Exercise). Sonst der
                        // normale Library-Editor.
                        if isPickerMode && onCreateCustom != nil {
                            showingDraftSheet = true
                        } else {
                            showingCreate = true
                        }
                    }
                ]
            )

            searchField
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

            List {
                // DEL-210: Plan-Env-Filter-Toggle (DEL-048, portiert) — nur
                // wenn ein Plan-Kontext mitkommt.
                if planEnvironment != nil {
                    planEnvFilterSection
                }
                // EXLIB-02/03: Suche/Filter ohne Treffer rendert sonst eine
                // stumme leere Liste — expliziter Hinweis statt Stille.
                if filtered.isEmpty {
                    noResultsRow
                } else {
                    customSection
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        muscleSection(muscle)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        // Bug-Fix: .navigationBarBackButtonHidden(true) nimmt auf iOS die
        // Swipe-Back-Geste als Nebenwirkung mit runter - siehe
        // deltiqSwipeBackEnabled()-Dokumentation in Theme.swift. Harmlos im
        // Picker-Sheet-Modus (dort ist die View die Wurzel ihres eigenen
        // NavigationStacks, es gibt nichts zum Zurueckwischen).
        .deltiqSwipeBackEnabled()
        .sheet(item: $selectedTemplate) { template in
            ExerciseLibraryEditorSheet(template: template)
        }
        // DEL-201: Übungs-Detail-Push. Leading-Swipe auf einer Zeile setzt
        // historyTemplate; der Detail-Screen identifiziert die Historie seit
        // Settings-Epic Phase 6 (EXLIB-07/09) primaer ueber die stabile
        // `template.id`, mit Namens-Snapshot als Fallback fuer Alt-Daten.
        .navigationDestination(item: $historyTemplate) { template in
            ExerciseDetailView(
                systemName: template.name,
                exerciseTemplateID: template.id,
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

    // MARK: - Suche

    /// Ersatz fuer `.searchable()` (siehe Kommentar in `body`) - gleiche
    /// ruhige Fill-Flaeche wie `DeltiqSegmentedPicker`s Spur, damit sich
    /// das Suchfeld optisch in die bestehende Token-Sprache einreiht.
    /// `.autocorrectionDisabled()` gleicht das an, was `.searchable()`
    /// (UISearchBar-basiert) schon immer implizit mitbrachte.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Deltiq.textSecondary)
            TextField(
                String(localized: "library.searchPlaceholder", bundle: .module),
                text: $search
            )
            .font(.system(size: 15))
            .foregroundStyle(Color.primary)
            .autocorrectionDisabled()
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.Deltiq.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.Deltiq.fill)
        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
    }

    // MARK: Sections

    /// Eyebrow-Stil statt der nativen List-Section-Header-Konvention.
    /// Nimmt (anders als in anderen Screens) einen bereits aufgeloesten
    /// String statt eines Lokalisierungs-Keys entgegen, da Muskelgruppen-
    /// Header ueber `MuscleGroup.localizedName` (LocalizedStringResource)
    /// statt eines eigenen xcstrings-Keys aufgeloest werden.
    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(Color.deltiqOrange)
            .textCase(nil)
    }

    @ViewBuilder
    /// EXLIB-02/03: Expliziter No-Results-State, wenn Suche/Filter alles
    /// ausschliessen. Kein CTA — der Ausweg ist, Suchtext/Filter anzupassen,
    /// nicht eine Aktion hier auf der Zeile.
    private var noResultsRow: some View {
        DashboardEmptyState(
            icon: "magnifyingglass",
            title: "library.noResults.title",
            description: "library.noResults.description"
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

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
                // Stern-Icon entfaellt - kein anderer Section-Header im
                // Signature-Geruest traegt ein Icon; die "EIGEN"-Pill an
                // jeder Zeile markiert Custom-Uebungen bereits eindeutig.
                sectionHeader(String(localized: "picker.exercise.section.customs", bundle: .module))
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
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
                sectionHeader(String(localized: muscle.localizedName))
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        }
    }

    // MARK: Row

    private func row(_ template: ExerciseTemplate) -> some View {
        rowContent(template)
            .listRowBackground(Color.Deltiq.surface)
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
                ExerciseGifView(exerciseName: template.name, displayName: template.displayName, animated: false)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(template.displayName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.primary)
                        if template.isCustom {
                            // Handoff 1.10 (ein Akzent): war Lila, jetzt
                            // dieselbe Orange-DeltiqPill wie ueberall sonst.
                            DeltiqPill(String(localized: "picker.exercise.customBadge", bundle: .module).uppercased(), style: .accent)
                        }
                    }
                    Text("\(String(localized: template.primaryMuscle.localizedName)) • \(String(localized: template.equipment.localizedName))")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Deltiq.textTertiary)
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
                            .font(.system(size: 15))
                    } icon: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                .tint(Color.deltiqOrange)
                .listRowBackground(Color.Deltiq.surface)
            } footer: {
                Text("picker.exercise.filterHint", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
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

}

// MARK: - DEL-210 Picker-Sheet-Wrapper

/// Drop-in-Ersatz für den gelöschten `ExercisePickerView`: dieselbe
/// Signatur (planEnvironment / onSelect / onCreateCustom), aber innen
/// rendert die ECHTE Übungsbibliothek im Picker-Modus — identisches
/// Layout, Suche, Filter und Verlaufs-Swipe wie unter Einstellungen.
///
/// Eigene NavigationStack, dismissed sich selbst nach Auswahl/Erstellung
/// (Abbrechen laeuft ueber die DeltiqHeader-Kopfzone der eingebetteten
/// View, siehe Kommentar in `body`) — Call-Sites brauchen nur den
/// Typnamen zu tauschen.
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
            // Signature-Geruest: ExerciseLibraryView blendet die native
            // Navigationsleiste jetzt selbst aus (eigene DeltiqHeader-
            // Kopfzone) - ein hier angehaengtes .toolbar-Abbrechen-Item
            // wuerde dadurch nie sichtbar. Dismiss laeuft stattdessen ueber
            // den Zurueck-Chevron der DeltiqHeader-Kopfzone, der intern
            // ebenfalls `dismiss()` aufruft (funktioniert fuer Sheets genau
            // wie fuer Stack-Pushes).
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
        }
    }
}
#endif
