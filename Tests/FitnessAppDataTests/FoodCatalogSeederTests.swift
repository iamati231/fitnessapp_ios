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

    // MARK: - UX-Katalog-Erweiterung: backfillNewCatalogEntriesIfNeeded

    private func seedCatalogMissing(_ missingIDs: Set<String>) {
        for item in FoodCatalogData.all where !missingIDs.contains(item.id) {
            context.insert(FoodCatalogEntry(from: item))
        }
    }

    private func seededCatalogIDs() -> Set<String> {
        let descriptor = FetchDescriptor<FoodCatalogEntry>(predicate: #Predicate { $0.sourceRaw == "seeded" })
        return Set(((try? context.fetch(descriptor)) ?? []).map(\.catalogID))
    }

    func testBackfillAddsEntriesMissingSinceLastSeed() throws {
        seedCatalogMissing(["banana", "oats"])
        XCTAssertFalse(seededCatalogIDs().contains("banana"))

        let added = FoodCatalogSeeder.backfillNewCatalogEntriesIfNeeded(in: context)

        XCTAssertEqual(added, 2)
        XCTAssertEqual(seededCatalogIDs(), Set(FoodCatalogData.all.map(\.id)), "Bestandsnutzer muss nach dem Backfill den vollen aktuellen Katalog haben")
    }

    func testBackfillIsIdempotent() {
        seedCatalogMissing(["banana", "oats"])
        FoodCatalogSeeder.backfillNewCatalogEntriesIfNeeded(in: context)
        let secondPass = FoodCatalogSeeder.backfillNewCatalogEntriesIfNeeded(in: context)

        XCTAssertEqual(secondPass, 0, "zweiter Aufruf darf nichts mehr finden")
        XCTAssertEqual(seededCatalogIDs().count, FoodCatalogData.all.count, "keine Duplikate durch doppelten Backfill")
    }

    func testBackfillIsNoOpRightAfterAFreshSeed() {
        FoodCatalogSeeder.seedIfNeeded(in: context)
        let added = FoodCatalogSeeder.backfillNewCatalogEntriesIfNeeded(in: context)
        XCTAssertEqual(added, 0, "frisch geseedeter Katalog hat schon alle aktuellen Eintraege")
    }

    /// Online-importierte/manuell angelegte Eintraege duerfen den Backfill
    /// nicht beeinflussen — er filtert auf `source == .seeded` und arbeitet
    /// ausschliesslich gegen `FoodCatalogData.all`.
    func testBackfillDoesNotTouchOnlineImportedOrUserCreatedEntries() {
        seedCatalogMissing(["banana"])
        let onlineEntry = FoodCatalogEntry(
            displayName: "Mein Online-Fund", source: .onlineImported, category: .other,
            kcalPer100g: 100, proteinPer100g: 5, carbsPer100g: 10, fatPer100g: 2
        )
        context.insert(onlineEntry)

        _ = FoodCatalogSeeder.backfillNewCatalogEntriesIfNeeded(in: context)

        let onlineDescriptor = FetchDescriptor<FoodCatalogEntry>(predicate: #Predicate { $0.sourceRaw == "onlineImported" })
        let onlineEntries = (try? context.fetch(onlineDescriptor)) ?? []
        XCTAssertEqual(onlineEntries.count, 1)
        XCTAssertEqual(onlineEntries.first?.displayName, "Mein Online-Fund")
        XCTAssertTrue(seededCatalogIDs().contains("banana"), "fehlender Seed-Eintrag muss trotzdem nachgezogen werden")
    }
}
#endif
