import XCTest
@testable import FitnessAppCore

final class FoodCatalogDataTests: XCTestCase {
    func testAllIDsAreUnique() {
        let ids = FoodCatalogData.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Doppelte Katalog-IDs")
    }

    func testCatalogHasAtLeast100Items() {
        XCTAssertGreaterThanOrEqual(FoodCatalogData.all.count, 100)
    }

    func testMillilitersRequireExplicitDensity() {
        // Spec 4.2: ml darf NIE pauschal angenommen werden — jeder Eintrag
        // mit densityGramsPerMl muss ihn bewusst gesetzt haben (>0), kein
        // Eintrag darf 0 oder negativ tragen.
        for item in FoodCatalogData.all {
            if let density = item.densityGramsPerMl {
                XCTAssertGreaterThan(density, 0, "\(item.id): densityGramsPerMl muss > 0 sein")
            }
        }
    }

    func testPieceUnitRequiresPositivePieceWeight() {
        for item in FoodCatalogData.all {
            if let pieceWeight = item.pieceWeightGrams {
                XCTAssertGreaterThan(pieceWeight, 0, "\(item.id): pieceWeightGrams muss > 0 sein")
            }
        }
    }
}
