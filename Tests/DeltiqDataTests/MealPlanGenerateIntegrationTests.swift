#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
@testable import DeltiqCore

/// Phase 5: Testet den generate→upsert-Datenpfad (analog generatePlan() in MealPlannerView).
/// Die Rezeptliste ist inline definiert — kein Bundle.module-Zugriff in Tests nötig.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealPlanGenerateIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    private let lunchRecipe = Recipe(
        id: "r_lunch", nameKey: "test.lunch",
        mealTypes: [.lunch], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken_breast_cooked", amountGrams: 100)]
    )
    private let breakfastRecipe = Recipe(
        id: "r_breakfast", nameKey: "test.breakfast",
        mealTypes: [.breakfast], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken_breast_cooked", amountGrams: 100)]
    )
    private let dinnerRecipe = Recipe(
        id: "r_dinner", nameKey: "test.dinner",
        mealTypes: [.dinner], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken_breast_cooked", amountGrams: 100)]
    )
    private let snackRecipe = Recipe(
        id: "r_snack", nameKey: "test.snack",
        mealTypes: [.snack], dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken_breast_cooked", amountGrams: 100)]
    )

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Schema(AppSchema.types),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    private var catalog: [Recipe] { [lunchRecipe, breakfastRecipe, dinnerRecipe, snackRecipe] }

    /// Simuliert generatePlan() aus MealPlannerView: generate → PlannedMealAssignment → upsertGenerated.
    @discardableResult
    private func runGenerate(for date: Date = Date()) throws -> Bool {
        let result = MealPlanGenerator.generate(
            for: date,
            mealTypes: MealType.allCases,
            preferences: UserNutritionPreferences(),
            dailyCalorieGoalKcal: nil,
            recentRecipeIDs: [],
            recipeCatalog: catalog
        )
        guard case .success(let plan) = result else { return false }
        let assignments = plan.assignments.map { a -> PlannedMealAssignment in
            let pa = PlannedMealAssignment(recipeID: a.recipeID, mealType: a.mealType, portionMultiplier: a.portionMultiplier)
            context.insert(pa)
            return pa
        }
        return try DailyMealPlan.upsertGenerated(
            date: date,
            assignments: assignments,
            warning: plan.insufficientSelectionWarning,
            in: context
        )
    }

    // MARK: - 1. Plan wird erstellt

    func testGenerateCreatesPlan() throws {
        let date = Date()
        try runGenerate(for: date)

        let plans = try context.fetch(FetchDescriptor<DailyMealPlan>())
        XCTAssertEqual(plans.count, 1, "Genau ein Plan muss entstehen")
        XCTAssertEqual(plans.first?.assignments.count, MealType.allCases.count)
        XCTAssertFalse(plans.first?.isManuallyAdjusted ?? true)
    }

    func testGeneratePlanHasOneAssignmentPerMealType() throws {
        try runGenerate()

        let assignments = try context.fetch(FetchDescriptor<PlannedMealAssignment>())
        let types = Set(assignments.map(\.mealType))
        XCTAssertEqual(types, Set(MealType.allCases), "Jeder MealType muss belegt sein")
    }

    // MARK: - 2. Manuell angepasster Plan wird nicht überschrieben

    func testGenerateDoesNotOverwriteManualPlan() throws {
        let date = Date()
        let plan = DailyMealPlan(date: date)
        context.insert(plan)
        let manual = PlannedMealAssignment(recipeID: "manual_recipe", mealType: .lunch)
        context.insert(manual)
        manual.plan = plan
        plan.isManuallyAdjusted = true
        try context.save()

        let updated = try runGenerate(for: date)

        XCTAssertFalse(updated, "isManuallyAdjusted-Plan darf nicht überschrieben werden")
        let plans = try context.fetch(FetchDescriptor<DailyMealPlan>())
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.assignments.first?.recipeID, "manual_recipe")
    }

    // MARK: - 3. Wiederholter Generate-Aufruf erzeugt keinen Duplikat-Plan

    func testGenerateTwiceNosDuplicatePlan() throws {
        let date = Date()
        try runGenerate(for: date)
        try runGenerate(for: date)

        let plans = try context.fetch(FetchDescriptor<DailyMealPlan>())
        XCTAssertEqual(plans.count, 1, "Zweiter Generate-Aufruf darf keinen zweiten Plan anlegen")
    }

    // MARK: - 5. Kein Duplikat-Rezept wenn Katalog groß genug

    func testGenerateNoDuplicateRecipesWhenCatalogLargeEnough() {
        let allTypes = MealType.allCases
        let multiRecipes = (0..<5).map { i in
            Recipe(
                id: "multi_\(i)", nameKey: "test.multi_\(i)",
                mealTypes: allTypes, dietaryTags: [], allergens: [], allergenVerified: true,
                halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
                ingredients: [RecipeIngredient(ingredientID: "x", amountGrams: 100)]
            )
        }
        guard case .success(let plan) = MealPlanGenerator.generate(
            for: Date(), mealTypes: allTypes,
            preferences: UserNutritionPreferences(),
            dailyCalorieGoalKcal: nil,
            recentRecipeIDs: [],
            recipeCatalog: multiRecipes
        ) else { XCTFail("generate sollte Erfolg liefern"); return }

        let ids = plan.assignments.map(\.recipeID)
        XCTAssertEqual(Set(ids).count, ids.count, "Kein Rezept darf im selben Plan doppelt vorkommen")
    }

    // MARK: - 4. Tagebuch-Einträge bleiben unberührt

    func testGenerateDoesNotTouchMealEntries() throws {
        let diaryEntry = MealEntry(date: Date(), mealType: .lunch)
        context.insert(diaryEntry)
        let item = MealItem(
            catalogID: "x", nameSnapshot: "Test", quantity: 100, unit: .gram,
            nutrients: NutrientValues(kcal: .known(200), proteinG: .known(10), carbsG: .known(20), fatG: .known(5)),
            meal: diaryEntry
        )
        context.insert(item)
        try context.save()

        try runGenerate()

        let entries = try context.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(entries.count, 1, "MealEntry darf durch Plan-Generierung nicht verändert werden")
        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.count, 1)
    }
}
#endif
