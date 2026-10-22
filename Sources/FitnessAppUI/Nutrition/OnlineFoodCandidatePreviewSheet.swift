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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            // nutrient value. Confirming with a field still blank stores 0,
            // same as leaving a manual-entry field untouched elsewhere.
            TextField("", value: value, format: .number)
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
    }

    private func confirm() {
        onConfirm(OnlineFoodImportValues(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kcalPer100g: kcalPer100g ?? 0,
            proteinPer100g: proteinPer100g ?? 0,
            carbsPer100g: carbsPer100g ?? 0,
            fatPer100g: fatPer100g ?? 0
        ))
    }
}
#endif
