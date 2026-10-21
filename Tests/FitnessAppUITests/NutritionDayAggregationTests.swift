#if canImport(SwiftData)
import XCTest
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
final class NutritionDayAggregationTests: XCTestCase {
    func testGroupsByMealType() {
        let breakfast = MealEntry(date: Date(), mealType: .breakfast)
        let lunch1 = MealEntry(date: Date(), mealType: .lunch)
        let lunch2 = MealEntry(date: Date(), mealType: .lunch)
        let grouped = NutritionDayAggregator.grouped(meals: [breakfast, lunch1, lunch2])
        XCTAssertEqual(grouped[.lunch]?.count, 2)
        XCTAssertEqual(grouped[.breakfast]?.count, 1)
    }

    func testDailyTotalSumsAllItemsAcrossMeals() {
        let meal1 = MealEntry(date: Date(), mealType: .breakfast)
        _ = MealItem(catalogID: nil, nameSnapshot: "A", quantity: 1, unit: .gram,
                     nutrients: NutrientValues(kcal: 100, proteinG: 1, carbsG: 1, fatG: 1), meal: meal1)
        let meal2 = MealEntry(date: Date(), mealType: .dinner)
        _ = MealItem(catalogID: nil, nameSnapshot: "B", quantity: 1, unit: .gram,
                     nutrients: NutrientValues(kcal: 50, proteinG: 1, carbsG: 1, fatG: 1), meal: meal2)
        let total = NutritionDayAggregator.dailyTotal(meals: [meal1, meal2])
        XCTAssertEqual(total.kcal, 150)
    }

    func testEmptyDayReturnsZeroTotal() {
        XCTAssertEqual(NutritionDayAggregator.dailyTotal(meals: []), .zero)
    }
}
#endif
