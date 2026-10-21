#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class NutritionDayAggregationTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private var context: ModelContext { container.mainContext }

    func testGroupsByMealType() {
        let breakfast = MealEntry(date: Date(), mealType: .breakfast)
        let lunch1 = MealEntry(date: Date(), mealType: .lunch)
        let lunch2 = MealEntry(date: Date(), mealType: .lunch)
        let grouped = NutritionDayAggregator.grouped(meals: [breakfast, lunch1, lunch2])
        XCTAssertEqual(grouped[.lunch]?.count, 2)
        XCTAssertEqual(grouped[.breakfast]?.count, 1)
    }

    // Final-review fix (important): vorher wurden MealEntry/MealItem nie in
    // einen ModelContext eingefuegt — die Summierung verliess sich darauf,
    // dass @Relationship(inverse:) rein im Speicher auf un-inserteten
    // Objekten synct. Dafuer gibt es anderswo in diesem Repo keinen
    // Praezedenzfall (jeder andere Relationship-Test inserted beide Seiten
    // zuerst in einen Context) — kein Verhaltensunterschied in Produktion,
    // da `MealDraft.save` immer vor `NutritionDayAggregator.dailyTotal`
    // (via @Query) in einen Context insertet.
    func testDailyTotalSumsAllItemsAcrossMeals() throws {
        let meal1 = MealEntry(date: Date(), mealType: .breakfast)
        context.insert(meal1)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "A", quantity: 1, unit: .gram,
                     nutrients: NutrientValues(kcal: 100, proteinG: 1, carbsG: 1, fatG: 1), meal: meal1))
        let meal2 = MealEntry(date: Date(), mealType: .dinner)
        context.insert(meal2)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "B", quantity: 1, unit: .gram,
                     nutrients: NutrientValues(kcal: 50, proteinG: 1, carbsG: 1, fatG: 1), meal: meal2))
        try context.save()

        let total = NutritionDayAggregator.dailyTotal(meals: [meal1, meal2])
        XCTAssertEqual(total.kcal, 150)
    }

    func testEmptyDayReturnsZeroTotal() {
        XCTAssertEqual(NutritionDayAggregator.dailyTotal(meals: []), .zero)
    }
}
#endif
