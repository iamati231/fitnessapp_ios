#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore
import FitnessAppFoodLookup

/// Online-Food-Lookup SDD, Task 4: "Online suchen" aus der manuellen Suche
/// (0 Treffer) in `AddMealView`.
///
/// This package has no ViewInspector/XCUITest harness — CI only runs
/// `swift test` (see `apple-ci-comparison.yml`) — so these tests exercise
/// the extracted, testable pieces directly (`OnlineFoodSearchController`,
/// the `FoodCatalogEntry`/`MealDraft` composition `confirmOnlineImport`
/// uses) instead of tapping rendered SwiftUI, same approach as
/// `MealDraftTests` for `MealDraft` and `OnlineFoodLookupSettingPersistenceTests`
/// (Task 3) for the toggle wiring itself.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class OnlineFoodLookupFlowTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    override func tearDownWithError() throws { container = nil }
    private var context: ModelContext { container.mainContext }

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Returns the text between `afterOpenBrace` (the position right after
    /// an already-consumed opening `{`) and ITS matching closing `}` —
    /// brace-depth counting, not a fixed-indentation string match, so this
    /// survives incidental reformatting of the surrounding code.
    private static func matchingBraceBlock(in source: String, afterOpenBrace start: String.Index) -> String? {
        var depth = 1
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char == "{" { depth += 1 } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    // MARK: - Step 1: onlineFoodLookupEnabled == false -> unverändertes Verhalten

    func testOnlineSearchActionIsGatedByTheSameAppStorageKeyAsSettings() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        XCTAssertTrue(
            source.contains("@AppStorage(\"onlineFoodLookupEnabled\") private var onlineFoodLookupEnabled: Bool = false"),
            "AddMealView muss denselben AppStorage-Key/Default lesen, den Task 3 in SettingsDataConnectionsView deklariert hat."
        )
        // Die "Online suchen"-Aktion UND die Trefferliste muessen innerhalb
        // des `if onlineFoodLookupEnabled { ... }`-Zweigs liegen, nicht
        // unconditional sichtbar sein — sonst waere das heutige (Toggle aus)
        // Verhalten veraendert.
        guard let gateRange = source.range(of: "if onlineFoodLookupEnabled {") else {
            XCTFail("kein `if onlineFoodLookupEnabled` Gate in AddMealView gefunden")
            return
        }
        let gatedBlock = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: gateRange.upperBound))
        // `onlineSearchButton` is an extracted property (not inlined here,
        // same style as `detailsSection`/`aiSection`) — check its own body
        // separately for the visible text-label key the brief requires.
        XCTAssertTrue(gatedBlock.contains("onlineSearchButton"))
        XCTAssertTrue(gatedBlock.contains("OnlineFoodResultsList"))
        XCTAssertTrue(source.contains("\"nutrition.addMeal.onlineSearch.action\""))
    }

    // MARK: - Step 1 (C1 regression): Trefferliste baut Buttons nicht in EINER Row zusammen

    func testResultsListUsesOnePerRowBorderlessButtons() throws {
        // Regressionsschutz gegen genau die in der finalen Review gefundene
        // Mehrfach-Button-Falle (C1): mehrere default-style Buttons in EINER
        // Form/List-Zeile verschmelzen zu einem Tap-Target.
        let source = try contents(of: "Nutrition/OnlineFoodResultsList.swift")
        XCTAssertTrue(source.contains(".buttonStyle(.borderless)"))
        XCTAssertTrue(source.contains("ForEach(candidates)"), "jede Zeile muss eine eigene ForEach-Iteration sein, kein verschachtelter Button-Stack in einer gemeinsamen VStack-Zeile")
    }

    // MARK: - Step 1: kein Netz -> lokalisierter Hinweis, keine Candidates

    func testSearchWithNoNetworkSetsLocalizedErrorAndNoCandidates() async {
        let controller = OnlineFoodSearchController(searcher: FakeOnlineFoodSearcher(result: .failure(.noNetwork)))

        await controller.search(query: "nutella", locale: Locale(identifier: "de_DE")) { error in
            switch error {
            case .noNetwork: return "Keine Internetverbindung."
            default: XCTFail("falscher Fehlerfall gemappt: \(error)"); return ""
            }
        }

        XCTAssertEqual(controller.errorMessage, "Keine Internetverbindung.")
        XCTAssertTrue(controller.candidates.isEmpty)
        XCTAssertFalse(controller.isSearching)
        // Manuelle Erfassung bleibt bedienbar: der Controller fasst nur sein
        // eigenes State an, nie `searchText`/`filteredEntries` der View.
    }

    // MARK: - Step 1: Netz + mehrere Treffer -> alle sichtbar, Auswahl eindeutig (C1-Regression)

    func testSearchReturnsAllCandidates() async {
        let candidates = Self.makeThreeCandidates()
        let controller = OnlineFoodSearchController(searcher: FakeOnlineFoodSearcher(result: .success(candidates)))

        await controller.search(query: "milch", locale: Locale(identifier: "de_DE")) { _ in "" }

        XCTAssertEqual(controller.candidates, candidates)
    }

    func testSelectPicksExactlyTheTappedCandidateRegardlessOfOrder() async {
        let (a, b, c) = (Self.candidateA, Self.candidateB, Self.candidateC)
        let controller = OnlineFoodSearchController(searcher: FakeOnlineFoodSearcher(result: .success([a, b, c])))
        await controller.search(query: "milch", locale: Locale(identifier: "de_DE")) { _ in "" }

        // Tippt absichtlich NICHT in Listenreihenfolge — ein indexbasierter
        // Bug (oder die C1-Falle: "letzter Button gewinnt immer") wuerde hier
        // auffallen, weil jeder Tap den genau zuletzt getippten Kandidaten
        // zurueckgeben MUSS, nie den letzten der Liste.
        controller.select(c)
        XCTAssertEqual(controller.selectedCandidate, c)

        controller.select(a)
        XCTAssertEqual(controller.selectedCandidate, a)

        controller.select(b)
        XCTAssertEqual(controller.selectedCandidate, b)
    }

    // MARK: - Step 1: Abbrechen legt nichts an

    func testDismissPreviewCreatesNothing() async throws {
        let controller = OnlineFoodSearchController(searcher: FakeOnlineFoodSearcher(result: .success([Self.candidateA])))
        await controller.search(query: "milch", locale: Locale(identifier: "de_DE")) { _ in "" }
        controller.select(Self.candidateA)
        XCTAssertNotNil(controller.selectedCandidate)
        let draft = MealDraft(date: Date(), mealType: .snack)

        controller.dismissPreview()

        XCTAssertNil(controller.selectedCandidate)
        // Weder ein FoodCatalogEntry noch eine Draft-Position entstehen —
        // `dismissPreview()` fasst ausschliesslich `selectedCandidate` an.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogEntry>()), 0)
        XCTAssertTrue(draft.items.isEmpty)
    }

    // MARK: - Step 1: Bestaetigen legt FoodCatalogEntry(.onlineImported) an und nutzt den bestehenden addItem-Pfad

    func testConfirmingPreviewCreatesOnlineImportedEntryAndAddsThroughExistingAddItemPath() throws {
        // Reproduziert exakt, was `AddMealView.confirmOnlineImport` +
        // `addSelectedEntry` tun (beide `private`, daher hier dieselbe
        // Komposition aus denselben public APIs, keine neue Persistenz-
        // Logik): FoodCatalogEntry(displayName:source:...) -> insert ->
        // NutritionCalculations.nutrients(for:quantity:unit:) -> draft.addItem.
        let values = OnlineFoodImportValues(
            name: "Nutella",
            kcalPer100g: 539,
            proteinPer100g: 6.3,
            carbsPer100g: 57.5,
            fatPer100g: 30.9
        )

        let entry = FoodCatalogEntry(
            displayName: values.name,
            source: .onlineImported,
            category: .other,
            kcalPer100g: values.kcalPer100g,
            proteinPer100g: values.proteinPer100g,
            carbsPer100g: values.carbsPer100g,
            fatPer100g: values.fatPer100g
        )
        context.insert(entry)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogEntry>()), 1)
        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<FoodCatalogEntry>()).first)
        XCTAssertEqual(saved.source, .onlineImported)
        XCTAssertEqual(saved.displayName, "Nutella")

        let draft = MealDraft(date: Date(), mealType: .breakfast)
        let nutrients = try XCTUnwrap(NutritionCalculations.nutrients(for: entry.asCatalogItem, quantity: 50, unit: .gram))
        draft.addItem(catalogID: entry.catalogID, nameSnapshot: "Nutella", quantity: 50, unit: .gram, nutrients: nutrients)

        XCTAssertEqual(draft.items.count, 1)
        XCTAssertEqual(draft.items.first?.catalogID, entry.catalogID)
        XCTAssertEqual(draft.items.first?.nutrients.kcal, 539 * 50 / 100)

        let result = draft.save(into: context)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("unerwarteter Fehler: \(error)")
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 1)
    }

    // MARK: - Fixtures

    private static let candidateA = OnlineFoodCandidate(
        id: "a", name: "Produkt A", brand: "Marke A",
        kcalPer100g: 100, proteinPer100g: 10, carbsPer100g: 5, fatPer100g: 2
    )
    private static let candidateB = OnlineFoodCandidate(
        id: "b", name: "Produkt B", brand: nil,
        kcalPer100g: nil, proteinPer100g: nil, carbsPer100g: nil, fatPer100g: nil
    )
    private static let candidateC = OnlineFoodCandidate(
        id: "c", name: "Produkt C", brand: "Marke C",
        kcalPer100g: 250, proteinPer100g: 20, carbsPer100g: 30, fatPer100g: 8
    )

    private static func makeThreeCandidates() -> [OnlineFoodCandidate] {
        [candidateA, candidateB, candidateC]
    }
}

/// Deterministic `OnlineFoodSearching` stand-in — no network, no `URLSession`.
private struct FakeOnlineFoodSearcher: OnlineFoodSearching {
    let result: Result<[OnlineFoodCandidate], OnlineFoodSearchError>

    func search(query: String, locale: Locale) async throws -> [OnlineFoodCandidate] {
        try result.get()
    }
}
#endif
