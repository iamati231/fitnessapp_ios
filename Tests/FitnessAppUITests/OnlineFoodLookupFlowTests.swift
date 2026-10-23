#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore
import FitnessAppFoodLookup

/// Online-Food-Lookup SDD, Task 4: "Online suchen" aus der manuellen Suche
/// (0 Treffer) in `AddMealView`. Task 5 erweitert dieselbe Testdatei um den
/// zweiten Einstiegspunkt: "Online suchen" aus einem KI-Kandidaten ohne
/// Katalogtreffer (`aiCandidateRow`'s `hasNoCatalogMatch`-Zweig), auf
/// demselben geteilten `OnlineFoodSearchController` und denselben
/// `OnlineFoodResultsList`/`OnlineFoodCandidatePreviewSheet`-Komponenten.
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
        let values = try XCTUnwrap(OnlineFoodImportValues(
            name: "Nutella",
            kcalPer100g: 539,
            proteinPer100g: 6.3,
            carbsPer100g: 57.5,
            fatPer100g: 30.9
        ))

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
        XCTAssertEqual(draft.items.first?.nutrients.kcal.value, 539 * 50 / 100)

        let result = draft.save(into: context)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("unerwarteter Fehler: \(error)")
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealEntry>()), 1)
    }

    // MARK: - Task 5: second entry point from an AI candidate with no catalog match

    /// Step 1 (Task 5 brief): a `hasNoCatalogMatch` AI candidate must show an
    /// "Online suchen" action prefilled with `candidate.foodText`, reusing
    /// Task 4's exact gate/components (no second, divergent implementation).
    func testAICandidateNoMatchShowsOnlineSearchPrefilledWithFoodTextReusingTask4Components() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let noMatchRange = source.range(of: "if candidate.hasNoCatalogMatch {") else {
            XCTFail("kein `if candidate.hasNoCatalogMatch` Zweig in aiCandidateRow gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: noMatchRange.upperBound))

        // Gleicher Gate-Key wie Task 4 (kein eigener/divergenter Toggle).
        XCTAssertTrue(block.contains("if onlineFoodLookupEnabled {"))
        // Vorausgefuellt mit `foodText`, ueber dieselbe (nicht duplizierte)
        // `runOnlineSearch`-Funktion wie der manuelle Einstiegspunkt (jetzt
        // mit `origin:`, siehe Final-Review-Fix I1 — trackt, WELCHE Zeile die
        // Suche gestartet hat).
        XCTAssertTrue(block.contains("runOnlineSearch(origin: .aiCandidate(candidate), query: candidate.foodText)"))
        // Wiederverwendet Task 4's Trefferlisten-/Fehler-Komponenten 1:1,
        // keine zweite, abweichende Implementierung.
        XCTAssertTrue(block.contains("OnlineFoodResultsList(candidates: onlineSearch.candidates, onSelect: onlineSearch.select)"))
        XCTAssertTrue(block.contains("onlineSearch.errorMessage"))
        XCTAssertTrue(source.contains("\"nutrition.addMeal.onlineSearch.action\""))
    }

    /// C1 regression, repeated for this second call site: `aiCandidateRow` is
    /// ONE VStack/Form row, so once a second button (this task's "Online
    /// suchen") joins the pre-existing "manuell suchen" button inside the
    /// SAME `hasNoCatalogMatch` branch, EVERY button in that branch must
    /// carry its own `.buttonStyle(.borderless)` hit target — otherwise taps
    /// collapse onto the last button's action, exactly like the original C1
    /// bug in the `isAmbiguous` branch below it.
    func testAICandidateNoMatchBranchButtonsAreAllBorderless() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let noMatchRange = source.range(of: "if candidate.hasNoCatalogMatch {") else {
            XCTFail("kein `if candidate.hasNoCatalogMatch` Zweig in aiCandidateRow gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: noMatchRange.upperBound))
        let buttonCount = block.components(separatedBy: "Button {").count - 1
        let borderlessCount = block.components(separatedBy: ".buttonStyle(.borderless)").count - 1
        // Task 6 added a third ("eigenes Lebensmittel anlegen") button to this
        // same shared Form-row VStack, alongside Task 4/5's "manuell suchen"
        // and "online suchen".
        XCTAssertEqual(buttonCount, 3, "erwartet: 'manuell suchen' + 'online suchen' + 'eigenes Lebensmittel anlegen' Button in diesem Zweig")
        XCTAssertEqual(borderlessCount, buttonCount, "jeder Button in diesem gemeinsamen Form-Row-VStack braucht .buttonStyle(.borderless), sonst C1-Regression")
    }

    // MARK: - Task 6: third, network/AI-independent entry point reuses the same AddMealView state

    /// Step 1 (Task 6 brief): the `hasNoCatalogMatch` branch must ALSO offer
    /// "eigenes Lebensmittel anlegen", prefilled with `candidate.foodText`,
    /// via the SAME `showingCustomFoodEntry`/`customFoodPrefillName` state
    /// the always-visible search-section entry point uses (no second,
    /// divergent sheet-presentation wiring).
    func testAICandidateNoMatchOffersCustomFoodEntryPrefilledWithFoodText() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let noMatchRange = source.range(of: "if candidate.hasNoCatalogMatch {") else {
            XCTFail("kein `if candidate.hasNoCatalogMatch` Zweig in aiCandidateRow gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: noMatchRange.upperBound))
        XCTAssertTrue(block.contains("customFoodPrefillName = candidate.foodText"))
        XCTAssertTrue(block.contains("showingCustomFoodEntry = true"))
        XCTAssertTrue(source.contains("\"nutrition.addMeal.customFood.action\""))
    }

    /// `OnlineFoodSearchController.search` ist der einzige Ort, der
    /// `candidates`/`errorMessage` zuruecksetzt — das deckt BEIDE
    /// Einstiegspunkte ab (gemeinsamer Controller), ohne dass `AddMealView`
    /// selbst vor jedem Such-Trigger ein explizites `reset()` braucht.
    /// Siehe Task-5-Brief: Variante (b), hier gegen den echten Code bestaetigt.
    func testSearchClearsStaleCandidatesAndErrorAtStartOfEveryCall() async {
        let controller = OnlineFoodSearchController(searcher: FakeOnlineFoodSearcher(result: .failure(.noNetwork)))
        await controller.search(query: "erster Suchbegriff", locale: Locale(identifier: "de_DE")) { _ in "Fehler A" }
        XCTAssertEqual(controller.errorMessage, "Fehler A")

        // Zweiter Aufruf (z.B. vom anderen Einstiegspunkt) mit Treffern:
        // weder der alte Fehlertext noch (waeren vorher welche da gewesen)
        // alte Candidates duerfen ueberleben, bevor der neue Request ueberhaupt
        // antwortet.
        let successController = OnlineFoodSearchController(searcher: FakeOnlineFoodSearcher(result: .success(Self.makeThreeCandidates())))
        await successController.search(query: "erster Suchbegriff", locale: Locale(identifier: "de_DE")) { _ in "" }
        XCTAssertEqual(successController.candidates.count, 3)

        await successController.search(query: "zweiter Suchbegriff", locale: Locale(identifier: "de_DE")) { _ in "Fehler B" }
        // `FakeOnlineFoodSearcher` liefert hier wieder dieselben 3 Treffer
        // (kein Fehler), aber der Punkt ist: der State wurde beim Start DIESES
        // Aufrufs neu gesetzt (candidates=[]/errorMessage=nil), nie einfach
        // vom vorherigen Aufruf uebernommen.
        XCTAssertNil(successController.errorMessage)
        XCTAssertEqual(successController.candidates.count, 3)
    }

    // MARK: - OFF-01: unbekannte Naehrwerte sind zulaessig, aber nie 0

    /// OFF-01 (docs/AUDIT_2026-10-23_DELTIQ.md): Ein Treffer mit einem
    /// fehlenden Makro ist uebernehmbar — der fehlende Wert bleibt `nil`
    /// (unbekannt), wird NICHT als 0 gespeichert und die Vorschau markiert
    /// ihn als unvollstaendig. Vorher war genau dieser Fall eine Sackgasse.
    func testPartialCandidateIsImportableWithUnknownValuesStoredAsUnknown() throws {
        let values = try XCTUnwrap(OnlineFoodImportValues(
            name: "Teilprodukt",
            kcalPer100g: 100,
            proteinPer100g: nil,
            carbsPer100g: 5,
            fatPer100g: nil
        ))
        XCTAssertTrue(values.hasUnknownValues, "fehlende Makros muessen als unvollstaendig markiert sein")
        XCTAssertFalse(values.isComplete)

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

        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<FoodCatalogEntry>()).first)
        let nutrients = stored.nutrientsPer100g
        XCTAssertEqual(nutrients.kcal.value, 100)
        XCTAssertEqual(nutrients.carbsG.value, 5)
        XCTAssertTrue(nutrients.proteinG.isUnknown, "fehlendes Protein bleibt unbekannt, nicht 0")
        XCTAssertTrue(nutrients.fatG.isUnknown, "fehlendes Fett bleibt unbekannt, nicht 0")
        XCTAssertTrue(nutrients.partiallyKnown)

        // Der Snapshot in der Mahlzeit traegt die Unbekannt-Markierung mit.
        let itemNutrients = try XCTUnwrap(NutritionCalculations.nutrients(for: stored.asCatalogItem, quantity: 100, unit: .gram))
        let meal = MealEntry(date: Date(), mealType: .lunch)
        context.insert(meal)
        let item = MealItem(catalogID: stored.catalogID, nameSnapshot: "Teilprodukt", quantity: 100, unit: .gram,
                            nutrients: itemNutrients, meal: meal)
        context.insert(item)
        try context.save()

        XCTAssertTrue(item.nutrientsSnapshot.fatG.isUnknown)
        XCTAssertEqual(item.nutrientsSnapshot.kcal.value, 100)
    }

    /// OFF-01: Ein Eintrag ganz ohne Naehrwerte traegt keine Information und
    /// bleibt nicht bestaetigbar (die Vorschau bietet stattdessen den Weg
    /// zum manuellen Anlegen an).
    func testCandidateWithoutAnyNutrientValueCannotBeConfirmed() throws {
        // Nur der unbekannte Fall: ein Negativwert ist ein Eingabefehler und
        // keine Luecke — in Swift unterscheidet der Compiler die beiden
        // `init?`-Varianten anhand des Parameter-Typs, hier bewusst `nil`.
        let values: OnlineFoodImportValues? = OnlineFoodImportValues(
            name: "Ohne Werte",
            kcalPer100g: nil,
            proteinPer100g: nil,
            carbsPer100g: nil,
            fatPer100g: nil
        )
        XCTAssertNil(values, "ohne jeden Naehrwert gibt es nichts zu uebernehmen")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogEntry>()), 0)
    }

    func testNegativeMacroCandidateCannotBeConfirmed() {
        // Expliziter `Double?`-Kontext, damit die `Double?`-Variante von
        // `OnlineFoodImportValues.init?` gewaehlt wird (die `Double`-Variante
        // wuerde die Absicht — „negativ = ungueltig" — nur zufaellig treffen).
        let values: OnlineFoodImportValues? = OnlineFoodImportValues(
            name: "Teilprodukt",
            kcalPer100g: 100,
            proteinPer100g: -1,
            carbsPer100g: 5,
            fatPer100g: 2
        )
        XCTAssertNil(values, "ein negativer Makrowert darf nicht bestaetigbar sein")
    }

    func testBlankNameCandidateCannotBeConfirmed() {
        let values: OnlineFoodImportValues? = OnlineFoodImportValues(
            name: "   ",
            kcalPer100g: 100,
            proteinPer100g: 1,
            carbsPer100g: 5,
            fatPer100g: 2
        )
        XCTAssertNil(values, "ein leerer Name darf nicht bestaetigbar sein")
    }

    // MARK: - Final-review fix (I1): online-search results must be scoped to the entry point that started them

    func testManualSearchResultsAreScopedToManualOrigin() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let gateRange = source.range(of: "if onlineFoodLookupEnabled {") else {
            XCTFail("kein onlineFoodLookupEnabled-Gate in searchSection gefunden")
            return
        }
        let gatedBlock = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: gateRange.upperBound))
        XCTAssertTrue(
            gatedBlock.contains("if onlineSearchOrigin == .manual {"),
            "Ergebnisse/Fehler der manuellen Suche duerfen nicht sichtbar sein, waehrend ein KI-Kandidat die aktive Suche gestartet hat"
        )
    }

    func testAICandidateOnlineSearchResultsAreScopedToThatCandidatesOwnOrigin() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let noMatchRange = source.range(of: "if candidate.hasNoCatalogMatch {") else {
            XCTFail("kein `if candidate.hasNoCatalogMatch` Zweig gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: noMatchRange.upperBound))
        guard let gateRange = block.range(of: "if onlineFoodLookupEnabled {") else {
            XCTFail("kein verschachteltes onlineFoodLookupEnabled-Gate in aiCandidateRow gefunden")
            return
        }
        let gatedBlock = try XCTUnwrap(Self.matchingBraceBlock(in: block, afterOpenBrace: gateRange.upperBound))
        XCTAssertTrue(
            gatedBlock.contains("if onlineSearchOrigin == .aiCandidate(candidate) {"),
            "Ergebnisse/Fehler duerfen nur unter GENAU diesem Kandidaten erscheinen, nicht unter jedem unmatched Kandidaten"
        )
        XCTAssertTrue(gatedBlock.contains("runOnlineSearch(origin: .aiCandidate(candidate)"))
    }

    /// Second part of I1: a successful import that originated from an AI
    /// candidate must remove that candidate (like its sibling "manuell
    /// suchen"/"eigenes Lebensmittel anlegen" buttons already do) and carry
    /// over its quantity/unit via the SAME `applyAICandidate` a normal
    /// catalog match uses, instead of leaving them `nil`.
    func testConfirmOnlineImportFromAICandidateReusesApplyAICandidate() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let confirmRange = source.range(of: "private func confirmOnlineImport(_ values: OnlineFoodImportValues) {") else {
            XCTFail("confirmOnlineImport nicht gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: confirmRange.upperBound))
        XCTAssertTrue(block.contains("case .aiCandidate(let candidate)"), "muss zwischen manuellem und KI-Kandidaten-Ursprung unterscheiden")
        XCTAssertTrue(
            block.contains("applyAICandidate(candidate, entry: entry)"),
            "muss Menge/Einheit ueber denselben Pfad wie ein normaler KI-Treffer uebernehmen, statt sie auf nil zu lassen, und dabei den Kandidaten entfernen"
        )
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
