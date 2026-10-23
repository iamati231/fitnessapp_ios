#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppAI
import FitnessAppFoodLookup

/// Task 8 (docs/superpowers/sdd/2026-10-22-ui-consistency): Feldwerte einer
/// `MealDraft.Item`-Position fuer `AddMealView.isDirty` -- `MealDraft.Item`
/// selbst ist nicht `Equatable` (siehe dortige Doku), und Edit-Mode startet
/// mit vorbefuellten Items aus der bestehenden Mahlzeit, die fuer sich allein
/// NICHT dirty machen duerfen (Vergleich gegen `itemsAtOpen`). `internal`
/// statt `private`, damit ein Test (siehe `Tests/FitnessAppUITests`) die
/// Capture-Logik per `@testable import` direkt pruefen kann -- gleiches
/// Prinzip wie `ExerciseSnapshot`/`MeasurementFieldSnapshot`.
@available(iOS 17.0, macOS 14.0, *)
struct MealDraftItemFieldsSnapshot: Equatable {
    let catalogID: String?
    let nameSnapshot: String
    let quantity: Double
    let unit: FoodUnit

    static func capture(from items: [MealDraft.Item]) -> [MealDraftItemFieldsSnapshot] {
        items.map {
            MealDraftItemFieldsSnapshot(catalogID: $0.catalogID, nameSnapshot: $0.nameSnapshot, quantity: $0.quantity, unit: $0.unit)
        }
    }
}

