#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

/// Online-Food-Lookup SDD, Task 6: manuelles Anlegen eines eigenen
/// Lebensmittels in `AddMealView` — UNABHAENGIG von Netz/KI. Wie
/// `OnlineFoodLookupFlowTests` fuer Task 4/5 testet dies `CustomFoodDraft`
/// (die extrahierte, testbare Persistenz-/Validierungslogik hinter
/// `CustomFoodEntrySheet`) direkt, da dieses Package kein ViewInspector/
/// XCUITest-Harness hat.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CustomFoodEntryTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    override func tearDownWithError() throws { container = nil }
    private var context: ModelContext { container.mainContext }

    // MARK: - Alle Pflichtfelder gueltig -> Speichern erzeugt genau einen userCreated-Eintrag

    func testValidFormSavesUserCreatedEntryWithEnteredMacros() throws {
        let draft = CustomFoodDraft(name: "Linsensuppe")
        draft.kcalPer100g = 90
        draft.proteinPer100g = 5
        draft.carbsPer100g = 12
        draft.fatPer100g = 2
        XCTAssertTrue(draft.isValid)

        let result = draft.save(into: context)
        switch result {
        case .success(let entry):
            XCTAssertEqual(entry.source, .userCreated)
            XCTAssertEqual(entry.displayName, "Linsensuppe")
            XCTAssertEqual(entry.kcalPer100g, 90)
            XCTAssertEqual(entry.proteinPer100g, 5)
            XCTAssertEqual(entry.carbsPer100g, 12)
            XCTAssertEqual(entry.fatPer100g, 2)
        case .failure(let error):
            XCTFail("unerwarteter Fehler: \(error)")
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogEntry>()), 1)
    }

    // MARK: - Pflichtfeld fehlt/ungueltig -> isValid false (spiegelt den deaktivierten Speichern-Button)

    func testMissingNameIsInvalid() {
        let draft = CustomFoodDraft(name: "   ")
        draft.kcalPer100g = 90
        draft.proteinPer100g = 5
        draft.carbsPer100g = 12
        draft.fatPer100g = 2
        XCTAssertFalse(draft.isValid)
    }

    func testMissingMacroIsInvalid() {
        let draft = CustomFoodDraft(name: "Linsensuppe")
        draft.kcalPer100g = 90
        draft.proteinPer100g = 5
        draft.carbsPer100g = 12
        // fatPer100g bleibt nil
        XCTAssertFalse(draft.isValid)
    }

    func testNegativeMacroIsInvalid() {
        let draft = CustomFoodDraft(name: "Linsensuppe")
        draft.kcalPer100g = 90
        draft.proteinPer100g = -1
        draft.carbsPer100g = 12
        draft.fatPer100g = 2
        XCTAssertFalse(draft.isValid)
    }

    func testSaveWithInvalidInputFailsAndCreatesNothing() throws {
        let draft = CustomFoodDraft(name: "")
        let result = draft.save(into: context)
        switch result {
        case .success:
            XCTFail("ungueltiger Entwurf darf nicht speichern")
        case .failure(let error):
            XCTAssertEqual(error as? CustomFoodDraftError, .invalidInput)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogEntry>()), 0)
    }

    // MARK: - Doppeltipp auf Speichern -> GENAU EIN Eintrag

    func testDoubleSaveCreatesExactlyOneEntry() throws {
        let draft = CustomFoodDraft(name: "Linsensuppe")
        draft.kcalPer100g = 90
        draft.proteinPer100g = 5
        draft.carbsPer100g = 12
        draft.fatPer100g = 2

        draft.save(into: context)
        // Zweiter Aufruf (simuliert Doppeltipp, bevor ein UI-`.disabled` je
        // greifen koennte) ist dank `didSaveSuccessfully` ein Context-freies
        // No-Op, das denselben bereits gespeicherten Eintrag zurueckgibt.
        let secondResult = draft.save(into: context)
        switch secondResult {
        case .success(let entry):
            XCTAssertEqual(entry.displayName, "Linsensuppe")
        case .failure(let error):
            XCTFail("unerwarteter Fehler beim zweiten Aufruf: \(error)")
        }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogEntry>()), 1)
    }

    // MARK: - Speicherfehler -> Entwurf bleibt erhalten, kein Erfolgs-Feedback

    func testSaveFailurePreservesDraftAndRollsBackInsertedEntry() throws {
        let draft = CustomFoodDraft(name: "Linsensuppe")
        draft.kcalPer100g = 90
        draft.proteinPer100g = 5
        draft.carbsPer100g = 12
        draft.fatPer100g = 2

        struct Boom: Error {}
        let result = draft.save(into: context, persist: { _ in throw Boom() })

        switch result {
        case .success:
            XCTFail("persist() schlug fehl — save() darf keinen Erfolg melden")
        case .failure:
            break
        }
        XCTAssertFalse(draft.didSaveSuccessfully)
        // Entwurf (Name/Makros) bleibt fuer einen erneuten Versuch unveraendert.
        XCTAssertEqual(draft.name, "Linsensuppe")
        XCTAssertEqual(draft.kcalPer100g, 90)
        // Der frisch eingefuegte, nie persistierte Eintrag wurde zurueckgebaut.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogEntry>()), 0)

        // Ein erneuter Versuch mit funktionierendem `persist` gelingt danach.
        let retryResult = draft.save(into: context)
        switch retryResult {
        case .success: break
        case .failure(let error): XCTFail("Retry haette gelingen muessen: \(error)")
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogEntry>()), 1)
    }

    // MARK: - Ohne Stueckgewicht/Dichte -> nur Gramm, nie Stueck/ml

    func testWithoutPieceWeightOrDensityOnlyGramIsSupported() throws {
        let draft = CustomFoodDraft(name: "Linsensuppe")
        draft.kcalPer100g = 90
        draft.proteinPer100g = 5
        draft.carbsPer100g = 12
        draft.fatPer100g = 2
        // pieceWeightGrams/densityGramsPerMl bewusst nicht gesetzt.

        let entry = try XCTUnwrap(draft.save(into: context).get())
        let item = entry.asCatalogItem
        XCTAssertTrue(item.supports(.gram))
        XCTAssertFalse(item.supports(.piece), "ohne Stueckgewicht darf die Mengenauswahl KEIN Stueck anbieten")
        XCTAssertFalse(item.supports(.milliliter), "ohne Dichte darf die Mengenauswahl KEIN ml anbieten")
    }

    func testWithPieceWeightAndDensityBothUnitsAreSupported() throws {
        let draft = CustomFoodDraft(name: "Olivenoel")
        draft.kcalPer100g = 884
        draft.proteinPer100g = 0
        draft.carbsPer100g = 0
        draft.fatPer100g = 100
        draft.pieceWeightGrams = 5
        draft.densityGramsPerMl = 0.92

        let entry = try XCTUnwrap(draft.save(into: context).get())
        let item = entry.asCatalogItem
        XCTAssertTrue(item.supports(.piece))
        XCTAssertTrue(item.supports(.milliliter))
    }

    // MARK: - Kaltstart-Persistenz: nach Neuerstellen des ModelContainer weiterhin per Katalogsuche auffindbar

    func testEntrySurvivesColdRestartAndIsFindableBySearch() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("custom-food-entry-cold-start-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let firstContainer = try ModelContainer(
                for: Schema(AppSchema.types),
                configurations: ModelConfiguration(url: storeURL)
            )
            let draft = CustomFoodDraft(name: "Linsensuppe")
            draft.kcalPer100g = 90
            draft.proteinPer100g = 5
            draft.carbsPer100g = 12
            draft.fatPer100g = 2
            let result = draft.save(into: firstContainer.mainContext)
            switch result {
            case .success: break
            case .failure(let error): XCTFail("unerwarteter Fehler: \(error)")
            }
        }

        // Echter Kaltstart: komplett NEUER ModelContainer gegen dieselbe
        // Store-Datei (kein In-Memory-Hin-und-Her, keine geteilte Context-
        // Instanz aus dem Schreibschritt oben).
        let secondContainer = try ModelContainer(
            for: Schema(AppSchema.types),
            configurations: ModelConfiguration(url: storeURL)
        )
        let reloadedEntries = try secondContainer.mainContext.fetch(FetchDescriptor<FoodCatalogEntry>())
        XCTAssertEqual(reloadedEntries.count, 1)

        // Simuliert `AddMealView.filteredEntries`'s Live-Filter ueber den
        // aufgeloesten Namen — fuer einen manuell angelegten Eintrag ist das
        // `displayName` (siehe `AddMealView.resolvedName(for:)`, hat Vorrang
        // vor `nameKey`).
        let searchText = "Linsen"
        let found = reloadedEntries.filter {
            ($0.displayName ?? "").localizedCaseInsensitiveContains(searchText)
        }
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.source, .userCreated)
    }
}
#endif
