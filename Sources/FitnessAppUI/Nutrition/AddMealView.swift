#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

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
                searchSection
                if let selectedEntry {
                    quantitySection(for: selectedEntry)
                }
                if !draft.items.isEmpty {
                    itemsSection
                    previewSection
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
                if editingMeal != nil {
                    // Loeschen der GESAMTEN Mahlzeit ist eine separate, simplere
                    // Operation als das Editieren ihrer Positionen — laeuft
                    // deshalb bewusst nicht ueber MealDraft, siehe deleteMeal().
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(Text("nutrition.editMeal.delete", bundle: .module))
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

            Picker(selection: $draft.mealType) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(mealTypeLabel(type)).tag(type)
                }
            } label: {
                Text("nutrition.addMeal.mealTypeLabel", bundle: .module)
            }
            .pickerStyle(.segmented)
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

    @ViewBuilder
    private func quantitySection(for entry: FoodCatalogEntry) -> some View {
        // Nur die laut FoodCatalogItem.supports(_:) zulaessigen Einheiten
        // (Spec 4.2) — niemals Stueck/Milliliter pauschal anbieten.
        let allowedUnits = FoodUnit.allCases.filter { entry.asCatalogItem.supports($0) }
        Section {
            HStack {
                Text("nutrition.addMeal.quantityLabel", bundle: .module)
                Spacer()
                TextField("", value: $quantity, format: .number)
                    .decimalKeyboard()
                    .multilineTextAlignment(.trailing)
                    .fitnessNumberStyle()
                    .frame(maxWidth: 100)
            }
            .listRowBackground(Color.Deltiq.surface)

            Picker(selection: $selectedUnit) {
                ForEach(allowedUnits, id: \.self) { unit in
                    Text(unitLabel(unit)).tag(unit)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.Deltiq.surface)

            Button {
                addSelectedEntry()
            } label: {
                HStack {
                    Spacer()
                    Text("common.add", bundle: .module)
                    Spacer()
                }
            }
            .disabled((quantity ?? 0) <= 0)
            .listRowBackground(Color.Deltiq.surface)
        }
        .listRowSeparatorTint(Color.Deltiq.divider)
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

    // MARK: Derived

    private var filteredEntries: [FoodCatalogEntry] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return catalogEntries }
        return catalogEntries.filter { resolvedName(for: $0).localizedCaseInsensitiveContains(trimmed) }
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
        String(localized: String.LocalizationValue(entry.nameKey), bundle: .module)
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
