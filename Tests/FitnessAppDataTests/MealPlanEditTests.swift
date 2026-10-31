#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Phase 4.5: Testet Austauschen und Entfernen von PlannedMealAssignments.
/// Stellt sicher, dass Ernährungstagebuch-Einträge niemals berührt werden.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealPlanEditTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

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

    // MARK: - Hilfsfunktionen

    private func makePlan(date: Date = Date(), assignments: [(recipeID: String, mealType: MealType)]) throws -> DailyMealPlan {
        let plan = DailyMealPlan(date: date)
        context.insert(plan)
        for a in assignments {
            let assignment = PlannedMealAssignment(recipeID: a.recipeID, mealType: a.mealType)
            context.insert(assignment)
            assignment.plan = plan
        }
        try context.save()
        return plan
    }

    private func makeMealEntry(date: Date = Date()) throws -> MealEntry {
        let entry = MealEntry(date: date, mealType: .lunch)
        context.insert(entry)
        let nutrients = NutrientValues(kcal: .known(300), proteinG: .known(25), carbsG: .known(30), fatG: .known(8))
        let item = MealItem(catalogID: "chicken", nameSnapshot: "Hähnchen", quantity: 150, unit: .gram, nutrients: nutrients, meal: entry)
        context.insert(item)
        try context.save()
        return entry
    }

    // MARK: - 1. Rezept austauschen

    func testSwapReplacesRecipeID() throws {
        let plan = try makePlan(assignments: [("recipe_a", .lunch)])
        let assignment = plan.assignments.first!

        // Austauschen simulieren (analog swapAssignment in MealPlannerView)
        assignment.recipeID = "recipe_b"
        assignment.portionMultiplier = 1.0
        plan.isManuallyAdjusted = true
        try context.save()

        let saved = try context.fetch(FetchDescriptor<PlannedMealAssignment>()).first!
        XCTAssertEqual(saved.recipeID, "recipe_b")
        XCTAssertEqual(saved.portionMultiplier, 1.0)
        XCTAssertTrue(plan.isManuallyAdjusted)
    }

    func testSwapOnlyChangesSelectedAssignment() throws {
        let plan = try makePlan(assignments: [
            ("recipe_a", .lunch),
            ("recipe_x", .dinner)
        ])
        let lunchAssignment = plan.assignments.first { $0.mealType == .lunch }!

        lunchAssignment.recipeID = "recipe_b"
        plan.isManuallyAdjusted = true
        try context.save()

        let dinnerAssignment = plan.assignments.first { $0.mealType == .dinner }!
        XCTAssertEqual(dinnerAssignment.recipeID, "recipe_x", "Andere Mahlzeiten dürfen nicht verändert werden")
    }

    func testSwapPortionMultiplierReset() throws {
        let plan = try makePlan(assignments: [("recipe_a", .lunch)])
        let assignment = plan.assignments.first!
        assignment.portionMultiplier = 2.0
        try context.save()

        // Austauschen setzt Portion auf 1.0
        assignment.recipeID = "recipe_b"
        assignment.portionMultiplier = 1.0
        plan.isManuallyAdjusted = true
        try context.save()

        XCTAssertEqual(assignment.portionMultiplier, 1.0)
    }

    func testSwapSetsIsManuallyAdjusted() throws {
        let plan = try makePlan(assignments: [("recipe_a", .lunch)])
        XCTAssertFalse(plan.isManuallyAdjusted)

        plan.assignments.first!.recipeID = "recipe_b"
        plan.isManuallyAdjusted = true
        try context.save()

        let fetchedPlan = try context.fetch(FetchDescriptor<DailyMealPlan>()).first!
        XCTAssertTrue(fetchedPlan.isManuallyAdjusted, "isManuallyAdjusted muss nach manuellem Austausch gesetzt sein")
    }

    // MARK: - 2. Rezept entfernen

    func testRemoveDeletesOnlySelectedAssignment() throws {
        let plan = try makePlan(assignments: [
            ("recipe_a", .lunch),
            ("recipe_b", .dinner)
        ])
        let toRemove = plan.assignments.first { $0.mealType == .lunch }!

        plan.isManuallyAdjusted = true
        context.delete(toRemove)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<PlannedMealAssignment>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.recipeID, "recipe_b")
    }

    func testRemoveKeepsOtherMealTypes() throws {
        let plan = try makePlan(assignments: [
            ("recipe_a", .lunch),
            ("recipe_b", .dinner),
            ("recipe_c", .breakfast)
        ])
        let toRemove = plan.assignments.first { $0.mealType == .lunch }!
        context.delete(toRemove)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<PlannedMealAssignment>())
        XCTAssertEqual(remaining.count, 2)
        XCTAssertFalse(remaining.contains { $0.mealType == .lunch }, "Mittagessen muss entfernt sein")
    }

    func testRemoveDoesNotDeletePlan() throws {
        let plan = try makePlan(assignments: [("recipe_a", .lunch)])
        let assignment = plan.assignments.first!
        context.delete(assignment)
        try context.save()

        let plans = try context.fetch(FetchDescriptor<DailyMealPlan>())
        XCTAssertEqual(plans.count, 1, "DailyMealPlan muss erhalten bleiben")
        XCTAssertTrue(plans.first!.assignments.isEmpty)
    }

    // MARK: - 3. Ernährungstagebuch-Schutz

    func testSwapDoesNotTouchMealEntries() throws {
        let diaryDate = Calendar.current.startOfDay(for: Date())
        let entry = try makeMealEntry(date: diaryDate)
        let originalItems = entry.items.count

        // Plan für denselben Tag austauschen
        let plan = try makePlan(date: diaryDate, assignments: [("recipe_a", .lunch)])
        plan.assignments.first!.recipeID = "recipe_b"
        plan.isManuallyAdjusted = true
        try context.save()

        let savedEntries = try context.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(savedEntries.count, 1, "Kein MealEntry darf durch Austausch gelöscht werden")
        XCTAssertEqual(savedEntries.first!.items.count, originalItems, "Keine MealItems dürfen verändert werden")
    }

    func testRemoveDoesNotTouchMealEntries() throws {
        let diaryDate = Calendar.current.startOfDay(for: Date())
        let entry = try makeMealEntry(date: diaryDate)

        let plan = try makePlan(date: diaryDate, assignments: [("recipe_a", .lunch)])
        let toRemove = plan.assignments.first!
        plan.isManuallyAdjusted = true
        context.delete(toRemove)
        try context.save()

        let savedEntries = try context.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(savedEntries.count, 1, "MealEntry muss nach Entfernen erhalten bleiben")
        let savedItems = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(savedItems.count, 1, "MealItem muss nach Entfernen erhalten bleiben")
    }

    func testSnapshotNutrientsUnchangedAfterPlanEdit() throws {
        let nutrients = NutrientValues(kcal: .known(330), proteinG: .known(62), carbsG: .known(1), fatG: .known(4))
        let entry = MealEntry(date: Date(), mealType: .dinner)
        context.insert(entry)
        let item = MealItem(catalogID: "chicken", nameSnapshot: "Hähnchenbrust", quantity: 200, unit: .gram, nutrients: nutrients, meal: entry)
        context.insert(item)
        try context.save()

        // Plan-Änderung
        let plan = try makePlan(assignments: [("recipe_a", .lunch)])
        plan.assignments.first!.recipeID = "recipe_b"
        plan.isManuallyAdjusted = true
        try context.save()

        let savedItem = try context.fetch(FetchDescriptor<MealItem>()).first!
        XCTAssertEqual(savedItem.nutrientsSnapshot.kcal, .known(330), "Snapshot-Nährwerte müssen unverändert bleiben")
        XCTAssertEqual(savedItem.nutrientsSnapshot.proteinG, .known(62))
    }

    // MARK: - 4. Mehrere Mahlzeiten desselben Tages

    func testMultipleAssignmentsSameDay() throws {
        let plan = try makePlan(assignments: [
            ("r_breakfast", .breakfast),
            ("r_lunch", .lunch),
            ("r_dinner", .dinner)
        ])

        // Nur Mittagessen austauschen
        let lunch = plan.assignments.first { $0.mealType == .lunch }!
        lunch.recipeID = "r_lunch_new"
        plan.isManuallyAdjusted = true
        try context.save()

        let assignments = try context.fetch(FetchDescriptor<PlannedMealAssignment>())
        XCTAssertEqual(assignments.count, 3)

        let breakfastID = assignments.first { $0.mealType == .breakfast }?.recipeID
        let dinnerID = assignments.first { $0.mealType == .dinner }?.recipeID
        let lunchID = assignments.first { $0.mealType == .lunch }?.recipeID

        XCTAssertEqual(breakfastID, "r_breakfast", "Frühstück unverändert")
        XCTAssertEqual(dinnerID, "r_dinner", "Abendessen unverändert")
        XCTAssertEqual(lunchID, "r_lunch_new", "Mittagessen ausgetauscht")
    }

}
// eligibleRecipes-Filterfälle (Allergene, DietaryStyle, ExcludedIDs) sind in
// FitnessAppCoreTests/MealPlanGeneratorTests.swift abgedeckt (Tests 10–12 der Spec).
#endif
