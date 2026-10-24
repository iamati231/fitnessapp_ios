#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
@testable import FitnessAppData
@testable import FitnessAppUI

/// writing-block.md Punkt 6 ("Lebensmittelname folgt nicht der aktuellen
/// App-Sprache"): a saved `MealItem`/`MealDraft.Item` freezes its name into
/// `nameSnapshot` at save time — `resolvedMealItemName` re-resolves through
/// the CURRENT `FoodCatalogEntry` (which already picks up locale changes,
/// see `resolvedName(for:)`) whenever one still exists for the stored
/// `catalogID`, instead of showing the frozen text forever.
///
/// These tests deliberately don't assert an actual RESOLVED translation
/// (this session's own CI run already showed `String(localized:bundle:
/// .module)` can return the raw key instead of a translation for certain
/// keys) — using a made-up `nameKey` makes that irrelevant here: the point
/// is only to prove WHICH branch (nameKey vs. frozen snapshot vs.
/// displayName) was taken, not what the localized text ends up being.
@available(iOS 17.0, macOS 14.0, *)
final class FoodCatalogEntryDisplayNameTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    func testCatalogBasedItemResolvesThroughTheCurrentCatalogEntryNotTheFrozenSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let entry = FoodCatalogEntry(from: FoodCatalogItem(
            id: "test_food",
            nameKey: "test.fake.nameKey.notARealTranslation",
            category: .other,
            kcalPer100g: 100,
            proteinPer100g: 1,
            carbsPer100g: 1,
            fatPer100g: 1
        ))
        context.insert(entry)
        try context.save()

        // "Alter Name" stands in for whatever name was frozen at log time,
        // e.g. in German, before the app switched to another language.
        let resolved = resolvedMealItemName(nameSnapshot: "Alter Name", catalogID: "test_food", catalogEntries: [entry])

        XCTAssertNotEqual(resolved, "Alter Name", "ein noch existierender Katalogeintrag muss den Snapshot-Namen ueberschreiben")
        XCTAssertEqual(resolved, "test.fake.nameKey.notARealTranslation", "muss ueber resolvedName(for:)/nameKey aufloesen, nicht den Snapshot zeigen")
    }

    func testUserOrOnlineItemKeepsItsFrozenDisplayNameRegardlessOfLocale() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let entry = FoodCatalogEntry(
            displayName: "Nutella",
            source: .userCreated,
            category: .other,
            kcalPer100g: 539,
            proteinPer100g: 6,
            carbsPer100g: 57,
            fatPer100g: 31
        )
        context.insert(entry)
        try context.save()

        let resolved = resolvedMealItemName(nameSnapshot: "Nutella", catalogID: entry.catalogID, catalogEntries: [entry])

        XCTAssertEqual(resolved, "Nutella", "benutzerdefinierte/online-importierte Namen duerfen nie automatisch uebersetzt werden")
    }

    func testMissingCatalogIDFallsBackToTheFrozenSnapshot() {
        let resolved = resolvedMealItemName(nameSnapshot: "Legacy-Eintrag", catalogID: nil, catalogEntries: [])
        XCTAssertEqual(resolved, "Legacy-Eintrag")
    }

    func testDeletedCatalogEntryFallsBackToTheFrozenSnapshot() {
        // catalogID verweist auf nichts (mehr) Vorhandenes in catalogEntries.
        let resolved = resolvedMealItemName(nameSnapshot: "Geloeschtes Lebensmittel", catalogID: "no_longer_exists", catalogEntries: [])
        XCTAssertEqual(resolved, "Geloeschtes Lebensmittel")
    }
}
#endif
