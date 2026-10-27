#if canImport(SwiftData)
import XCTest
@testable import FitnessAppCore

/// Task: Ernaehrungserfassung UX verbessern + lokalen Lebensmittelkatalog
/// erweitern. `AddMealView`/`BarcodeScannerSheet`'s neue UX-Logik (Beliebt-
/// Liste, Kategorie-Chips, Barcode-Kartenposition, gestalteter Scanner-
/// Screen) lebt in privaten Properties zweier SwiftUI-`View`-Structs mit
/// SwiftData-/VisionKit-Abhaengigkeiten — wie bei `OnlineFoodLookupFlowTests`/
/// `BarcodeLookupFlowTests` etabliert, werden Struktur-/Positions-
/// Eigenschaften ueber den Quelltext geprueft, nicht durch Instanziieren der
/// View (dort steht auch die ausfuehrliche Begruendung fuer diesen Ansatz).
final class NutritionCatalogUXTests: XCTestCase {
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

    // MARK: - Spec 2.1/2.2: Barcode-Einstieg sitzt direkt unter dem Suchfeld, vor Kategorien/Treffern

    func testBarcodeEntrySitsDirectlyUnderSearchFieldInSearchSection() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let sectionRange = source.range(of: "private var searchSection: some View {") else {
            XCTFail("searchSection nicht gefunden")
            return
        }
        let tail = source[sectionRange.upperBound...]
        guard let searchFieldIndex = tail.range(of: "searchField")?.lowerBound,
              let barcodeIndex = tail.range(of: "barcodeEntryRow")?.lowerBound,
              let categoryChipsIndex = tail.range(of: "categoryChipsRow")?.lowerBound
        else {
            XCTFail("searchField/barcodeEntryRow/categoryChipsRow nicht in searchSection gefunden")
            return
        }
        XCTAssertLessThan(searchFieldIndex, barcodeIndex, "Barcode-Einstieg muss NACH dem Suchfeld kommen")
        XCTAssertLessThan(barcodeIndex, categoryChipsIndex, "Barcode-Einstieg muss VOR Kategorie-Chips/Trefferliste kommen")
    }

    /// Spec: "Scanner-Einstieg bleibt auch dann sichtbar, wenn die lokale
    /// Suche Treffer liefert" — darf also nicht im 0-Treffer-Zweig haengen.
    func testBarcodeEntryIsNotNestedInsideTheNoResultsBranch() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let sectionRange = source.range(of: "private var searchSection: some View {") else {
            XCTFail("searchSection nicht gefunden")
            return
        }
        let tail = source[sectionRange.upperBound...]
        guard let barcodeIndex = tail.range(of: "barcodeEntryRow")?.lowerBound,
              let emptyBranchIndex = tail.range(of: "filteredEntries.isEmpty")?.lowerBound
        else {
            XCTFail("barcodeEntryRow/filteredEntries.isEmpty nicht gefunden")
            return
        }
        XCTAssertLessThan(barcodeIndex, emptyBranchIndex, "Barcode-Einstieg darf nicht im 0-Treffer-Zweig verschachtelt sein")
    }

    // MARK: - Spec 2.3: deaktiviertes Opt-in zeigt Hinweis + Settings-Link, kein Kamera-/Netzstart

    func testBarcodeEntryRowLinksToExistingSettingsScreenWhenOptInDisabled() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let range = source.range(of: "private var barcodeEntryRow: some View {") else {
            XCTFail("barcodeEntryRow nicht gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(block.contains("if onlineFoodLookupEnabled {"))
        XCTAssertTrue(block.contains("showingBarcodeScanner = true"))
        XCTAssertTrue(block.contains("showingDataConnectionsSettings = true"), "deaktiviertes Opt-in muss auf die bestehende Settings-Seite verlinken, nicht auf einen erfundenen Pfad")
        // Kein erfundener Navigationspfad: dieselbe, bereits vorhandene View.
        XCTAssertTrue(source.contains(".sheet(isPresented: $showingDataConnectionsSettings) {"))
        XCTAssertTrue(source.contains("SettingsDataConnectionsView()"))
    }

    // MARK: - Spec 2.4: kein leeres Suchfeld zeigt mehr den ganzen Katalog

    func testEmptySearchShowsPopularEntriesNotTheFullCatalog() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let range = source.range(of: "private var searchSection: some View {") else {
            XCTFail("searchSection nicht gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        guard let browsingRange = block.range(of: "if isBrowsingWithoutQuery {") else {
            XCTFail("isBrowsingWithoutQuery-Zweig nicht gefunden")
            return
        }
        let browsingBlock = try XCTUnwrap(Self.matchingBraceBlock(in: block, afterOpenBrace: browsingRange.upperBound))
        XCTAssertTrue(browsingBlock.contains("popularEntries"), "leeres Suchfeld + keine Kategorie muss die Beliebt-Auswahl zeigen")
        XCTAssertFalse(browsingBlock.contains("catalogEntries)"), "darf NICHT den gesamten catalogEntries-Katalog rendern")
    }

    /// Spec 2.4: hoechstens 6–8 Eintraege, stabile bereits vorhandene
    /// Katalog-IDs — Cross-Check gegen den echten `FoodCatalogData.all`.
    func testPopularSelectionUsesAtMostEightExistingStableCatalogIDs() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let range = source.range(of: "private static let popularCatalogIDs: [String] = ["),
              let closeRange = source.range(of: "]", range: range.upperBound..<source.endIndex)
        else {
            XCTFail("popularCatalogIDs nicht gefunden")
            return
        }
        let literal = source[range.upperBound..<closeRange.lowerBound]
        let ids = literal
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\""))) }
            .filter { !$0.isEmpty }

        XCTAssertGreaterThanOrEqual(ids.count, 6)
        XCTAssertLessThanOrEqual(ids.count, 8)

        let catalogIDs = Set(FoodCatalogData.all.map(\.id))
        for id in ids {
            XCTAssertTrue(catalogIDs.contains(id), "Beliebt-ID '\(id)' existiert nicht (mehr) im Katalog")
        }
    }

    // MARK: - Spec 2.5: Kategorie-Chips nutzen FoodCategory, kein zweites Kategorie-System

    func testCategoryChipsUseFoodCategoryAndItsExistingLocalizationKeys() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        XCTAssertTrue(source.contains("FoodCategory.allCases"))
        XCTAssertTrue(source.contains("category.localizationKey"))
    }

    /// Spec: "Biete eine leicht erkennbare Moeglichkeit, einen aktiven
    /// Kategorie-Filter zurueckzusetzen." — ein eigener "Alle"-Chip statt
    /// verstecktem erneuten Antippen.
    func testCategoryChipsIncludeAResetToAllOption() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        XCTAssertTrue(source.contains("categoryChip(nil, label:"))
        XCTAssertTrue(source.contains("\"nutrition.addMeal.category.all\""))
    }

    /// Spec 2.5: eine Kategorie filtert auch ohne Suchtext; ein leerer
    /// Suchtext fuehrt bei AKTIVER Kategorie trotzdem nicht zur vollen Liste
    /// (das uebernimmt weiterhin `isBrowsingWithoutQuery`, siehe oben).
    func testFilteredEntriesAppliesCategoryFilterIndependentlyOfSearchText() throws {
        let source = try contents(of: "Nutrition/AddMealView.swift")
        guard let range = source.range(of: "private var filteredEntries: [FoodCatalogEntry] {") else {
            XCTFail("filteredEntries nicht gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(block.contains("selectedCategory"))
        XCTAssertTrue(block.contains("$0.category == selectedCategory"))
    }

    // MARK: - Spec 2.7: gestalteter Scanner-Screen statt vollflaechiger Kamera

    func testScannerHasOwnHeaderAndRoundedBoundedCameraCard() throws {
        let source = try contents(of: "Nutrition/BarcodeScannerSheet.swift")
        XCTAssertTrue(source.contains("DeltiqHeader("), "eigener Kopfbereich statt nativer Navigationsleiste")
        XCTAssertTrue(source.contains("onBack: onCancel"), "Schliessen-Button bleibt jederzeit erreichbar")
        XCTAssertTrue(source.contains("RoundedRectangle(cornerRadius: Deltiq.Radius.card"), "Live-Vorschau muss in einem abgerundeten Container liegen")
        XCTAssertTrue(source.contains(".clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.card"), "die echte Live-Vorschau muss geclippt werden, nicht durch ein Platzhalterbild ersetzt")
        XCTAssertTrue(source.contains("ScanFrameCorners()"), "dezente Scan-Markierungen ueber der Live-Kamera")
        XCTAssertTrue(source.contains(".allowsHitTesting(false)"), "dekorative Overlays duerfen die Erkennung nicht blockieren")
    }

    /// Nie eine technische Scanflaechen-Beschraenkung behaupten, die nicht
    /// implementiert ist (Spec: "Behaupte nicht, dass der Rahmen die
    /// Scanflaeche begrenzt, wenn dies nicht umgesetzt wurde").
    func testScannerDoesNotClaimARegionOfInterestItDoesNotImplement() throws {
        let source = try contents(of: "Nutrition/BarcodeScannerSheet.swift")
        XCTAssertFalse(source.contains("regionOfInterest"))
    }

    func testManualBarcodeEntryUsesTheSameOnDetectCallbackAsTheCamera() throws {
        let source = try contents(of: "Nutrition/BarcodeScannerSheet.swift")
        guard let range = source.range(of: "private func submitManualBarcode() {") else {
            XCTFail("submitManualBarcode nicht gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(block.contains("trimmed.allSatisfy(\\.isNumber)"), "nur Ziffern -- derselbe Guard wie der Produkt-Lookup-Client")
        XCTAssertTrue(block.contains("onDetect(trimmed)"), "muss denselben Callback wie die Kamera nutzen, keine zweite Lookup-Implementierung")
    }

    func testManualEntryShowsAnInvalidStateInsteadOfCrashingOrSilentlyFailing() throws {
        let source = try contents(of: "Nutrition/BarcodeScannerSheet.swift")
        XCTAssertTrue(source.contains("manualBarcodeError"))
        XCTAssertTrue(source.contains("\"nutrition.barcode.manualInvalid\""))
    }
}
#endif
