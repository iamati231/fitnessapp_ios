#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealDraftEditTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private var context: ModelContext { container.mainContext }

    func testEditingReplacesItemsWithoutCreatingSecondMeal() throws {
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Alt", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let draft = MealDraft(editing: meal)
        draft.items.removeAll()
        draft.addItem(catalogID: nil, nameSnapshot: "Neu", quantity: 200, unit: .gram, nutrients: .zero)
        let result = draft.save(into: context)

        if case .failure(let error) = result { XCTFail("\(error)") }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 1, "Edit darf keine zweite MealEntry anlegen")
        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.map(\.nameSnapshot), ["Neu"])
    }

    func testCancelingEditLeavesOriginalUntouched() throws {
        let meal = MealEntry(date: Date(), mealType: .dinner)
        context.insert(meal)
        context.insert(MealItem(catalogID: nil, nameSnapshot: "Original", quantity: 100, unit: .gram, nutrients: .zero, meal: meal))
        try context.save()

        let draft = MealDraft(editing: meal)
        draft.addItem(catalogID: nil, nameSnapshot: "Wird verworfen", quantity: 1, unit: .gram, nutrients: .zero)
        // Kein draft.save() — Abbrechen heisst: Entwurf wird einfach nicht gespeichert.

        let items = try context.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.map(\.nameSnapshot), ["Original"], "Unveraenderte Originaldaten trotz Entwurfs-Aenderung")
    }
}
#endif
