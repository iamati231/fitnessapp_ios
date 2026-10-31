#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Phase 4.3 (2026-10-31): Rezeptdetail-Ansicht mit Portionsanpassung.
/// Phase 4.4 (2026-10-31): "Zum Tagebuch hinzufügen" persistiert MealEntry + MealItems.
/// Wird aus MealPlannerView via `MealPlannerRoute.recipeDetail` gepusht.
///
/// OFF-01-konform: unbekannte Naehrwerte werden als "–" angezeigt, niemals als 0.
/// Snapshot-Semantik: gespeicherte Naehrwerte sind zum Zeitpunkt des Speicherns
/// eingefroren — nachträgliche Katalogänderungen berühren historische Einträge nie.
@available(iOS 17.0, macOS 14.0, *)
public struct RecipeDetailView: View {

    let recipeID: String
    let mealType: MealType
    let date: Date

    @State private var portionMultiplier: Double
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var saveError: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let recipeCatalog: [Recipe] = RecipeCatalogData.all
    private let foodCatalog: [FoodCatalogItem] = FoodCatalogData.all

    public init(recipeID: String, mealType: MealType, initialPortionMultiplier: Double, date: Date) {
        self.recipeID = recipeID
        self.mealType = mealType
        self.date = date
        _portionMultiplier = State(initialValue: max(0.5, min(10.0, initialPortionMultiplier)))
    }

    // MARK: - Derived state

    private var recipe: Recipe? { recipeCatalog.first { $0.id == recipeID } }

    private var nutrients: NutrientValues? {
        guard let r = recipe else { return nil }
        if case .success(let v) = RecipeNutritionCalculator.nutrients(
            for: r, catalog: foodCatalog, portionMultiplier: portionMultiplier
        ) { return v }
        return nil
    }

