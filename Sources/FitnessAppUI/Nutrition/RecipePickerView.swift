#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Phase 4.5: Sheet zum Austauschen eines geplanten Rezepts.
/// Zeigt alle fuer `mealType` und `preferences` geeigneten Alternativen —
/// ausser dem aktuell zugewiesenen Rezept.
/// Ernährungstagebuch-Eintraege werden niemals beruehrt (strukturelle Trennung).
@available(iOS 17.0, macOS 14.0, *)
struct RecipePickerView: View {

    let mealType: MealType
    let currentRecipeID: String
    let preferences: UserNutritionPreferences
    let onSelect: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss

    private let recipeCatalog: [Recipe] = RecipeCatalogData.all
    private let foodCatalog: [FoodCatalogItem] = FoodCatalogData.all

    private var alternatives: [Recipe] {
        MealPlanGenerator.eligibleRecipes(in: recipeCatalog, for: mealType, preferences: preferences)
            .filter { $0.id != currentRecipeID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if alternatives.isEmpty {
                    emptyState
                } else {
                    recipeList
                }
            }
            .navigationTitle(String(localized: "mealPlanner.picker.title", bundle: .module))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", bundle: .module)) { dismiss() }
                }
            }
        }
    }

    private var recipeList: some View {
        List(alternatives) { recipe in
            Button {
                onSelect(recipe)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: String.LocalizationValue(recipe.nameKey), bundle: .module))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    if let n = nutrients(for: recipe),
                       let kcal = n.kcal.value {
                        Text("\(kcal.truncated(to: 0).formattedNoDecimals) kcal")
                            .font(.caption)
                            .foregroundStyle(Color.Deltiq.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("mealPlanner.picker.empty", bundle: .module)
                .font(.system(size: 15))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func nutrients(for recipe: Recipe) -> NutrientValues? {
        if case .success(let v) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: foodCatalog) {
            return v
        }
        return nil
    }
}
#endif
