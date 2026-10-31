#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Phase 4.4: Testet die Persistenz-Logik für „Rezept ins Tagebuch übernehmen".
/// Prüft MealEntry/MealItem-Erstellung, OFF-01-Konformität und Snapshot-Invarianz.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class RecipeDiarySaveTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Schema(AppSchema.types),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    // MARK: - Storage

    func testSaveCreatesOneMealEntryWithCorrectDateAndType() throws {
        let date = Calendar.current.startOfDay(for: Date())
        let entry = MealEntry(date: date, mealType: .lunch)
        context.insert(entry)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].mealType, .lunch)
        XCTAssertEqual(entries[0].date, date)
    }

    func testMealItemsAreStoredWithSnapshotNutrients() throws {
        let nutrients = NutrientValues(kcal: .known(330), proteinG: .known(62), carbsG: .known(1), fatG: .known(4))
        let entry = MealEntry(date: Date(), mealType: .dinner)
        context.insert(entry)
        let item = MealItem(catalogID: "chicken", nameSnapshot: "Hähnchenbrust", quantity: 200, unit: .gram, nutrients: nutrients, meal: entry)
        context.insert(item)
        try context.save()

        let saved = try context.fetch(FetchDescriptor<MealItem>()).first!
        XCTAssertEqual(saved.nutrientsSnapshot.kcal, .known(330))
        XCTAssertEqual(saved.nutrientsSnapshot.proteinG, .known(62))
        XCTAssertEqual(saved.nameSnapshot, "Hähnchenbrust")
        XCTAssertEqual(saved.catalogID, "chicken")
    }

    func testMultipleMealItemsStoredForOneEntry() throws {
        let entry = MealEntry(date: Date(), mealType: .lunch)
        context.insert(entry)
        let n1 = NutrientValues(kcal: .known(165), proteinG: .known(31), carbsG: .known(1), fatG: .known(4))
        let n2 = NutrientValues(kcal: .known(130), proteinG: .known(2), carbsG: .known(28), fatG: .known(0.4))
        context.insert(MealItem(catalogID: "chicken", nameSnapshot: "Hähnchen", quantity: 100, unit: .gram, nutrients: n1, meal: entry))
        context.insert(MealItem(catalogID: "rice", nameSnapshot: "Reis", quantity: 100, unit: .gram, nutrients: n2, meal: entry))
        try context.save()

        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.count, 2)
        let entries = try context.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(entries.count, 1)
    }

    // MARK: - OFF-01: Unbekannte Nährwerte bleiben unbekannt

    func testUnknownFatStoredAsUnknownNotZero() throws {
        let nutrients = NutrientValues(kcal: .known(100), proteinG: .known(5), carbsG: .known(10), fatG: .unknown)
        let entry = MealEntry(date: Date(), mealType: .snack)
        context.insert(entry)
        let item = MealItem(catalogID: "item", nameSnapshot: "Test", quantity: 100, unit: .gram, nutrients: nutrients, meal: entry)
        context.insert(item)
        try context.save()

        let saved = try context.fetch(FetchDescriptor<MealItem>()).first!
        XCTAssertEqual(saved.nutrientsSnapshot.fatG, .unknown, "OFF-01: Unknown fat must not be stored as 0")
        XCTAssertEqual(saved.nutrientsSnapshot.kcal, .known(100))
    }

    func testAllUnknownNutrientsStoredCorrectly() throws {
        let nutrients = NutrientValues(kcal: .unknown, proteinG: .unknown, carbsG: .unknown, fatG: .unknown)
        let entry = MealEntry(date: Date(), mealType: .breakfast)
        context.insert(entry)
        let item = MealItem(catalogID: nil, nameSnapshot: "Unbekannt", quantity: 50, unit: .gram, nutrients: nutrients, meal: entry)
        context.insert(item)
        try context.save()

        let saved = try context.fetch(FetchDescriptor<MealItem>()).first!
        XCTAssertEqual(saved.nutrientsSnapshot.kcal, .unknown)
        XCTAssertEqual(saved.nutrientsSnapshot.proteinG, .unknown)
        XCTAssertEqual(saved.nutrientsSnapshot.carbsG, .unknown)
        XCTAssertEqual(saved.nutrientsSnapshot.fatG, .unknown)
    }

    // MARK: - Snapshot-Invarianz: Flaches Feld-Muster

    func testSnapshotIsIndependentOfCatalogID() throws {
        // catalogID ist rein informativ — Nährwert-Snapshot ist unabhängig davon.
        let nutrients = NutrientValues(kcal: .known(165), proteinG: .known(31), carbsG: .known(1), fatG: .known(4))
        let entry = MealEntry(date: Date(), mealType: .lunch)
        context.insert(entry)
        let item = MealItem(catalogID: "chicken_v1", nameSnapshot: "Hähnchenbrust", quantity: 100, unit: .gram, nutrients: nutrients, meal: entry)
        context.insert(item)
        try context.save()

        // Snapshot-Werte stimmen mit dem übergebenen NutrientValues überein.
        let saved = try context.fetch(FetchDescriptor<MealItem>()).first!
        XCTAssertEqual(saved.nutrientsSnapshot.kcal, .known(165), "Snapshot muss zum Zeitpunkt des Speicherns eingefroren sein")
        XCTAssertEqual(saved.nameSnapshot, "Hähnchenbrust")
        // catalogID ist nur informativ — keine @Relationship.
        XCTAssertEqual(saved.catalogID, "chicken_v1")
    }

    // MARK: - Kaskadenlöschung

    func testDeleteEntryAlsoDeletesItsItems() throws {
        let entry = MealEntry(date: Date(), mealType: .lunch)
        context.insert(entry)
        let nutrients = NutrientValues(kcal: .known(200), proteinG: .known(10), carbsG: .known(20), fatG: .known(5))
        context.insert(MealItem(catalogID: "food", nameSnapshot: "Essen", quantity: 100, unit: .gram, nutrients: nutrients, meal: entry))
        try context.save()

        context.delete(entry)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<MealEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MealItem>()).count, 0, "Cascade delete muss Items mitlöschen")
    }
}
#endif
