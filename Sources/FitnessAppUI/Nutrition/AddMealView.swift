#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData
import FitnessAppAI

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
    @State private var showingSaveError: Bool = false
    @State private var showingDeleteConfirm: Bool = false

    // Task E: local AI-assisted free-text meal draft parsing.
    @State private var aiInputText: String = ""
    @State private var isExtracting: Bool = false
    @State private var aiCandidates: [MealDraftCandidate] = []
    @State private var aiErrorMessage: String?

    public init(date: Date = Date(), mealType: MealType = .snack) {
        _draft = StateObject(wrappedValue: MealDraft(date: date, mealType: mealType))
        self.editingMeal = nil
    }

    public init(editing meal: MealEntry) {
        _draft = StateObject(wrappedValue: MealDraft(editing: meal))
        self.editingMeal = meal
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
                    // Verwirft den MealDraft kommentarlos — bewusst KEIN
                    // save()-Aufruf hier, also keine Spur im ModelContext.
                    Button {
                        dismiss()
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
                    .disabled(draft.didSaveSuccessfully || draft.items.isEmpty)
                }
            }
            .alert(
                Text("nutrition.addMeal.saveFailed.title", bundle: .module),
                isPresented: $showingSaveError
            ) {
                Button {
                } label: {
                    Text("common.close", bundle: .module)
                }
            } message: {
                Text("nutrition.addMeal.saveFailed.message", bundle: .module)
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
            TextField(
                String(localized: "nutrition.addMeal.searchPlaceholder", bundle: .module),
                text: $searchText
            )
            .autocorrectionDisabled()
            .listRowBackground(Color.Deltiq.surface)

            if filteredEntries.isEmpty {
                Text("nutrition.addMeal.noResults", bundle: .module)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .listRowBackground(Color.Deltiq.surface)
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
                    Text("\(item.nutrients.kcal.truncated(to: 0).formattedTwoDecimals) kcal")
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
        } header: {
            Text("nutrition.addMeal.previewSection", bundle: .module)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
    }

    private func previewRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.primary)
            Spacer()
            Text(value.truncated(to: 2).formattedTwoDecimals)
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

    private func saveMeal() {
        let result = draft.save(into: modelContext)
        switch result {
        case .success:
            dismiss()
        case .failure:
            showingSaveError = true
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
            showingSaveError = true
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
