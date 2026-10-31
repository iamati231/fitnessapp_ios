#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Phase 4.7: SwiftData-Integrationstests für „Alternative generieren".
/// Testet den vollständigen Persistenzpfad, wie er in regenerateAssignment() läuft.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealPlanAlternativeIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    // Katalog mit je einem Rezept pro mealType
    private let lunchA = Recipe(
        id: "lunch_a", nameKey: "test.lunch_a", mealTypes: [.lunch],
        dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken_breast_cooked", amountGrams: 100)]
    )
    private let lunchB = Recipe(
        id: "lunch_b", nameKey: "test.lunch_b", mealTypes: [.lunch],
        dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken_breast_cooked", amountGrams: 100)]
    )
    private let dinnerA = Recipe(
        id: "dinner_a", nameKey: "test.dinner_a", mealTypes: [.dinner],
        dietaryTags: [], allergens: [], allergenVerified: true,
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

    // Erstellt einen Plan mit Lunch (lunch_a) und Dinner (dinner_a)
    private func makeTestPlan() throws -> (plan: DailyMealPlan, lunch: PlannedMealAssignment, dinner: PlannedMealAssignment) {
        let plan = DailyMealPlan(date: Date())
        context.insert(plan)
        let lunch = PlannedMealAssignment(recipeID: "lunch_a", mealType: .lunch, portionMultiplier: 2.0)
        let dinner = PlannedMealAssignment(recipeID: "dinner_a", mealType: .dinner)
        context.insert(lunch)
        context.insert(dinner)
        lunch.plan = plan
        dinner.plan = plan
        try context.save()
        return (plan, lunch, dinner)
    }

    // Simuliert regenerateAssignment() aus MealPlannerView
    private func runRegenerate(
        assignment: PlannedMealAssignment,
        plan: DailyMealPlan,
        catalog: [Recipe],
        seed: Int = 0
    ) throws -> Bool {
        let usedIDs = Set(plan.assignments.map(\.recipeID))
        guard let alternative = MealPlanGenerator.alternativeRecipe(
            for: assignment.mealType,
            excluding: assignment.recipeID,
            preferExcluding: usedIDs,
            from: catalog,
            preferences: UserNutritionPreferences(),
            seed: seed
        ) else { return false }
        assignment.recipeID = alternative.id
        assignment.portionMultiplier = 1.0
        plan.isManuallyAdjusted = true
        try context.save()
        return true
    }

    // MARK: - 7. Andere Assignments bleiben unverändert

    func testRegenerateOnlyChangesTargetAssignment() throws {
        let (plan, lunch, dinner) = try makeTestPlan()
        let originalDinnerID = dinner.recipeID

        try runRegenerate(assignment: lunch, plan: plan, catalog: [lunchA, lunchB, dinnerA])

        let saved = try context.fetch(FetchDescriptor<PlannedMealAssignment>())
        let savedDinner = saved.first { $0.mealType == .dinner }
        XCTAssertEqual(savedDinner?.recipeID, originalDinnerID, "Dinner muss unverändert bleiben")
        XCTAssertEqual(saved.count, 2, "Keine Assignments dürfen verloren gehen")
    }

    // MARK: - 8. Portionsmultiplikator wird auf 1.0 zurückgesetzt

    func testRegenerateResetsPortion() throws {
        let (plan, lunch, _) = try makeTestPlan()
        XCTAssertEqual(lunch.portionMultiplier, 2.0, "Precondition: Portion war 2.0")

        try runRegenerate(assignment: lunch, plan: plan, catalog: [lunchA, lunchB, dinnerA])

        let saved = try context.fetch(FetchDescriptor<PlannedMealAssignment>()).first { $0.mealType == .lunch }
        XCTAssertEqual(saved?.portionMultiplier, 1.0, "Portion muss nach Neugenerierung 1.0 sein")
    }

    // MARK: - 9. isManuallyAdjusted wird gesetzt

    func testRegenerateSetsIsManuallyAdjusted() throws {
        let (plan, lunch, _) = try makeTestPlan()
        XCTAssertFalse(plan.isManuallyAdjusted)

        try runRegenerate(assignment: lunch, plan: plan, catalog: [lunchA, lunchB, dinnerA])

        let savedPlan = try context.fetch(FetchDescriptor<DailyMealPlan>()).first!
        XCTAssertTrue(savedPlan.isManuallyAdjusted)
    }

    // MARK: - 10. Keine Alternative vorhanden → kein Datenstand geändert

    func testRegenerateNoAlternative_noStateChange() throws {
        let (plan, lunch, _) = try makeTestPlan()
        let originalID = lunch.recipeID

        // Katalog enthält nur lunch_a (das aktuelle Rezept) → keine Alternative
        let changed = try runRegenerate(assignment: lunch, plan: plan, catalog: [lunchA, dinnerA])

        XCTAssertFalse(changed, "Rückgabewert muss false sein wenn keine Alternative")
        let saved = try context.fetch(FetchDescriptor<PlannedMealAssignment>()).first { $0.mealType == .lunch }
        XCTAssertEqual(saved?.recipeID, originalID, "recipeID darf bei fehlender Alternative nicht geändert werden")
        let savedPlan = try context.fetch(FetchDescriptor<DailyMealPlan>()).first!
        XCTAssertFalse(savedPlan.isManuallyAdjusted, "isManuallyAdjusted darf nicht gesetzt werden wenn keine Alternative")
    }

    // MARK: - 11. Wiederholte Neugenerierung funktioniert

    func testRegenerateCanRunMultipleTimes() throws {
        let (plan, lunch, _) = try makeTestPlan()

        // Seed 0 → lunch_b (0 % 1 = 0, pool=[lunch_b])
        try runRegenerate(assignment: lunch, plan: plan, catalog: [lunchA, lunchB, dinnerA], seed: 0)
        let afterFirst = lunch.recipeID

        // Zweiter Aufruf: wieder lunch_a oder lunch_b (aktuelles exkludiert)
        try runRegenerate(assignment: lunch, plan: plan, catalog: [lunchA, lunchB, dinnerA], seed: 1)
        let afterSecond = lunch.recipeID

        XCTAssertNotEqual(afterFirst, afterSecond, "Wiederholte Neugenerierung mit anderem Seed soll anderes Rezept liefern")

        // Plan darf immer noch nur 2 Assignments haben
        let assignments = try context.fetch(FetchDescriptor<PlannedMealAssignment>())
        XCTAssertEqual(assignments.count, 2)
    }

    // MARK: - 12. Tagebucheinträge bleiben unverändert

    func testRegenerateDoesNotTouchMealEntries() throws {
        let entry = MealEntry(date: Date(), mealType: .lunch)
        context.insert(entry)
        let item = MealItem(
            catalogID: "x", nameSnapshot: "Test", quantity: 100, unit: .gram,
            nutrients: NutrientValues(kcal: .known(300), proteinG: .known(20), carbsG: .known(30), fatG: .known(8)),
            meal: entry
        )
        context.insert(item)
        try context.save()

        let (plan, lunch, _) = try makeTestPlan()
        try runRegenerate(assignment: lunch, plan: plan, catalog: [lunchA, lunchB, dinnerA])

        let entries = try context.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(entries.count, 1, "MealEntry muss unberührt bleiben")
        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.count, 1, "MealItem muss unberührt bleiben")
        XCTAssertEqual(items.first?.nutrientsSnapshot.kcal, .known(300))
    }

    // MARK: - 13. Persistenz: Plan lädt korrekt nach erneutem Fetch

    func testRegeneratedPlanPersistsAfterFetch() throws {
        let (plan, lunch, _) = try makeTestPlan()
        try runRegenerate(assignment: lunch, plan: plan, catalog: [lunchA, lunchB, dinnerA])
        let newID = lunch.recipeID

        // Neuer FetchDescriptor — simuliert erneutes Laden
        let freshPlans = try context.fetch(FetchDescriptor<DailyMealPlan>())
        let freshLunch = freshPlans.first?.assignments.first { $0.mealType == .lunch }
        XCTAssertEqual(freshLunch?.recipeID, newID, "Geändertes Rezept muss nach erneutem Fetch noch vorhanden sein")
        XCTAssertTrue(freshPlans.first?.isManuallyAdjusted ?? false)
    }
}
#endif