    private var recipeName: String {
        guard let r = recipe else {
            return String(localized: "recipe.detail.unknown.name", bundle: .module)
        }
        return String(localized: String.LocalizationValue(r.nameKey), bundle: .module)
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: String.LocalizationValue(mealType.localizationKey), bundle: .module).uppercased(),
                title: recipeName,
                onBack: { dismiss() }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    portionSection
                    if let n = nutrients {
                        nutritionSection(n)
                    }
                    ingredientsSection
                    addToDiaryButton
                }
                .deltiqScreen()
            }
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .deltiqSwipeBackEnabled()
    }

    // MARK: - Portion

    private var portionSection: some View {
        DeltiqSection(String(localized: "recipe.detail.portion.label", bundle: .module).uppercased()) {
            HStack {
                Spacer()
                Button {
                    if portionMultiplier > 0.5 { portionMultiplier = portionMultiplier - 0.5 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(portionMultiplier > 0.5 ? Color.deltiqOrange : Color.Deltiq.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.Deltiq.fill)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("×\(portionMultiplier.formatted(.number.precision(.fractionLength(0...1))))")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(minWidth: 56)
                    .multilineTextAlignment(.center)

                Button {
                    if portionMultiplier < 10.0 { portionMultiplier = portionMultiplier + 0.5 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(portionMultiplier < 10.0 ? Color.deltiqOrange : Color.Deltiq.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.Deltiq.fill)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Nutrition

    @ViewBuilder
    private func nutritionSection(_ n: NutrientValues) -> some View {
        DeltiqSection(String(localized: "recipe.detail.nutrition.title", bundle: .module).uppercased()) {
            nutrientRow(String(localized: "nutrition.goals.calorie.label", bundle: .module), value: n.kcal, unit: "kcal")
            Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
            nutrientRow(String(localized: "nutrition.goals.protein.label", bundle: .module), value: n.proteinG, unit: "g")
            Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
            nutrientRow(String(localized: "nutrition.goals.carbs.label", bundle: .module), value: n.carbsG, unit: "g")
            Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
            nutrientRow(String(localized: "nutrition.goals.fat.label", bundle: .module), value: n.fatG, unit: "g")
            if n.partiallyKnown {
                Text("nutrition.day.total.incomplete", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }

    private func nutrientRow(_ label: String, value: KnownValue, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)
            Spacer()
            Text(NutritionDisplay.text(value, unit: unit))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .fitnessNumberStyle()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        DeltiqSection(String(localized: "recipe.detail.ingredients.title", bundle: .module).uppercased()) {
            ingredientsContent
        }
    }

    @ViewBuilder
    private var ingredientsContent: some View {
        if let r = recipe {
            let foodByID = Dictionary(uniqueKeysWithValues: foodCatalog.map { ($0.id, $0) })
            let factor = portionMultiplier / Double(max(r.servings, 1))
            ForEach(Array(r.ingredients.enumerated()), id: \.offset) { index, ingredient in
                let food = foodByID[ingredient.ingredientID]
                let scaledGrams = ingredient.amountGrams * factor
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(food.map {
                            String(localized: String.LocalizationValue($0.nameKey), bundle: .module)
                        } ?? ingredient.ingredientID)
                            .font(.system(size: 15))
                            .foregroundStyle(food != nil ? Color.primary : Color.Deltiq.textSecondary)
                        Spacer()
                        Text("\(scaledGrams.truncated(to: 0).formattedNoDecimals) g")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.Deltiq.textSecondary)
                            .fitnessNumberStyle()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    if index < r.ingredients.count - 1 {
                        Rectangle().fill(Color.Deltiq.divider).frame(height: 1)
                    }
                }
            }
        } else {
            Text("recipe.detail.ingredients.missing", bundle: .module)
                .font(.system(size: 15))
                .foregroundStyle(Color.Deltiq.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
    }

    // MARK: - Add to Diary

    private var addToDiaryButton: some View {
        VStack(spacing: 8) {
            if let error = saveError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button {
                saveRecipeToDiary()
            } label: {
                Text(saveSuccess
                    ? String(localized: "recipe.detail.addToDiary.success", bundle: .module)
                    : String(localized: "recipe.detail.addToDiary.button", bundle: .module))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.deltiqOrange.opacity(isSaving || saveSuccess ? 0.5 : 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSaving || saveSuccess)
        }
    }

    private func saveRecipeToDiary() {
        guard let r = recipe, !isSaving, !saveSuccess else { return }
        isSaving = true
        saveError = nil

        let factor = portionMultiplier / Double(max(r.servings, 1))
        let foodByID = Dictionary(uniqueKeysWithValues: foodCatalog.map { ($0.id, $0) })

        for ingredient in r.ingredients {
            guard foodByID[ingredient.ingredientID] != nil else {
                saveError = String(localized: "recipe.detail.addToDiary.error.missingIngredient", bundle: .module)
                isSaving = false
                return
            }
        }

        let entry = MealEntry(date: date, mealType: mealType)
        modelContext.insert(entry)
        var insertedItems: [MealItem] = []

        for ingredient in r.ingredients {
            let food = foodByID[ingredient.ingredientID]!
            let scaledGrams = ingredient.amountGrams * factor
            let nutrients = NutritionCalculations.nutrients(for: food, quantity: scaledGrams, unit: .gram)
                ?? NutrientValues(kcal: .unknown, proteinG: .unknown, carbsG: .unknown, fatG: .unknown)
            let name = String(localized: String.LocalizationValue(food.nameKey), bundle: .module)
            let item = MealItem(
                catalogID: food.id,
                nameSnapshot: name,
                quantity: scaledGrams,
                unit: .gram,
                nutrients: nutrients,
                meal: entry
            )
            modelContext.insert(item)
            insertedItems.append(item)
        }

        do {
            try modelContext.save()
            isSaving = false
            saveSuccess = true
        } catch {
            for item in insertedItems {
                entry.items.removeAll { $0.persistentModelID == item.persistentModelID }
                modelContext.delete(item)
            }
            modelContext.delete(entry)
            isSaving = false
            saveError = String(localized: "recipe.detail.addToDiary.error.saveFailed", bundle: .module)
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Rezeptdetails – Mittagessen") {
    let container = try! ModelContainer(
        for: Schema(AppSchema.types),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return NavigationStack {
        RecipeDetailView(
            recipeID: "chicken_rice_bowl",
            mealType: .lunch,
            initialPortionMultiplier: 1.0,
            date: Calendar.current.startOfDay(for: Date())
        )
    }
    .modelContainer(container)
    .environment(AppNavigation())
}
#endif
#endif
