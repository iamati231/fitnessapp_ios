#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Fehler, die `CustomFoodDraft.save` zurueckgeben kann.
public enum CustomFoodDraftError: Error, Equatable {
    /// `isValid` war `false` (Name leer oder ein Pflicht-Makro fehlt/negativ)
    /// — Save-Button-seitig durch `.disabled(!draft.isValid)` abgefangen,
    /// dieser Fall ist nur die Code-seitige Absicherung desselben Gates.
    case invalidInput
}

/// Task 6 (docs/superpowers/sdd/2026-10-22-online-food-lookup): manuelles
/// Anlegen eines eigenen Lebensmittels, UNABHAENGIG von Netz/KI (keine
/// `OnlineFoodSearchController`-Abhaengigkeit). Gleiches Doppeltap-Schutz-
/// und Rueckbau-Muster wie `MealDraft.save()`: `didSaveSuccessfully` macht
/// jeden weiteren `save()`-Aufruf zu einem Context-freien No-Op (liefert den
/// bereits gespeicherten Eintrag erneut), ein fehlgeschlagener erster
/// Versuch raeumt den frisch eingefuegten, nie persistierten Eintrag wieder
/// auf und laesst Name/Makros fuer einen erneuten Versuch unveraendert
/// stehen (kein Datenverlust, kein falsches Erfolgs-Feedback).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public final class CustomFoodDraft: ObservableObject {
    @Published public var name: String
    @Published public var kcalPer100g: Double?
    @Published public var proteinPer100g: Double?
    @Published public var carbsPer100g: Double?
    @Published public var fatPer100g: Double?
    /// Optional — bleibt bei `nil` unangetastet. `FoodCatalogItem.supports(_:)`
    /// liest direkt `pieceWeightGrams != nil`/`densityGramsPerMl != nil`, der
    /// spaetere Mengen-Picker (`AddMealView.quantityBottomBar`) bietet ohne
    /// diese Werte also automatisch NUR Gramm an — keine eigene Logik hier
    /// noetig, siehe `NutritionCalculations.supports(_:)`.
    @Published public var pieceWeightGrams: Double?
    @Published public var densityGramsPerMl: Double?
    @Published public private(set) var didSaveSuccessfully: Bool = false
    private var savedEntry: FoodCatalogEntry?

    public init(name: String = "") {
        self.name = name
    }

    /// Alle 4 Pflicht-Makros muessen gesetzt UND `>= 0` sein (kein negativer
    /// Wert), der Name darf nicht leer/nur-Whitespace sein. Spiegelt sich
    /// 1:1 im Save-Button-`.disabled` von `CustomFoodEntrySheet`.
    public var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return [kcalPer100g, proteinPer100g, carbsPer100g, fatPer100g].allSatisfy { ($0 ?? -1) >= 0 }
    }

    @discardableResult
    public func save(
        into context: ModelContext,
        persist: (ModelContext) throws -> Void = { try $0.save() }
    ) -> Result<FoodCatalogEntry, Error> {
        if didSaveSuccessfully, let savedEntry {
            return .success(savedEntry)
        }
        guard isValid,
              let kcal = kcalPer100g, let protein = proteinPer100g,
              let carbs = carbsPer100g, let fat = fatPer100g
        else {
            return .failure(CustomFoodDraftError.invalidInput)
        }

        let entry = FoodCatalogEntry(
            displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            source: .userCreated,
            category: .other,
            kcalPer100g: kcal,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            pieceWeightGrams: pieceWeightGrams,
            densityGramsPerMl: densityGramsPerMl
        )
        context.insert(entry)
        do {
            try persist(context)
            didSaveSuccessfully = true
            savedEntry = entry
            return .success(entry)
        } catch {
            // Rueckbau: der frisch eingefuegte, nie persistierte Eintrag darf
            // nicht im Context haengen bleiben (gleiche Begruendung wie
            // MealDraft.save()'s Neuanlage-Fehlerpfad).
            context.delete(entry)
            return .failure(error)
        }
    }
}

/// Eigenstaendiges Sheet (gleiches Form+NavigationStack-Muster wie
/// `OnlineFoodCandidatePreviewSheet`), aber ohne jede Online-/KI-Abhaengigkeit
/// — reine manuelle Erfassung. `onSave` liefert den bereits in den
/// `ModelContext` eingefuegten und gespeicherten `FoodCatalogEntry`; der
/// Aufrufer (`AddMealView`) routet ihn durch denselben `selectEntry` ->
/// `quantityBottomBar` -> `addSelectedEntry`-Pfad wie jede andere Auswahl.
@available(iOS 17.0, macOS 14.0, *)
struct CustomFoodEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    let onSave: (FoodCatalogEntry) -> Void
    let onCancel: () -> Void

    @StateObject private var draft: CustomFoodDraft
    // Doppeltap-Schutz auf UI-Ebene (zusaetzlich zu `draft.didSaveSuccessfully`
    // selbst): deaktiviert den Save-Button SOFORT beim ersten Tap, noch bevor
    // `draft.save` ueberhaupt zurueckkehrt.
    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?

    init(prefillName: String, onSave: @escaping (FoodCatalogEntry) -> Void, onCancel: @escaping () -> Void) {
        _draft = StateObject(wrappedValue: CustomFoodDraft(name: prefillName))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "nutrition.customFood.nameLabel", bundle: .module), text: $draft.name)
                        .listRowBackground(Color.Deltiq.surface)
                }
                Section {
                    macroRow("nutrition.customFood.kcalLabel", value: $draft.kcalPer100g)
                    macroRow("nutrition.customFood.proteinLabel", value: $draft.proteinPer100g)
                    macroRow("nutrition.customFood.carbsLabel", value: $draft.carbsPer100g)
                    macroRow("nutrition.customFood.fatLabel", value: $draft.fatPer100g)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
                Section {
                    macroRow("nutrition.customFood.pieceWeightLabel", value: $draft.pieceWeightGrams)
                    macroRow("nutrition.customFood.densityLabel", value: $draft.densityGramsPerMl)
                } footer: {
                    Text("nutrition.customFood.optionalFooter", bundle: .module)
                }
                .listRowSeparatorTint(Color.Deltiq.divider)
                if let saveErrorMessage {
                    Section {
                        Text(saveErrorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .listRowBackground(Color.Deltiq.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.Deltiq.background.ignoresSafeArea())
            .navigationTitle(Text("nutrition.customFood.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .keyboardDismissToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onCancel()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("common.add", bundle: .module)
                    }
                    .disabled(!draft.isValid || isSaving)
                }
            }
        }
    }

    private func macroRow(_ labelKey: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(LocalizedStringKey(labelKey), bundle: .module)
            Spacer()
            TextField("", value: value, format: .number)
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
        .listRowBackground(Color.Deltiq.surface)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        switch draft.save(into: modelContext) {
        case .success(let entry):
            onSave(entry)
        case .failure:
            // Entwurf bleibt vollstaendig erhalten (kein Feld wird geleert),
            // kein Erfolgs-Feedback — nur der lokalisierte Fehlerhinweis,
            // Button wird wieder aktiv fuer einen erneuten Versuch.
            isSaving = false
            saveErrorMessage = String(localized: "nutrition.customFood.saveFailed", bundle: .module)
        }
    }
}
#endif