/// Task 6: Erfassungs-Sheet fuer eine neue Mahlzeit. Sammelt Positionen in
/// einem `MealDraft` (reine Vorschau, siehe dortige Doku) und persistiert
/// erst beim expliziten "Speichern"-Tap ueber `MealDraft.save(into:)`.
/// "Abbrechen" verwirft den Draft kommentarlos — kein `save()`-Aufruf, also
/// keine Spur im Context.
///
/// Baut auf dem bewaehrten Form+NavigationStack-Muster von
/// `NewCustomExerciseSheet` (Cancel/Save als Toolbar-Items) statt auf dem
/// DeltiqHeader-Vollbild-Geruest — fuer ein mehrteiliges Erfassungs-Sheet mit
/// Live-Suche ist das native `Form` robuster als neu zusammengesetzte
/// Deltiq-Bausteine.
@available(iOS 17.0, macOS 14.0, *)
public struct AddMealView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // Task E (M2 in task-D-review.md): explicit UI locale instead of
    // NutritionAIService's `.current` default, so the availability/language
    // check always follows the language the user actually sees.
    @Environment(\.locale) private var locale

    @StateObject private var draft: MealDraft

    /// Non-nil im Edit-Modus (Task 7) — bestimmt Titel/Button-Labels und
    /// schaltet den Loeschen-Button frei. Das Loeschen der ganzen Mahlzeit
    /// laeuft bewusst NICHT ueber `MealDraft` (das kennt nur den Positions-
    /// Entwurf), sondern direkt via `context.delete(meal)`.
    private let editingMeal: MealEntry?

    @Query(sort: \FoodCatalogEntry.catalogID)
    private var catalogEntries: [FoodCatalogEntry]

    @State private var searchText: String = ""
    @State private var selectedEntry: FoodCatalogEntry?
    @State private var quantity: Double?
    @State private var selectedUnit: FoodUnit = .gram
    /// UI-Konsistenz-Fix: war vorher ein blockierendes SwiftUI-Alert -- als
    /// einziger Form-Editor im ganzen Repo wich `AddMealView` damit vom
    /// etablierten Muster ab (inline-Fehlertext als Form-Row), das sowohl
    /// das eigene `aiErrorMessage`/`onlineSearch.errorMessage` in dieser
    /// Datei als auch `CustomFoodEntrySheet.saveErrorMessage` (selbe Datei-
    /// Familie, ebenfalls natives Form+NavigationStack-Geruest) bereits
    /// verwenden. Gleicher Stil: `.font(.caption)` + `Color.Deltiq.textSecondary`.
    @State private var saveErrorMessage: String?
    @State private var showingDeleteConfirm: Bool = false
    /// Task 8 (docs/superpowers/sdd/2026-10-22-ui-consistency): siehe
    /// `isDirty`/`discardChangesConfirmation` unten.
    @State private var showingDiscardConfirm: Bool = false

    /// Task 8: Positionen beim Oeffnen -- Vergleichsbasis fuer `isDirty` im
    /// Edit-Mode (Task 7), wo `draft.items` von Anfang an vorbefuellt ist und
    /// deshalb allein NICHT als "etwas zu verlieren" zaehlen darf. New-Mode
    /// startet immer leer. Gleiches Prinzip wie `MeasurementView.fieldsAtOpen`.
    private let itemsAtOpen: [MealDraftItemFieldsSnapshot]

    /// Fix-Runde 1 (Befund 2): `draft.date`/`draft.mealType` sind echte Felder,
    /// die `MealDraft.save()` im Edit-Mode mit zurueckschreibt (siehe
    /// `MealDraft.save(into:)` -- `meal.date = date; meal.mealType = mealType`),
    /// aber `isDirty` hat sie bisher nicht geprueft -- ein Verschieben auf
    /// einen anderen Tag/Mahlzeittyp ging beim Abbrechen kommentarlos
    /// verloren, ohne Verwerfen-Rueckfrage. Snapshot nach demselben Prinzip
    /// wie `itemsAtOpen` oben.
    private let dateAtOpen: Date
    private let mealTypeAtOpen: MealType

    // Task 6: manuelles Anlegen eines eigenen Lebensmittels — unabhaengig
    // von Netz/KI (siehe `CustomFoodEntrySheet`/`CustomFoodDraft`).
    @State private var showingCustomFoodEntry: Bool = false
    @State private var customFoodPrefillName: String = ""

    // Task E: local AI-assisted free-text meal draft parsing.
    @State private var aiInputText: String = ""
    @State private var isExtracting: Bool = false
    @State private var aiCandidates: [MealDraftCandidate] = []
    @State private var aiErrorMessage: String?

    /// Task 4 (docs/superpowers/sdd/2026-10-22-online-food-lookup): same
    /// AppStorage key/default Task 3 already declared in
    /// `SettingsDataConnectionsView` — today's behavior (no toggle = no
    /// online action at all) stays exactly as-is when this is `false`.
    @AppStorage("onlineFoodLookupEnabled") private var onlineFoodLookupEnabled: Bool = false
    @StateObject private var onlineSearch = OnlineFoodSearchController(
        searcher: OpenFoodFactsSearchClient(userAgent: "Deltiq/1.0 (a.isik@atamya.com)")
    )
    /// Final-review fix (important): `onlineSearch` is ONE shared controller
    /// for both entry points (manual search + any unmatched AI candidate),
    /// so its `candidates`/`errorMessage`/`isSearching` alone can't say WHICH
    /// row started the running/last search. This tracks that, so the
    /// results list/error/spinner render under exactly one row instead of
    /// every unmatched candidate (and the manual section) at once.
    private enum OnlineSearchOrigin: Equatable {
        case manual
        case aiCandidate(MealDraftCandidate)
    }
    @State private var onlineSearchOrigin: OnlineSearchOrigin?

    public init(date: Date = Date(), mealType: MealType = .snack) {
        _draft = StateObject(wrappedValue: MealDraft(date: date, mealType: mealType))
        self.editingMeal = nil
        self.itemsAtOpen = []
        self.dateAtOpen = date
        self.mealTypeAtOpen = mealType
    }

    public init(editing meal: MealEntry) {
        let newDraft = MealDraft(editing: meal)
        _draft = StateObject(wrappedValue: newDraft)
        self.editingMeal = meal
        self.itemsAtOpen = MealDraftItemFieldsSnapshot.capture(from: newDraft.items)
        self.dateAtOpen = meal.date
        self.mealTypeAtOpen = meal.mealType
    }

    public var body: some View {
        NavigationStack {
            Form {
                detailsSection
                aiSection
                searchSection
                if !draft.items.isEmpty {
                    itemsSection
                    previewSection
                }
                if editingMeal != nil {
                    deleteSection
                }
                // UI-Konsistenz-Fix: ersetzt den vormaligen SwiftUI-Alert
                // -- gleiche Section-Form wie `CustomFoodEntrySheet`s eigene
                // `saveErrorMessage`-Row.
                if let saveErrorMessage {
                    Section {
                        Text(saveErrorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .listRowBackground(Color.Deltiq.surface)
                    }
                    .listRowSeparatorTint(Color.Deltiq.divider)
                }
            }
            // Task A: Mengenbereich haengt NICHT mehr im scrollenden Form-Flow
            // (vorher musste man die bis zu ~130 Eintraege lange Trefferliste
            // ganz durchscrollen, um ihn ueberhaupt zu erreichen) — stattdessen
            // unten verankert, unabhaengig vom Scroll-Stand der Suche. Exaktes
            // Vorbild: ActiveWorkoutView.swift's RestTimerBar-safeAreaInset.
            .safeAreaInset(edge: .bottom) {
                if let selectedEntry {
                    quantityBottomBar(for: selectedEntry)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text(editingMeal == nil ? "nutrition.addMeal.title" : "nutrition.editMeal.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .keyboardDismissToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Task 8: verwirft den MealDraft weiterhin kommentarlos
                    // OHNE Entwurfsdaten (kein save()-Aufruf, keine Spur im
                    // ModelContext) -- MIT Entwurfsdaten (siehe `isDirty`)
                    // fragt derselbe Button jetzt erst per
                    // `discardChangesConfirmation` nach.
                    Button {
                        isDirty ? (showingDiscardConfirm = true) : dismiss()
                    } label: {
                        Text("nutrition.addMeal.cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveMeal()
                    } label: {
                        Text(editingMeal == nil ? "nutrition.addMeal.save" : "nutrition.editMeal.save", bundle: .module)
                    }
                    // UI-seitige Zusatz-Absicherung — die eigentlichen
                    // Garantien (Doppeltap-Schutz, leere-Items-Guard) sitzen
                    // in MealDraft.save() selbst.
                    // NUT-01: `hasPendingCleanup` laesst den Tap offen, damit
                    // ein gescheiterter Cleanup erneut versucht wird.
                    .disabled((draft.didSaveSuccessfully && !draft.hasPendingCleanup) || draft.items.isEmpty)
                }
            }
            .confirmationDialog(
                Text("nutrition.editMeal.deleteConfirm", bundle: .module),
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    deleteMeal()
                } label: {
                    Text("nutrition.editMeal.delete", bundle: .module)
                }
                Button(role: .cancel) {
                } label: {
                    Text("common.cancel", bundle: .module)
                }
            }
            .discardChangesConfirmation(isPresented: $showingDiscardConfirm) {
                dismiss()
            }
            // Task 8: interaktives Wegziehen des Sheets ist sonst ein
            // ungesicherter Verlassen-Weg am Discard-Dialog vorbei (gleiches
            // Prinzip wie ExerciseLibraryEditorSheet/NewCustomExerciseSheet).
            // Ohne Entwurfsdaten (`!isDirty`) bleibt es normal moeglich.
            .interactiveDismissDisabled(isDirty)
            // Task 4: preview/confirm for a tapped online-search result.
            // `OnlineFoodCandidate` is `Identifiable`, so `.sheet(item:)`
            // both presents it and clears `selectedCandidate` on swipe-to-
            // dismiss — same effect as `onlineSearch.dismissPreview()`.
            .sheet(item: $onlineSearch.selectedCandidate) { candidate in
                OnlineFoodCandidatePreviewSheet(
                    candidate: candidate,
                    onConfirm: { confirmOnlineImport($0) },
                    onCancel: { onlineSearch.dismissPreview() },
                    // OFF-01: manueller Weg aus der Vorschau heraus, wenn
                    // die Datenlage fuer einen Import nicht reicht.
                    onCreateManually: { prefill in
                        let origin = onlineSearchOrigin
                        onlineSearch.dismissPreview()
                        onlineSearch.reset()
                        onlineSearchOrigin = nil
                        if case .aiCandidate(let pending) = origin {
                            removeAICandidate(pending)
                        }
                        customFoodPrefillName = prefill.trimmingCharacters(in: .whitespacesAndNewlines)
                        showingCustomFoodEntry = true
                    }
                )
            }
            // Task 6: manuelles Anlegen — `CustomFoodEntrySheet` persistiert
            // den `FoodCatalogEntry(source: .userCreated)` bereits selbst
            // (siehe `CustomFoodDraft.save`); `onSave` routet ihn nur noch
            // durch denselben `selectEntry` -> `quantityBottomBar`-Pfad.
            .sheet(isPresented: $showingCustomFoodEntry) {
                CustomFoodEntrySheet(
                    prefillName: customFoodPrefillName,
                    onSave: { entry in
                        showingCustomFoodEntry = false
                        selectEntry(entry)
                    },
                    onCancel: {
                        showingCustomFoodEntry = false
                    }
                )
            }
        }
    }

    // MARK: Sections

    private var detailsSection: some View {
        Section {
            DatePicker(
                String(localized: "summary.date", bundle: .module),
                selection: $draft.date,
                displayedComponents: .date
            )
            .listRowBackground(Color.Deltiq.surface)

            DeltiqSegmentedPicker(
                options: MealType.allCases.map { DeltiqSegmentedOption($0, label: mealTypeLabel($0)) },
                selection: $draft.mealType
            )
            // I4 fix: Task B replaced the labelled Picker with this segmented
            // control, which has no visible label of its own — leaving
            // "nutrition.addMeal.mealTypeLabel" both orphaned (dead_catalog_v3
            // UNUSED) and, for VoiceOver users, this picker's purpose
            // unannounced. Reusing the key as the accessibility label fixes
            // both without changing the visual design Task B intended.
            .accessibilityLabel(String(localized: "nutrition.addMeal.mealTypeLabel", bundle: .module))
            .listRowBackground(Color.Deltiq.surface)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    private var searchSection: some View {
        Section {
            searchField
                .listRowBackground(Color.Deltiq.surface)

            // Task 6: jederzeit sichtbar — NICHT nur im 0-Treffer-Zweig
            // darunter (Brief-Vorgabe) — unabhaengig von Netz/KI, deshalb
            // ausserhalb des `onlineFoodLookupEnabled`-Gates.
            customFoodButton
                .listRowBackground(Color.Deltiq.surface)

            if filteredEntries.isEmpty {
                Text("nutrition.addMeal.noResults", bundle: .module)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .listRowBackground(Color.Deltiq.surface)

                // Task 4: opt-in-only (Settings > Daten & Verbindungen),
                // default off — with the toggle off this whole branch is
                // gone, today's behavior unchanged. Deliberately its OWN
                // Section row (not nested inside the Text above's row) so
                // `OnlineFoodResultsList` below gets one real Form row per
                // candidate instead of sharing this row's tap target.
                if onlineFoodLookupEnabled {
                    onlineSearchButton
                        .listRowBackground(Color.Deltiq.surface)

                    // I1 fix: only render this search's own results/error
                    // here when THIS (manual) entry point actually started
                    // it — otherwise an AI candidate's active search would
                    // also show up here.
                    if onlineSearchOrigin == .manual {
                        if let message = onlineSearch.errorMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(Color.Deltiq.textSecondary)
                                .listRowBackground(Color.Deltiq.surface)
                        }

                        OnlineFoodResultsList(candidates: onlineSearch.candidates, onSelect: onlineSearch.select)
                    }
                }
            } else {
                // DEL-Picker-Muster (siehe ExerciseLibraryView.filtered):
                // Live-Filter ueber die aufgeloeste Katalog-Bezeichnung.
                ForEach(filteredEntries) { entry in
                    Button {
                        selectEntry(entry)
                    } label: {
                        HStack {
                            Text(resolvedName(for: entry))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if selectedEntry?.catalogID == entry.catalogID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.deltiqOrange)
                            }
                        }
                    }
                    .listRowBackground(Color.Deltiq.surface)
                }
            }
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    /// Task 3 (docs/superpowers/sdd/2026-10-22-ui-consistency): same
    /// icon+clear-button+`Color.Deltiq.fill` chrome as
    /// `ExerciseLibraryView.searchField` — duplicated rather than extracted
    /// into a shared component, since that view renders its search field
    /// standalone (outside any List/Form row), while this one lives inside
    /// a `Form` `Section` row; a shared component would need to paper over
    /// that difference for one call site each, more risk than value given
    /// how many other interdependent UI states this file already has.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Deltiq.textSecondary)
            TextField(
                String(localized: "nutrition.addMeal.searchPlaceholder", bundle: .module),
                text: $searchText
            )
            .font(.system(size: 15))
            .foregroundStyle(Color.primary)
            .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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

    /// Task 4: "Online suchen" in the manual-search 0-Treffer state —
    /// sichtbarer Text-Label (nicht icon-only, Brief-Vorgabe), deaktiviert
    /// waehrend eine Anfrage laeuft (gleicher Doppeltap-Schutz wie
    /// `aiSection`'s Extraktions-Button).
    private var onlineSearchButton: some View {
        Button {
            runOnlineSearch(origin: .manual)
        } label: {
            HStack {
                if onlineSearch.isSearching && onlineSearchOrigin == .manual {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("nutrition.addMeal.onlineSearch.action", bundle: .module)
            }
        }
        .disabled(onlineSearch.isSearching)
    }

    /// Task 6: oeffnet `CustomFoodEntrySheet`, vorausgefuellt mit dem
    /// aktuellen Suchtext (leer, falls noch nichts getippt wurde) — kein
    /// Netz, keine KI, kein Opt-in noetig (anders als `onlineSearchButton`
    /// oben, daher auch ausserhalb von dessen `onlineFoodLookupEnabled`-Gate).
    private var customFoodButton: some View {
        Button {
            customFoodPrefillName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            showingCustomFoodEntry = true
        } label: {
            Text("nutrition.addMeal.customFood.action", bundle: .module)
        }
    }

    /// Task E: lokale KI-gestuetzte Freitext-Erfassung. Bei `.unavailable`
    /// (jede Auspraegung) zeigt die Section NUR einen lokalisierten
    /// Hinweistext mit Verweis auf die Suche darunter — kein Ausblenden,
    /// kein leerer Zustand (Brief-Vorgabe). Die eigentliche Extraktion
    /// liefert NIE einen Naehrwert selbst: jeder Kandidat laeuft ueber
    /// `applyAICandidate` in genau denselben `quantityBottomBar`/`addSelectedEntry`-
    /// Pfad wie eine manuelle Suchauswahl.
    @ViewBuilder
    private var aiSection: some View {
        switch mealTextExtractor.availability() {
        case .available:
            Section {
                ForEach(Array(aiCandidates.enumerated()), id: \.offset) { _, candidate in
                    aiCandidateRow(candidate)
                }

                TextField(
                    String(localized: "nutrition.addMeal.aiDraft.placeholder", bundle: .module),
                    text: $aiInputText,
                    axis: .vertical
                )
                .lineLimit(1...3)
                .listRowBackground(Color.Deltiq.surface)

                Button {
                    runAIExtraction()
                } label: {
                    HStack {
                        if isExtracting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("nutrition.addMeal.aiDraft.action", bundle: .module)
                    }
                }
                // Mandatory addition from task-D-review.md (#6): no concurrent
                // requests from a double tap while one is already in flight.
                .disabled(isExtracting || aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .listRowBackground(Color.Deltiq.surface)

                if let aiErrorMessage {
                    Text(aiErrorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .listRowBackground(Color.Deltiq.surface)
                }
            } header: {
                Text("nutrition.addMeal.aiDraft.header", bundle: .module)
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        default:
            Section {
                Text("nutrition.addMeal.aiDraft.unavailable", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .listRowBackground(Color.Deltiq.surface)
            }
            .listRowSeparatorTint(Color.Deltiq.divider)
        }
    }

    /// Eine extrahierte Position: eindeutiger Treffer -> ein Button, der sie
    /// wie eine manuelle Suchauswahl in den `quantityBottomBar` uebernimmt;
    /// mehrdeutiger Treffer -> Auswahl-Buttons pro Katalogtreffer (NIE
    /// automatisch der erste); kein Treffer -> Hinweistext + Uebernahme des
    /// Suchtexts in die normale Suche darunter.
    @ViewBuilder
    private func aiCandidateRow(_ candidate: MealDraftCandidate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(candidate.foodText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)

            if candidate.needsQuantity {
                Text("nutrition.addMeal.aiDraft.needsQuantity", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }

            if candidate.hasNoCatalogMatch {
                Text("nutrition.addMeal.aiDraft.noMatch", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                Button {
                    searchText = candidate.foodText
                    removeAICandidate(candidate)
                } label: {
                    Text("nutrition.addMeal.aiDraft.searchManually", bundle: .module)
                }
                // C1 fix (see the `isAmbiguous` branch below for the full
                // explanation): this button now shares `aiCandidateRow`'s one
                // VStack/Form-row with the Task 5 "Online suchen" button
                // added right below, so each needs its own borderless button
                // style as an independently tappable hit target.
                .buttonStyle(.borderless)

                // Task 5 (docs/superpowers/sdd/2026-10-22-online-food-lookup):
                // second entry point for Task 4's online lookup — same
                // `onlineFoodLookupEnabled` gate, same shared `onlineSearch`
                // controller/components, prefilled with this candidate's
                // `foodText` instead of the manual search field.
                if onlineFoodLookupEnabled {
                    Button {
                        runOnlineSearch(origin: .aiCandidate(candidate), query: candidate.foodText)
                    } label: {
                        HStack {
                            if onlineSearch.isSearching && onlineSearchOrigin == .aiCandidate(candidate) {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("nutrition.addMeal.onlineSearch.action", bundle: .module)
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(onlineSearch.isSearching)

                    // I1 fix: with several unmatched candidates sharing this
                    // one controller, only render THIS candidate's results/
                    // error under THIS row — never under every unmatched
                    // candidate, and never here while the manual search
                    // entry point is the one active.
                    if onlineSearchOrigin == .aiCandidate(candidate) {
                        if let message = onlineSearch.errorMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }

                        OnlineFoodResultsList(candidates: onlineSearch.candidates, onSelect: onlineSearch.select)
                    }
                }

                // Task 6: dritter, von Netz/KI unabhaengiger Einstiegspunkt
                // fuer EXAKT diesen Kandidaten — vorausgefuellt mit
                // `candidate.foodText`, gleiches `.borderless`-Muster wie die
                // beiden Buttons darueber in diesem gemeinsamen Form-Row-VStack.
                Button {
                    customFoodPrefillName = candidate.foodText
                    showingCustomFoodEntry = true
                    removeAICandidate(candidate)
                } label: {
                    Text("nutrition.addMeal.customFood.action", bundle: .module)
                }
                .buttonStyle(.borderless)
            } else if candidate.isAmbiguous {
                Text("nutrition.addMeal.aiDraft.ambiguous", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                ForEach(candidate.matches, id: \.catalogID) { match in
                    if let entry = catalogEntries.first(where: { $0.catalogID == match.catalogID }) {
                        Button {
                            applyAICandidate(candidate, entry: entry)
                        } label: {
                            Text(resolvedName(for: entry))
                        }
                        // C1 fix: several default-style Buttons sharing one
                        // VStack inside a single Form row become ONE tap
                        // target in SwiftUI — tapping anywhere in the row runs
                        // every button's action, so only the LAST one's action
                        // actually won regardless of which label was tapped.
                        // `.borderless` (same reasoning as DeltiqSegmentedPicker's
                        // `.plain` in Theme.swift) gives each button its own
                        // real, independently tappable hit target instead of
                        // merging them into the row's single default tap area.
                        .buttonStyle(.borderless)
                    }
                }
            } else if let match = candidate.matches.first,
                      let entry = catalogEntries.first(where: { $0.catalogID == match.catalogID }) {
                Button {
                    applyAICandidate(candidate, entry: entry)
                } label: {
                    Text(String(format: String(localized: "nutrition.addMeal.aiDraft.useSuggestion", bundle: .module), resolvedName(for: entry)))
                }
            }
        }
        .listRowBackground(Color.Deltiq.surface)
    }

    /// Task A: Ersatz fuer das vormalige `quantitySection(for:)` — lebt jetzt
    /// ausserhalb des `Form`-Flows (siehe `.safeAreaInset` in `body`), daher
    /// kein `Section`/`listRowBackground` mehr, sondern eine eigenstaendige,
    /// ueber `.deltiqCardStyle()` vom Hintergrund abgesetzte Karte.
    @ViewBuilder
    private func quantityBottomBar(for entry: FoodCatalogEntry) -> some View {
        // Nur die laut FoodCatalogItem.supports(_:) zulaessigen Einheiten
        // (Spec 4.2) — niemals Stueck/Milliliter pauschal anbieten.
        let allowedUnits = FoodUnit.allCases.filter { entry.asCatalogItem.supports($0) }
        VStack(alignment: .leading, spacing: 12) {
            // Name des gewaehlten Lebensmittels zur Orientierung — ohne die
            // Trefferliste zu scrollen, sieht man sonst nicht mehr, wofuer
            // man gerade die Menge eintraegt.
            Text(resolvedName(for: entry))
                .font(.headline)
                .foregroundStyle(Color.primary)
                .lineLimit(1)

            HStack {
                Text("nutrition.addMeal.quantityLabel", bundle: .module)
                Spacer()
                TextField("", value: $quantity, format: .number)
                    .decimalKeyboard()
                    .multilineTextAlignment(.trailing)
                    .fitnessNumberStyle()
                    .frame(maxWidth: 100)
            }

            DeltiqSegmentedPicker(
                options: allowedUnits.map { DeltiqSegmentedOption($0, label: unitLabel($0)) },
                selection: $selectedUnit
            )

            Button {
                addSelectedEntry()
            } label: {
                HStack {
                    Spacer()
                    Text("common.add", bundle: .module)
                    Spacer()
                }
                // Audit-Fund (siehe NutritionDayView.mealEntryRow /
                // DashboardView-Nutrition-Tile): ein Spacer()-aufgespanntes
                // HStack ist ausserhalb eines Form/List nicht automatisch
                // hit-testable — ohne explizites .contentShape(Rectangle())
                // reagiert nur die Text-Glyphe selbst auf Taps, nicht die
                // ganze Button-Breite.
                .contentShape(Rectangle())
            }
            // Task B (Deltiq-Designsystem): bewusst BEI .buttonStyle(.borderedProminent)
            // geblieben statt auf .deltiqButtonStyle() zu wechseln. Zwei Anläufe im
            // Geraetetest (TestingBot, iPhone 15/iOS 18) zeigten, dass
            // .buttonStyle(.plain) + .deltiqButtonStyle() die Zeile nur VISUELL
            // vollbreit macht: weder ein nachtraeglich angehaengtes
            // .contentShape(Rectangle()) noch ein frame(maxWidth: .infinity) direkt
            // im Label stellten einen wirklich kantenbeidseitig tappbaren Bereich
            // her — raw-coordinate-Taps links/rechts neben "Add" blieben wirkungslos,
            // nur die Mitte (Text-Glyphe) reagierte. Die hier bereits vorhandene
            // Spacer()+.contentShape(Rectangle())-Loesung ist nachweislich
            // vollbreit tappbar (siehe vorheriger Commit a90939c) — kein Fine-Tuning
            // um des Fine-Tunings willen.
            .buttonStyle(.borderedProminent)
            .disabled((quantity ?? 0) <= 0)
        }
        .deltiqCardStyle()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color.Deltiq.background)
    }

    private var itemsSection: some View {
        Section {
            // NUT-01: Ist der Edit committet, aber der Cleanup offen, zeigt
            // die Positionen-Liste den GESPEICHERTEN Stand (alte + neue) —
            // nicht den Entwurf, der nach einem Retry schon anders aussieht.
            if let stored = showsStoredStateInsteadOfDraft ? storedMealItems : nil {
                ForEach(stored) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.nameSnapshot)
                                .foregroundStyle(Color.primary)
                            Text("\(item.quantity.truncated(to: 2).formattedTwoDecimals) \(unitLabel(item.unit))")
                                .font(.caption)
                                .foregroundStyle(Color.Deltiq.textSecondary)
                        }
                        Spacer()
                        Text(NutritionDisplay.text(item.nutrientsSnapshot.kcal, unit: "kcal", decimals: 0))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .fitnessNumberStyle()
                    }
                    .listRowBackground(Color.Deltiq.surface)
                }
                Text("nutrition.addMeal.saveFailed.cleanupMessage", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .listRowBackground(Color.Deltiq.surface)
            } else {
            ForEach(draft.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.nameSnapshot)
                            .foregroundStyle(Color.primary)
                        Text("\(item.quantity.truncated(to: 2).formattedTwoDecimals) \(unitLabel(item.unit))")
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                    Spacer()
                    // OFF-01: ein unbekannter Naehrwert darf nicht als 0 in
                    // der Positionszeile erscheinen.
                    Text(NutritionDisplay.text(item.nutrients.kcal, unit: "kcal", decimals: 0))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .fitnessNumberStyle()
                }
                .listRowBackground(Color.Deltiq.surface)
            }
            // Final-review fix (important): bisher gab es keinen Weg, eine
            // einzelne Position wieder zu entfernen, weder im Neuanlage-
            // noch im Edit-Flow.
            .onDelete { offsets in
                for index in offsets {
                    draft.removeItem(id: draft.items[index].id)
                }
            }
            }
        } header: {
            Text("nutrition.addMeal.positionsSection", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    private var previewSection: some View {
        // Rein lesend ueber draft.totalPreview — siehe MealDraft-Doku: es
        // gibt keinen Code-Pfad von hier zu SwiftData.
        let total = draft.totalPreview
        return Section {
            previewRow(String(localized: "nutrition.goals.calorie.label", bundle: .module), value: total.kcal)
            previewRow(String(localized: "nutrition.goals.protein.label", bundle: .module), value: total.proteinG)
            previewRow(String(localized: "nutrition.goals.carbs.label", bundle: .module), value: total.carbsG)
            previewRow(String(localized: "nutrition.goals.fat.label", bundle: .module), value: total.fatG)
            // OFF-01: sagt an der Vorschau, dass mindestens eine Position
            // einen unbekannten Wert enthaelt (die Summe ist dann „-").
            if total.partiallyKnown {
                Text("nutrition.day.total.incomplete", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .listRowBackground(Color.Deltiq.surface)
            }
        } header: {
            Text("nutrition.addMeal.previewSection", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    private func previewRow(_ label: String, value: KnownValue) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.primary)
            Spacer()
            Text(NutritionDisplay.text(value))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fitnessNumberStyle()
        }
        .listRowBackground(Color.Deltiq.surface)
    }

    /// Audit-Fund (Geraetetest): als Toolbar-Icon+Text-`Label` kollabierte
    /// dieser Button auf echten Geraeten still auf reines Icon (iOS
    /// komprimiert ein `.destructiveAction`-Toolbar-Item neben
    /// `.confirmationAction`, wenn der Platz knapp wird) — die Global-
    /// Constraint-Vorgabe "sichtbar textbeschriftete Controls" war dadurch
    /// faktisch nicht erfuellt. Als eigene Formular-Zeile (gleiches Muster
    /// wie `SettingsView.dangerZoneSection`) kann iOS den Text nicht mehr
    /// wegkuerzen.
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Label {
                        Text("nutrition.editMeal.delete", bundle: .module)
                    } icon: {
                        Image(systemName: "trash")
                    }
                    Spacer()
                }
            }
            .listRowBackground(Color.Deltiq.surface)
        }
    }

    // MARK: Derived

    /// Task 8 (docs/superpowers/sdd/2026-10-22-ui-consistency): muss ALLE
    /// Entwurfs-Quellen erfassen, nicht nur eine -- geprueft gegen den
    /// aktuellen Stand der Datei (Task 6/7/Online-Food-Lookup haben seitdem
    /// mehrere unabhaengige Entwurfs-Pfade hinzugefuegt):
    ///   * `draft.items` -- bereits per "Add" uebernommene Positionen,
    ///     verglichen gegen `itemsAtOpen` (Edit-Mode startet vorbefuellt).
    ///   * `selectedEntry`/`quantity` -- ein in der `quantityBottomBar`
    ///     angewaehlter Katalog-Eintrag mit (optional) eingetippter Menge,
    ///     der noch NICHT per "Add" in `draft.items` uebernommen wurde. Jeder
    ///     Eintrittspunkt (manuelle Suche, KI-Kandidat, Online-Import) landet
    ///     ueber `selectEntry`/`applyAICandidate` hier, ein einziger Check
    ///     deckt also alle drei ab.
    ///   * `aiInputText` -- getippter, noch nicht extrahierter KI-Freitext.
    ///   * `aiCandidates` -- bereits extrahierte, aber noch nicht uebernommene
    ///     KI-Kandidaten (Mehrdeutigkeits-Auswahl/Mengen-Rueckfrage offen).
    ///   * `draft.date`/`draft.mealType` -- Fix-Runde 1 (Befund 2): beide
    ///     werden von `MealDraft.save()` im Edit-Mode tatsaechlich
    ///     mitpersistiert (siehe dortige Doku), fehlten hier aber bisher --
    ///     ein Verschieben auf einen anderen Tag/Mahlzeittyp zaehlte dadurch
    ///     nicht als Aenderung und ging beim Abbrechen kommentarlos verloren.
    /// `searchText` (reiner Filter, kein Eingabe-Risiko), die aktiven
    /// Online-Suchergebnisse selbst sowie `showingCustomFoodEntry`/
    /// `onlineSearch.selectedCandidate` zaehlen bewusst NICHT: Letztere sind
    /// je ihr eigenes modales Sheet mit eigenem Save/Cancel -- waehrend eines
    /// davon offen ist, ist dieser Screen's eigener Cancel-Button ohnehin
    /// nicht erreichbar, und ein erfolgreicher Import/Uebernahme landet
    /// bereits ueber `selectEntry`/`applyAICandidate` in `selectedEntry`.
    private var isDirty: Bool {
        MealDraftItemFieldsSnapshot.capture(from: draft.items) != itemsAtOpen
            || selectedEntry != nil
            || quantity != nil
            || !aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !aiCandidates.isEmpty
            || draft.date != dateAtOpen
            || draft.mealType != mealTypeAtOpen
    }

    /// NUT-01: Die Positionen, die der Store tatsaechlich enthaelt, fuer eine
    /// Mahlzeit im Edit-Modus. Vor dem ersten Speichern (`itemsVersion == 0`)
    /// ist der Entwurf die einzige Quelle; danach (Cleanup-Fehler, Retry)
    /// zeigt die Ansicht den gespeicherten Stand.
    private var storedMealItems: [MealItem]? {
        guard let editingMeal, draft.itemsVersion > 0 else { return nil }
        return MealDraft.storedItems(forMealID: editingMeal.persistentModelID, in: modelContext)
    }

    /// NUT-01: `true`, solange der Edit committet ist, aber die alten
    /// Positionen noch im Store stehen — die Ansicht zeigt den gespeicherten
    /// Stand (alte + neue) und erklaert das.
    private var showsStoredStateInsteadOfDraft: Bool {
        editingMeal != nil && draft.hasPendingCleanup && storedMealItems != nil
    }

    private var filteredEntries: [FoodCatalogEntry] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return catalogEntries }
        return catalogEntries.filter { resolvedName(for: $0).localizedCaseInsensitiveContains(trimmed) }
    }

    /// Task E (M2 in task-D-review.md): explicit `locale` instead of
    /// `NutritionAIService`'s `.current` default.
    private var mealTextExtractor: MealTextExtractor {
        MealTextExtractor(service: NutritionAIService(locale: locale))
    }

    // MARK: Actions

    private func selectEntry(_ entry: FoodCatalogEntry) {
        selectedEntry = entry
        quantity = nil
        // Gramm ist laut FoodCatalogItem.supports(_:) IMMER erlaubt — ein
        // sicherer Default, egal welche Einheiten das Item sonst unterstuetzt.
        selectedUnit = .gram
    }

    private func addSelectedEntry() {
        guard let entry = selectedEntry,
              let quantity, quantity > 0,
              let nutrients = NutritionCalculations.nutrients(for: entry.asCatalogItem, quantity: quantity, unit: selectedUnit)
        else { return }

        // Resolution lebt bewusst HIER in der UI: nur FitnessAppUI hat
        // Zugriff auf Bundle.module/die xcstrings (siehe Task-6-Brief) — der
        // aufgeloeste String wird als Snapshot eingefroren, nicht der Key.
        let name = resolvedName(for: entry)
        draft.addItem(catalogID: entry.catalogID, nameSnapshot: name, quantity: quantity, unit: selectedUnit, nutrients: nutrients)

        selectedEntry = nil
        self.quantity = nil
        selectedUnit = .gram
        searchText = ""
    }

    /// Startet die Freitext-Extraktion. Die KI erzeugt NIE einen Naehrwert
    /// selbst und schreibt NIE direkt in `draft` — das Ergebnis landet nur in
    /// `aiCandidates`, von dort ausschliesslich ueber `applyAICandidate` (also
    /// denselben `quantityBottomBar`/`addSelectedEntry`-Pfad wie eine manuelle
    /// Auswahl) in den Entwurf.
    private func runAIExtraction() {
        // Mandatory addition from task-D-review.md (#6): no concurrent
        // requests — a second tap while one is in flight is a no-op.
        guard !isExtracting else { return }
        let text = aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isExtracting = true
        aiErrorMessage = nil
        let extractor = mealTextExtractor
        let catalog = catalogEntries.map { MealTextCatalogEntry(catalogID: $0.catalogID, name: resolvedName(for: $0)) }

        Task { @MainActor in
            defer { isExtracting = false }
            do {
                aiCandidates = try await extractor.extractCandidates(from: text, catalog: catalog)
                aiInputText = ""
            } catch {
                // Privacy: never log `text`/the model response anywhere here.
                aiErrorMessage = String(localized: "nutrition.addMeal.aiDraft.error", bundle: .module)
            }
        }
    }

    /// Uebernimmt einen KI-Kandidaten in exakt denselben Zustand, den eine
    /// manuelle Suchauswahl (`selectEntry`) erzeugt — der Nutzer sieht/bestaetigt
    /// Menge und Einheit im bestehenden `quantityBottomBar`, bevor "Add"
    /// tatsaechlich in `draft` schreibt. Fehlt die Menge, bleibt `quantity`
    /// bewusst `nil` (Rueckfrage via `quantityBottomBar`s leeres Feld +
    /// deaktiviertem Add-Button), statt still einen Default zu setzen.
    private func applyAICandidate(_ candidate: MealDraftCandidate, entry: FoodCatalogEntry) {
        selectedEntry = entry
        let allowedUnits = FoodUnit.allCases.filter { entry.asCatalogItem.supports($0) }
        let mappedUnit = candidate.unit.flatMap { FoodUnit(rawValue: $0.rawValue) }
        let validUnit = mappedUnit.flatMap { allowedUnits.contains($0) ? $0 : nil }
        selectedUnit = validUnit ?? .gram
        // I3 fix: an unknown/invalid unit means the extracted quantity can't be
        // trusted for THIS food (e.g. "2 Eier" with unit "piece" invalid for a
        // gram-only entry would otherwise silently become "2 g"). Drop the
        // quantity too so the existing "needs quantity" follow-up (empty field,
        // disabled Add button) kicks in instead of a silently wrong number.
        quantity = validUnit != nil ? candidate.quantity : nil
        removeAICandidate(candidate)
    }

    private func removeAICandidate(_ candidate: MealDraftCandidate) {
        guard let index = aiCandidates.firstIndex(of: candidate) else { return }
        aiCandidates.remove(at: index)
    }

    /// Task 4/5: searches Open Food Facts for `rawQuery`, or (Task 4's
    /// original call site, `onlineSearchButton`) the CURRENT manual search
    /// text when `rawQuery` is omitted. Task 5's AI-candidate entry point
    /// passes the candidate's `foodText` instead — same function, no
    /// duplicated flow logic. `OnlineFoodSearchController.search` already
    /// no-ops on a double tap while one request is in flight, and clears its
    /// own `candidates`/`errorMessage` at the start of every call, so a new
    /// search from either entry point can never show the OTHER entry
    /// point's stale results.
    ///
    /// Final-review fix (important): `origin` records WHICH row started this
    /// search, so the shared `onlineSearch` state only ever renders under
    /// that one row (see `searchSection`/`aiCandidateRow`).
    private func runOnlineSearch(origin: OnlineSearchOrigin, query rawQuery: String? = nil) {
        let query = (rawQuery ?? searchText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        onlineSearchOrigin = origin
        Task { @MainActor in
            await onlineSearch.search(query: query, locale: locale, errorText: onlineSearchErrorText)
        }
    }

    private func onlineSearchErrorText(_ error: OnlineFoodSearchError) -> String {
        switch error {
        case .noNetwork:
            return String(localized: "nutrition.addMeal.onlineSearch.noNetwork", bundle: .module)
        case .noResults:
            return String(localized: "nutrition.addMeal.onlineSearch.noResults", bundle: .module)
        case .rateLimited, .invalidResponse:
            return String(localized: "nutrition.addMeal.onlineSearch.error", bundle: .module)
        }
    }

    /// Confirm in `OnlineFoodCandidatePreviewSheet`: creates exactly ONE
    /// `FoodCatalogEntry` (`source == .onlineImported`) and routes it into
    /// the SAME `selectEntry`/`applyAICandidate` -> `quantityBottomBar` ->
    /// `addSelectedEntry` -> `draft.addItem` path a manual/AI catalog pick
    /// already uses — no new persistence logic.
    ///
    /// Final-review fix (important): when this import originated from an
    /// unmatched AI candidate (`onlineSearchOrigin == .aiCandidate`), it must
    /// be removed from `aiCandidates` on success — same as its sibling
    /// "manuell suchen"/"eigenes Lebensmittel anlegen" buttons already do —
    /// and its extracted quantity/unit must carry over instead of being
    /// dropped to `nil`, exactly like `applyAICandidate` already does for a
    /// normal catalog match. Reusing `applyAICandidate` itself (instead of
    /// duplicating that carry-over logic here) guarantees both.
    /// OFF-01: Fehlende Naehrwerte werden als `nil` (unbekannt) gespeichert —
    /// `FoodCatalogEntry`/`MealItem` unterscheiden das ueber eine additive
    /// Bitzmaske. Es gibt hier bewusst KEIN `?? 0`.
    private func confirmOnlineImport(_ values: OnlineFoodImportValues) {
        let entry = FoodCatalogEntry(
            displayName: values.name,
            source: .onlineImported,
            category: .other,
            kcalPer100g: values.kcalPer100g,
            proteinPer100g: values.proteinPer100g,
            carbsPer100g: values.carbsPer100g,
            fatPer100g: values.fatPer100g
        )
        modelContext.insert(entry)
        let origin = onlineSearchOrigin
        onlineSearch.dismissPreview()
        onlineSearch.reset()
        onlineSearchOrigin = nil

        if case .aiCandidate(let candidate) = origin {
            applyAICandidate(candidate, entry: entry)
        } else {
            selectEntry(entry)
        }
    }

    private func saveMeal() {
        let result = draft.save(into: modelContext)
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            // NUT-01: Der Edit selbst (Datum/Typ + Positionen) IST gespeichert,
            // nur das Entfernen der alten Positionen ist gescheitert — dann
            // nicht „nichts geändert" behaupten, sondern den gespeicherten
            // Stand benennen (eigener Hinweis-Key). Das Sheet bleibt offen,
            // weil `draft.save()` beim nächsten Tap erneut aufräumt
            // (`finishPendingCleanup`), statt Positionen zu duplizieren.
            saveErrorMessage = error is MealDraftItemCleanupError
                ? String(localized: "nutrition.addMeal.saveFailed.cleanupMessage", bundle: .module)
                : String(localized: "nutrition.addMeal.saveFailed.message", bundle: .module)
            // Ein erneuter Tap ist nach dem Fehler wieder möglich: der Button
            // war per `didSaveSuccessfully` deaktiviert, das ist für den
            // Cleanup-Retry nicht sinnvoll.
            draft.enableRetryAfterFailedCleanup()
        }
    }

    /// Loescht die GESAMTE Mahlzeit (Task 7) — bewusst NICHT ueber
    /// `MealDraft`, das kennt nur den Positions-Entwurf. `MealEntry.items`
    /// hat die Cascade-Delete-Rule (siehe dortige Doku), `context.delete`
    /// reisst alle `MealItem`s also automatisch mit.
    private func deleteMeal() {
        guard let editingMeal else { return }
        modelContext.delete(editingMeal)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = String(localized: "nutrition.addMeal.saveFailed.message", bundle: .module)
        }
    }

    // MARK: Localization helpers

    private func resolvedName(for entry: FoodCatalogEntry) -> String {
        // Online-importierte/manuell angelegte Eintraege haben einen
        // Klartext-Namen statt eines xcstrings-Keys (kein Lokalisierungs-
        // Key fuer vom Nutzer/einer Online-Quelle stammenden Text) — der hat
        // Vorrang vor `nameKey`.
        entry.displayName ?? String(localized: String.LocalizationValue(entry.nameKey), bundle: .module)
    }

    private func mealTypeLabel(_ type: MealType) -> String {
        String(localized: String.LocalizationValue(type.localizationKey), bundle: .module)
    }

    private func unitLocalizationKey(_ unit: FoodUnit) -> String {
        switch unit {
        case .gram: return "nutrition.unit.gram.label"
        case .piece: return "nutrition.unit.piece.label"
        case .milliliter: return "nutrition.unit.milliliter.label"
        }
    }

    private func unitLabel(_ unit: FoodUnit) -> String {
        String(localized: String.LocalizationValue(unitLocalizationKey(unit)), bundle: .module)
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    let container = try! ModelContainer(
        for: Schema(AppSchema.types),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    FoodCatalogSeeder.seedIfNeeded(in: container.mainContext)
    return AddMealView()
        .modelContainer(container)
}
#endif
#endif
