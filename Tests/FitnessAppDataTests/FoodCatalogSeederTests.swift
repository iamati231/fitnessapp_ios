#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class FoodCatalogSeederTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    override func tearDownWithError() throws { container = nil }
    private var context: ModelContext { container.mainContext }

    func testSeedsAllCatalogItemsOnce() throws {
        let seeded = FoodCatalogSeeder.seedIfNeeded(in: context)
        XCTAssertTrue(seeded)
        let count = try context.fetchCount(FetchDescriptor<FoodCatalogEntry>())
        XCTAssertEqual(count, FoodCatalogData.all.count)
    }

    func testIsIdempotent() throws {
        FoodCatalogSeeder.seedIfNeeded(in: context)
        let secondCall = FoodCatalogSeeder.seedIfNeeded(in: context)
        XCTAssertFalse(secondCall)
        let count = try context.fetchCount(FetchDescriptor<FoodCatalogEntry>())
        XCTAssertEqual(count, FoodCatalogData.all.count, "Zweiter Aufruf darf keine Duplikate einfuegen")
    }
}
#endif
