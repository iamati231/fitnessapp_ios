#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MealDraftTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private var context: ModelContext { container.mainContext }

    func testPreviewSumsAllDraftItems() {
        let draft = MealDraft(date: Date(), mealType: .lunch)
        draft.addItem(catalogID: "a", nameSnapshot: "A", quantity: 100, unit: .gram,
                      nutrients: NutrientValues(kcal: 100, proteinG: 10, carbsG: 5, fatG: 2))
        draft.addItem(catalogID: "b", nameSnapshot: "B", quantity: 50, unit: .gram,
                      nutrients: NutrientValues(kcal: 50, proteinG: 2, carbsG: 8, fatG: 1))
        XCTAssertEqual(draft.totalPreview.kcal, 150)
    }

    func testPreviewDoesNotPersistAnything() throws {
        // Spec: "Vorschau erzeugt keine gespeicherte Mahlzeit" — solange
        // save() nicht aufgerufen wird, darf im Context rein gar nichts landen.
        let draft = MealDraft(date: Date(), mealType: .snack)
        draft.addItem(catalogID: nil, nameSnapshot: "X", quantity: 1, unit: .piece, nutrients: .zero)
        XCTAssertEqual(draft.items.count, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 0)
    }

    func testSecondSaveCallIsNoOpAfterFirstSucceeds() throws {
        // Doppeltap-Schutz: zwei aufeinanderfolgende save()-Aufrufe (wie bei
        // zwei schnellen Taps, bevor die UI den Button deaktivieren konnte)
        // duerfen nur EINE MealEntry anlegen.
        let draft = MealDraft(date: Date(), mealType: .dinner)
        draft.addItem(catalogID: nil, nameSnapshot: "X", quantity: 1, unit: .piece, nutrients: .zero)

        _ = draft.save(into: context)
        _ = draft.save(into: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 1)
    }

    func testSaveFailurePreservesDraftAndReportsFailure() throws {
        struct Boom: Error {}
        let draft = MealDraft(date: Date(), mealType: .breakfast)
        draft.addItem(catalogID: nil, nameSnapshot: "X", quantity: 1, unit: .gram, nutrients: .zero)
        let itemCountBefore = draft.items.count

        let result = draft.save(into: context) { _ in throw Boom() }

        switch result {
        case .success: XCTFail("Erwartet: Fehler")
        case .failure: break
        }
        XCTAssertEqual(draft.items.count, itemCountBefore, "Entwurf bleibt nach Fehler erhalten")
        XCTAssertFalse(draft.didSaveSuccessfully)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 0, "Fehlgeschlagener Save darf keine Spur hinterlassen")
    }

    // Final-review fix (important): eine 0-kcal-Mahlzeit ohne Positionen
    // darf nie persistiert werden.
    func testSaveWithNoItemsIsNoOp() throws {
        let draft = MealDraft(date: Date(), mealType: .lunch)

        let result = draft.save(into: context)

        switch result {
        case .success: XCTFail("Erwartet: Fehler bei leerem Entwurf")
        case .failure(let error):
            XCTAssertEqual(error as? MealDraftError, .noItems)
        }
        XCTAssertFalse(draft.didSaveSuccessfully)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 0)
    }
}
#endif
