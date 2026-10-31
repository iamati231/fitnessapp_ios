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

    /// UX-Katalog-Erweiterung: Ziel war ein Katalog von mindestens ~200
    /// Eintraegen (Spec 3). Dokumentiert zugleich die tatsaechlich erreichte
    /// Anzahl — 234 (130 Bestand + 104 neue, qualitativ gepruefte Eintraege).
    func testCatalogReachesExpandedTargetOfAtLeast200Items() {
        XCTAssertGreaterThanOrEqual(FoodCatalogData.all.count, 200)
    }

    func testNoNutrientIsNegative() {
        for item in FoodCatalogData.all {
            XCTAssertGreaterThanOrEqual(item.kcalPer100g.value ?? 0, 0, "\(item.id): kcal darf nicht negativ sein")
            XCTAssertGreaterThanOrEqual(item.proteinPer100g.value ?? 0, 0, "\(item.id): Protein darf nicht negativ sein")
            XCTAssertGreaterThanOrEqual(item.carbsPer100g.value ?? 0, 0, "\(item.id): Kohlenhydrate duerfen nicht negativ sein")
            XCTAssertGreaterThanOrEqual(item.fatPer100g.value ?? 0, 0, "\(item.id): Fett darf nicht negativ sein")
        }
    }

    /// Jede `FoodCategory` aus Spec 3.1 sollte nach der Erweiterung mindestens
    /// einen lokalen Katalogeintrag haben — sonst waere ein Kategorie-Chip in
    /// der UI dauerhaft leer.
    func testEveryCategoryHasAtLeastOneCatalogItem() {
        let coveredCategories = Set(FoodCatalogData.all.map(\.category))
        for category in FoodCategory.allCases {
            XCTAssertTrue(coveredCategories.contains(category), "Kategorie \(category) hat keinen Katalogeintrag")
        }
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
