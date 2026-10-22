#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import FitnessAppFoodLookup

/// Confirmed values out of `OnlineFoodCandidatePreviewSheet` — the caller
/// (e.g. `AddMealView.confirmOnlineImport`) maps this straight onto Task 2's
/// `FoodCatalogEntry(displayName:source:category:...)` convenience init.
/// Deliberately NOT `OnlineFoodCandidate` itself: the user may have edited
/// the prefilled values before confirming.
struct OnlineFoodImportValues: Equatable {
    let name: String
    let kcalPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double

    /// Final-review fix (C1): the only way to get an `OnlineFoodImportValues`
    /// is through here — fails unless the name is non-blank AND all four
    /// macros are present (non-nil) and `>= 0`. Mirrors
    /// `CustomFoodDraft.isValid` exactly, so a candidate missing a nutrient
    /// (common — Open Food Facts is crowd-sourced) can never be silently
    /// coerced to 0 via `?? 0` on confirm.
    init?(name: String, kcalPer100g: Double?, proteinPer100g: Double?, carbsPer100g: Double?, fatPer100g: Double?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let kcal = kcalPer100g, kcal >= 0,
              let protein = proteinPer100g, protein >= 0,
              let carbs = carbsPer100g, carbs >= 0,
              let fat = fatPer100g, fat >= 0
        else { return nil }
        self.name = trimmedName
        self.kcalPer100g = kcal
        self.proteinPer100g = protein
        self.carbsPer100g = carbs
        self.fatPer100g = fat
    }
}

/// Task 4/5 reusable component: preview + confirm/cancel for one tapped
/// `OnlineFoodCandidate`, before any `FoodCatalogEntry` is created. Per the
/// Task 4 brief — name + macros/100g, editable, prefilled from the
/// candidate, missing fields stay EMPTY (never shown as "0", so nothing
/// looks like real data that wasn't actually returned by Open Food Facts).
/// Confirming here does NOT touch `ModelContext`/`MealDraft` itself — that's
/// the caller's job via `onConfirm`, which then reuses the existing
/// `addItem` path exactly like a manual/AI catalog selection.
@available(iOS 17.0, macOS 14.0, *)
struct OnlineFoodCandidatePreviewSheet: View {
    let onConfirm: (OnlineFoodImportValues) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var kcalPer100g: Double?
    @State private var proteinPer100g: Double?
    @State private var carbsPer100g: Double?
    @State private var fatPer100g: Double?

    init(candidate: OnlineFoodCandidate, onConfirm: @escaping (OnlineFoodImportValues) -> Void, onCancel: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _name = State(initialValue: candidate.name)
        _kcalPer100g = State(initialValue: candidate.kcalPer100g)
        _proteinPer100g = State(initialValue: candidate.proteinPer100g)
        _carbsPer100g = State(initialValue: candidate.carbsPer100g)
        _fatPer100g = State(initialValue: candidate.fatPer100g)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "nutrition.onlineImport.nameLabel", bundle: .module), text: $name)
                }
                Section {
                    macroRow("nutrition.onlineImport.kcalLabel", value: $kcalPer100g)
                    macroRow("nutrition.onlineImport.proteinLabel", value: $proteinPer100g)
                    macroRow("nutrition.onlineImport.carbsLabel", value: $carbsPer100g)
                    macroRow("nutrition.onlineImport.fatLabel", value: $fatPer100g)
                }
            }
            .navigationTitle(Text("nutrition.onlineImport.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                        confirm()
                    } label: {
                        Text("common.add", bundle: .module)
                    }
                    // C1 fix: disabled whenever any macro is still missing/
                    // negative, not just on an empty name — same gate
                    // `CustomFoodEntrySheet` applies via `draft.isValid`.
                    .disabled(pendingValues == nil)
                }
            }
        }
    }

    private func macroRow(_ labelKey: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(LocalizedStringKey(labelKey), bundle: .module)
            Spacer()
            // Left blank when `nil` (missing Open Food Facts field) instead
            // of prefilling "0" — Global Constraint: never fabricate a
            // nutrient value. A field still blank at confirm time keeps
            // "Add" disabled (see `pendingValues`), it is never silently
            // stored as 0.
            TextField("", value: value, format: .number)
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
    }

    /// `nil` while the name is blank or a macro is missing/negative — the
    /// single source of truth for both the "Add" button's `.disabled` and
    /// `confirm()` itself, so the two can never disagree.
    private var pendingValues: OnlineFoodImportValues? {
        OnlineFoodImportValues(
            name: name,
            kcalPer100g: kcalPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g
        )
    }

    private func confirm() {
        guard let values = pendingValues else { return }
        onConfirm(values)
    }
}
#endif
