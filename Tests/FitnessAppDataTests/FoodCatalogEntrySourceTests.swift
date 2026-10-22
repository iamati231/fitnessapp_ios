#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Online-Food-Lookup SDD, Task 2: Herkunfts-Markierung (`FoodCatalogEntrySource`)
/// und Klartext-Namen (`displayName`) auf `FoodCatalogEntry`, plus deren
/// Auswirkung auf `UserDataWipe`/`DataExportService`/`DataImportService`.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class FoodCatalogEntrySourceTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    override func tearDownWithError() throws { container = nil }
    private var context: ModelContext { container.mainContext }

    // MARK: - Step 1

    func testUserCreatedEntry_hasDisplayNameAndCorrectSource() {
        let entry = FoodCatalogEntry(displayName: "Linsensuppe", source: .userCreated, category: .other,
                                      kcalPer100g: 90, proteinPer100g: 5, carbsPer100g: 12, fatPer100g: 2)
        XCTAssertEqual(entry.source, .userCreated)
        XCTAssertEqual(entry.displayName, "Linsensuppe")
    }

    func testOnlineImportedEntry_hasCorrectSource() {
        let entry = FoodCatalogEntry(displayName: "Nutella", source: .onlineImported, category: .other,
                                      kcalPer100g: 539, proteinPer100g: 6.3, carbsPer100g: 57.5, fatPer100g: 30.9)
        XCTAssertEqual(entry.source, .onlineImported)
    }

    func testExistingSeededEntries_defaultToSeededSource() throws {
        // Ein ueber init(from: FoodCatalogItem) angelegter Eintrag (bestehender
        // Pfad, repraesentiert auch bereits migrierte/bestehende Zeilen) hat
        // source == .seeded.
        let entry = FoodCatalogEntry(from: FoodCatalogData.all.first!)
        XCTAssertEqual(entry.source, .seeded)
    }

    /// Belegt, dass das additive SwiftData-Feld fuer TATSAECHLICH PERSISTIERTE
    /// Zeilen den Default `.seeded` bekommt — nicht nur fuer frisch im Speicher
    /// konstruierte Objekte (die obigen Tests pruefen nur den Init-Defaultwert
    /// in-memory, nicht das SwiftData-Storage-Verhalten). `FoodCatalogSeeder`
    /// seedet ueber exakt `init(from:)`, dann wird gespeichert, der Context
    /// geleert (neuer Container/Fetch) und erneut gelesen.
    func testSeededRowsPersistAndReloadWithSeededSource() throws {
        _ = FoodCatalogSeeder.seedIfNeeded(in: context)
        try context.save()
        let reloaded = try context.fetch(FetchDescriptor<FoodCatalogEntry>())
        XCTAssertFalse(reloaded.isEmpty)
        XCTAssertTrue(reloaded.allSatisfy { $0.source == .seeded })
        XCTAssertTrue(reloaded.allSatisfy { $0.displayName == nil })
    }

    // MARK: - Step 4: Wipe-Regression

    func testDeleteSharedUserData_removesOnlyNonSeededFoodCatalogEntries() throws {
        let seeded = FoodCatalogEntry(from: FoodCatalogData.all.first!)
        context.insert(seeded)
        let online = FoodCatalogEntry(displayName: "Nutella", source: .onlineImported, category: .other,
                                       kcalPer100g: 539, proteinPer100g: 6.3, carbsPer100g: 57.5, fatPer100g: 30.9)
        context.insert(online)
        let manual = FoodCatalogEntry(displayName: "Linsensuppe", source: .userCreated, category: .other,
                                       kcalPer100g: 90, proteinPer100g: 5, carbsPer100g: 12, fatPer100g: 2)
        context.insert(manual)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogEntry>()), 3)

        try UserDataWipe.deleteSharedUserData(in: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<FoodCatalogEntry>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.source, .seeded)
    }

    // MARK: - Step 4: Export/Import-Regression

    func testExportImportRoundtrip_restoresOnlineAndUserCreatedEntriesWithSource() async throws {
        let seeded = FoodCatalogEntry(from: FoodCatalogData.all.first!)
        context.insert(seeded)
        let online = FoodCatalogEntry(displayName: "Nutella", source: .onlineImported, category: .other,
                                       kcalPer100g: 539, proteinPer100g: 6.3, carbsPer100g: 57.5, fatPer100g: 30.9)
        context.insert(online)
        let manual = FoodCatalogEntry(displayName: "Linsensuppe", source: .userCreated, category: .other,
                                       kcalPer100g: 90, proteinPer100g: 5, carbsPer100g: 12, fatPer100g: 2,
                                       pieceWeightGrams: 250)
        context.insert(manual)
        try context.save()

        let bundle = try DataExportService.makeExport(context: context)

        let targetSchema = Schema(AppSchema.types)
        let targetContainer = try ModelContainer(for: targetSchema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let targetContext = targetContainer.mainContext
        let result = try await DataImportService.performImport(
            zipData: bundle.data,
            context: targetContext,
            strategy: .appendOnly
        )
        XCTAssertEqual(result.errorRows, 0)

        // Frischer Container hat keine geseedeten Zeilen (Seeder laeuft nicht
        // automatisch) — nur die beiden nicht-seedierten Zeilen aus dem Import.
        let imported = try targetContext.fetch(FetchDescriptor<FoodCatalogEntry>())
        XCTAssertEqual(imported.count, 2)
        let importedOnline = imported.first { $0.displayName == "Nutella" }
        XCTAssertEqual(importedOnline?.source, .onlineImported)
        XCTAssertEqual(importedOnline?.catalogID, online.catalogID, "stabile catalog_id muss den Roundtrip ueberleben")
        let importedManual = imported.first { $0.displayName == "Linsensuppe" }
        XCTAssertEqual(importedManual?.source, .userCreated)
        XCTAssertEqual(importedManual?.pieceWeightGrams, 250)
        XCTAssertEqual(importedManual?.catalogID, manual.catalogID)
    }
}
#endif
