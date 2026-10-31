#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
@testable import FitnessAppCore

/// Phase 4.8: Integrationstests für Portionsgröße-Bearbeitung im Mahlzeitenplan.
/// Simuliert die adjustPortion()-Logik aus MealPlannerView und prüft fachliches Verhalten.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealPlanPortionEditIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    // Rezept: 100g chicken_breast_cooked → 165kcal, 31g Protein, 0g KH, 3.6g Fett (1 Portion)
    private let recipe = Recipe(
        id: "portion_test_recipe",
        nameKey: "test.portion",
        mealTypes: [.lunch],
        dietaryTags: [], allergens: [], allergenVerified: true,
        halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
        ingredients: [RecipeIngredient(ingredientID: "chicken_breast_cooked", amountGrams: 100)]
    )
    private let food = FoodCatalogItem(
        id: "chicken_breast_cooked",
        nameKey: "test.chicken",
        category: .meat,
        kcalPer100g: 165,
        proteinPer100g: 31.0,
        carbsPer100g: 0,
        fatPer100g: 3.6
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

    // Simuliert adjustPortion() aus MealPlannerView
    private func adjust(_ assignment: PlannedMealAssignment, plan: DailyMealPlan, by delta: Double) throws {
        let clamped = min(max(assignment.portionMultiplier + delta, 0.5), 5.0)
        guard clamped != assignment.portionMultiplier else { return }
        assignment.portionMultiplier = clamped
        plan.isManuallyAdjusted = true
        try context.save()
    }

    private func makePlan(portion: Double = 1.0) throws -> (DailyMealPlan, PlannedMealAssignment) {
        let plan = DailyMealPlan(date: Date())
        context.insert(plan)
        let a = PlannedMealAssignment(recipeID: recipe.id, mealType: .lunch, portionMultiplier: portion)
        context.insert(a)
        a.plan = plan
        try context.save()
        return (plan, a)
    }

    // MARK: - 1. Portionsfaktor erhöhen

    func testPortionIncrement() throws {
        let (plan, a) = try makePlan(portion: 1.0)
        try adjust(a, plan: plan, by: 0.5)
        XCTAssertEqual(a.portionMultiplier, 1.5)
    }

    // MARK: - 2. Portionsfaktor reduzieren

    func testPortionDecrement() throws {
        let (plan, a) = try makePlan(portion: 1.5)
        try adjust(a, plan: plan, by: -0.5)
        XCTAssertEqual(a.portionMultiplier, 1.0)
    }

    // MARK: - 3. Minimalwert 0,5

    func testPortionMinimum() throws {
        let (plan, a) = try makePlan(portion: 0.5)
        try adjust(a, plan: plan, by: -0.5)
        XCTAssertEqual(a.portionMultiplier, 0.5, "Minus bei Minimum darf portionMultiplier nicht ändern")
    }

    // MARK: - 4. Maximalwert 5,0

    func testPortionMaximum() throws {
        let (plan, a) = try makePlan(portion: 5.0)
        try adjust(a, plan: plan, by: 0.5)
        XCTAssertEqual(a.portionMultiplier, 5.0, "Plus bei Maximum darf portionMultiplier nicht ändern")
    }

    // MARK: - 5. Schrittweite 0,5

    func testPortionStepSize() throws {
        let (plan, a) = try makePlan(portion: 1.0)
        try adjust(a, plan: plan, by: 0.5)
        XCTAssertEqual(a.portionMultiplier, 1.5)
        try adjust(a, plan: plan, by: 0.5)
        XCTAssertEqual(a.portionMultiplier, 2.0)
        try adjust(a, plan: plan, by: -0.5)
        XCTAssertEqual(a.portionMultiplier, 1.5)
    }

    // MARK: - 6. Nährwerte werden korrekt neu berechnet

    func testNutrientsRescaleWithPortion() {
        let catalog = [food]
        guard case .success(let base) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog, portionMultiplier: 1.0),
              case .success(let doubled) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog, portionMultiplier: 2.0)
        else { XCTFail("Nährwertberechnung fehlgeschlagen"); return }

        guard let kcal1 = base.kcal.value, let kcal2 = doubled.kcal.value else { XCTFail("kcal unbekannt"); return }
        XCTAssertEqual(kcal1 * 2, kcal2, accuracy: 0.001)
        guard let p1 = base.proteinG.value, let p2 = doubled.proteinG.value else { XCTFail("Protein unbekannt"); return }
        XCTAssertEqual(p1 * 2, p2, accuracy: 0.001)
        guard let f1 = base.fatG.value, let f2 = doubled.fatG.value else { XCTFail("Fett unbekannt"); return }
        XCTAssertEqual(f1 * 2, f2, accuracy: 0.001)
    }

    // MARK: - 7. Unbekannte Nährwerte bleiben unbekannt (OFF-01)

    func testUnknownNutrientsRemainUnknown() {
        let unknownFood = FoodCatalogItem(
            id: "unknown_fat_food",
            nameKey: "test.unknown",
            category: .meat,
            nutrientsPer100g: NutrientValues(kcal: .known(100), proteinG: .known(10), carbsG: .unknown, fatG: .unknown)
        )
        let r = Recipe(
            id: "unknown_nutrient_recipe", nameKey: "test.unknown_nutrients",
            mealTypes: [.lunch], dietaryTags: [], allergens: [], allergenVerified: true,
            halalVerifiedBy: nil, servings: 1, prepMinutes: 5,
            ingredients: [RecipeIngredient(ingredientID: "unknown_fat_food", amountGrams: 100)]
        )
        guard case .success(let n) = RecipeNutritionCalculator.nutrients(for: r, catalog: [unknownFood], portionMultiplier: 3.0)
        else { XCTFail("Nährwertberechnung fehlgeschlagen"); return }

        XCTAssertTrue(n.carbsG.isUnknown, "Unbekannte KH müssen nach Skalierung unbekannt bleiben (OFF-01)")
        XCTAssertTrue(n.fatG.isUnknown, "Unbekanntes Fett muss nach Skalierung unbekannt bleiben (OFF-01)")
        XCTAssertFalse(n.kcal.isUnknown, "Bekannte kcal müssen bekannt bleiben")
    }

    // MARK: - 8. Tagesübersicht aktualisiert sich

    func testDayTotalReflectsUpdatedPortion() throws {
        let (plan, a) = try makePlan(portion: 1.0)
        let catalog = [food]
        guard case .success(let before) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog, portionMultiplier: a.portionMultiplier)
        else { XCTFail(); return }

        try adjust(a, plan: plan, by: 0.5)

        guard case .success(let after) = RecipeNutritionCalculator.nutrients(for: recipe, catalog: catalog, portionMultiplier: a.portionMultiplier)
        else { XCTFail(); return }

        guard let kcalBefore = before.kcal.value, let kcalAfter = after.kcal.value else { XCTFail("kcal unbekannt"); return }
        XCTAssertGreaterThan(kcalAfter, kcalBefore, "Tagesübersicht muss nach Portionserhöhung mehr kcal zeigen")
    }

    // MARK: - 9. Persistenz nach erneutem Laden

    func testPortionPersistsAfterFetch() throws {
        let (plan, a) = try makePlan(portion: 1.0)
        try adjust(a, plan: plan, by: 1.0)
        XCTAssertEqual(a.portionMultiplier, 2.0)

        let fresh = try context.fetch(FetchDescriptor<PlannedMealAssignment>())
        XCTAssertEqual(fresh.first?.portionMultiplier, 2.0, "portionMultiplier muss nach erneutem Fetch erhalten bleiben")
    }

    // MARK: - 10. isManuallyAdjusted wird gesetzt

    func testPortionSetsIsManuallyAdjusted() throws {
        let (plan, a) = try makePlan()
        XCTAssertFalse(plan.isManuallyAdjusted)
        try adjust(a, plan: plan, by: 0.5)
        XCTAssertTrue(plan.isManuallyAdjusted)
    }

    // MARK: - 11. Generator überschreibt den manuell angepassten Plan nicht

    func testGeneratorDoesNotOverwriteAfterPortionEdit() throws {
        let (plan, a) = try makePlan()
        try adjust(a, plan: plan, by: 0.5)
        let changedPortion = a.portionMultiplier

        let newAssignment = PlannedMealAssignment(recipeID: "other_recipe", mealType: .lunch)
        context.insert(newAssignment)
        let updated = try DailyMealPlan.upsertGenerated(
            date: plan.date,
            assignments: [newAssignment],
            warning: nil,
            in: context
        )

        XCTAssertFalse(updated, "Generator darf manuell angepassten Plan nicht überschreiben")
        let fetched = try context.fetch(FetchDescriptor<PlannedMealAssignment>())
        XCTAssertTrue(fetched.contains { $0.portionMultiplier == changedPortion }, "Manuell angepasste Portion muss erhalten bleiben")
    }

    // MARK: - 12. Tagebucheinträge bleiben unverändert

    func testPortionEditDoesNotTouchMealEntries() throws {
        let entry = MealEntry(date: Date(), mealType: .lunch)
        context.insert(entry)
        let item = MealItem(
            catalogID: "x", nameSnapshot: "Test", quantity: 100, unit: .gram,
            nutrients: NutrientValues(kcal: .known(200), proteinG: .known(10), carbsG: .known(20), fatG: .known(5)),
            meal: entry
        )
        context.insert(item)
        try context.save()

        let (plan, a) = try makePlan()
        try adjust(a, plan: plan, by: 1.0)

        XCTAssertEqual(try context.fetch(FetchDescriptor<MealEntry>()).count, 1, "MealEntry darf nicht verändert werden")
        XCTAssertEqual(try context.fetch(FetchDescriptor<MealItem>()).count, 1, "MealItem darf nicht verändert werden")
    }

    // MARK: - 13. Mehrfaches schnelles Ändern erzeugt keine inkonsistenten Werte

    func testRapidPortionChangesAreConsistent() throws {
        let (plan, a) = try makePlan(portion: 1.0)
        for _ in 0..<20 {
            try adjust(a, plan: plan, by: 0.5)
        }
        XCTAssertEqual(a.portionMultiplier, 5.0, "Wiederholtes Erhöhen muss bei Maximum 5,0 klemmen")
        for _ in 0..<20 {
            try adjust(a, plan: plan, by: -0.5)
        }
        XCTAssertEqual(a.portionMultiplier, 0.5, "Wiederholtes Verkleinern muss bei Minimum 0,5 klemmen")
    }
}
#endif
