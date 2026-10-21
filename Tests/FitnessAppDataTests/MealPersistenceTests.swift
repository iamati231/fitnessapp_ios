#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealPersistenceTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    override func tearDownWithError() throws { container = nil }
    private var context: ModelContext { container.mainContext }

    func testMultipleMealsOfSameTypeSameDayAreAllowed() throws {
        let day = Date()
        context.insert(MealEntry(date: day, mealType: .snack))
        context.insert(MealEntry(date: day, mealType: .snack))
        try context.save()
        let count = try context.fetchCount(FetchDescriptor<MealEntry>())
        XCTAssertEqual(count, 2)
    }

    func testDeletingMealCascadesToItems() throws {
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        let item = MealItem(catalogID: "x", nameSnapshot: "Testfood", quantity: 100, unit: .gram,
                             nutrients: NutrientValues(kcal: 100, proteinG: 1, carbsG: 1, fatG: 1), meal: meal)
        context.insert(item)
        try context.save()
        context.delete(meal)
        try context.save()
        let remaining = try context.fetchCount(FetchDescriptor<MealItem>())
        XCTAssertEqual(remaining, 0)
    }

    func testSnapshotSurvivesCatalogEntryMutation() throws {
        let entry = FoodCatalogEntry(from: FoodCatalogData.all[0])
        context.insert(entry)
        try context.save()

        let nutrients = NutritionCalculations.nutrients(for: entry.asCatalogItem, quantity: 150, unit: .gram)!
        let meal = MealEntry(date: Date(), mealType: .breakfast)
        context.insert(meal)
        let item = MealItem(catalogID: entry.catalogID, nameSnapshot: "Snapshot-Name",
                             quantity: 150, unit: .gram, nutrients: nutrients, meal: meal)
        context.insert(item)
        try context.save()

        // Katalogeintrag aendert sich NACH dem Speichern.
        entry.kcalPer100g = 9999
        try context.save()

        XCTAssertEqual(item.nutrientsSnapshot.kcal, nutrients.kcal, "Snapshot darf sich nicht rueckwirkend aendern")
    }
}
#endif
