import XCTest

/// Settings-Restructure-Task (2026-10-23): reiner Quelltext-Regressionstest
/// (kein SwiftUI-Import noetig, laeuft auch auf dem macOS-CI-Runner ohne
/// UIKit) nach dem Muster von `MainTabStructureTests`/
/// `OnlineFoodLookupSettingPersistenceTests` — prueft die neue
/// Gruppen-Reihenfolge in `SettingsView.groupNavigationSection`, den Umzug
/// des Open-Food-Facts-Lizenzhinweis-Links von `SettingsDataConnectionsView`
/// nach `SettingsHelpInfoView`, und die neue Attribution auf dem
/// Online-Suchergebnis-Screen (Teil C2).
final class SettingsGroupOrderAndAttributionTests: XCTestCase {
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

    /// Text between `afterOpenBrace` (position right after an already-consumed
    /// opening `{`) and its matching closing `}` — brace-depth counting, same
    /// helper shape as `OnlineFoodLookupFlowTests.matchingBraceBlock`.
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

    // MARK: - (a) Group row order

    func testGroupNavigationSectionRowsAreInTheNewOrder() throws {
        let source = try contents(of: "Settings/SettingsView.swift")
        guard let sectionRange = source.range(of: "private var groupNavigationSection: some View {") else {
            XCTFail("groupNavigationSection nicht gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: sectionRange.upperBound))

        let rowsInOrder = [
            "SettingsAppExperienceView()",
            "SettingsLibraryEquipmentView()",
            "NavigationLink(value: CalculatorsRoute.calculators)",
            "SettingsDataConnectionsView()",
            "SettingsHelpInfoView()"
        ]
        let positions = rowsInOrder.map { block.range(of: $0) }
        XCTAssertTrue(
            positions.allSatisfy { $0 != nil },
            "Alle 5 Gruppen-Zeilen muessen in groupNavigationSection vorhanden sein."
        )
        let indices = positions.compactMap { $0?.lowerBound }
        XCTAssertEqual(
            indices, indices.sorted(),
            "Gewuenschte Endreihenfolge: App-Erlebnis, Bibliothek & Ausstattung, Werkzeuge, "
                + "Daten & Verbindungen, Hilfe & Informationen."
        )
    }

    func testHelpInfoRowIsLastAndCarriesTheNoDividerModifier() throws {
        let source = try contents(of: "Settings/SettingsView.swift")
        guard let sectionRange = source.range(of: "private var groupNavigationSection: some View {") else {
            XCTFail("groupNavigationSection nicht gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: sectionRange.upperBound))
        guard let helpInfoRange = block.range(of: "SettingsHelpInfoView()") else {
            XCTFail("SettingsHelpInfoView()-Zeile nicht gefunden")
            return
        }
        let tail = block[helpInfoRange.upperBound...]
        XCTAssertTrue(
            tail.contains("showsDivider: false"),
            "Die zuletzt stehende Zeile (Hilfe & Informationen) muss showsDivider: false tragen."
        )
        // Werkzeuge ist nicht mehr die letzte Zeile und darf showsDivider: false
        // deshalb nicht mehr tragen (Default true greift wieder).
        guard let toolsRange = block.range(of: "NavigationLink(value: CalculatorsRoute.calculators)") else {
            XCTFail("Werkzeuge-Zeile nicht gefunden")
            return
        }
        guard let toolsRowEnd = block.range(of: "}", range: toolsRange.upperBound..<block.endIndex) else {
            XCTFail("Ende der Werkzeuge-Zeile nicht gefunden")
            return
        }
        let toolsRow = block[toolsRange.lowerBound..<toolsRowEnd.upperBound]
        XCTAssertFalse(
            toolsRow.contains("showsDivider: false"),
            "Werkzeuge ist jetzt die dritte von fuenf Zeilen, nicht mehr die letzte — showsDivider: false muss weg sein."
        )
    }

    // MARK: - (b) Open-Food-Facts credits link moved to Hilfe & Informationen

    func testOnlineFoodLookupCreditsLinkLivesInHelpInfoNotDataConnections() throws {
        let helpInfoSource = try contents(of: "Settings/SettingsHelpInfoView.swift")
        XCTAssertTrue(
            helpInfoSource.contains("OnlineFoodLookupCreditsView()"),
            "Der Open-Food-Facts-Lizenzhinweis-Link muss jetzt in SettingsHelpInfoView liegen."
        )

        let dataConnectionsSource = try contents(of: "Settings/SettingsDataConnectionsView.swift")
        XCTAssertFalse(
            dataConnectionsSource.contains("OnlineFoodLookupCreditsView()"),
            "SettingsDataConnectionsView darf den Credits-Link nicht mehr enthalten, nur noch den funktionalen Toggle."
        )
    }

    func testOnlineFoodLookupToggleStaysInDataConnections() throws {
        let dataConnectionsSource = try contents(of: "Settings/SettingsDataConnectionsView.swift")
        XCTAssertTrue(
            dataConnectionsSource.contains(
                "@AppStorage(\"onlineFoodLookupEnabled\") private var onlineFoodLookupEnabled: Bool = false"
            ),
            "Der funktionale Opt-in-Toggle muss unveraendert in SettingsDataConnectionsView bleiben."
        )
    }

    // MARK: - (c) Per-screen attribution on the online search results

    func testOnlineFoodResultsListShowsAttributionOnlyWhenCandidatesArePresent() throws {
        let source = try contents(of: "Nutrition/OnlineFoodResultsList.swift")
        XCTAssertTrue(
            source.contains("\"nutrition.addMeal.onlineSearch.attribution\""),
            "Die Trefferliste muss den neuen Attribution-Key fuer Open Food Facts zeigen."
        )
        guard let guardRange = source.range(of: "if !candidates.isEmpty {") else {
            XCTFail("Die Attribution muss hinter einem !candidates.isEmpty-Gate stehen, nicht immer sichtbar sein.")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: guardRange.upperBound))
        XCTAssertTrue(
            block.contains("nutrition.addMeal.onlineSearch.attribution"),
            "Der Attribution-Text muss INNERHALB des !candidates.isEmpty-Gates stehen."
        )
    }

    func testCreditsScreenIncludesOfficialShortFormCopyrightLine() throws {
        let source = try contents(of: "Settings/OnlineFoodLookupCreditsView.swift")
        XCTAssertTrue(
            source.contains("\"settings.credits.onlineFoodLookup.copyright\""),
            "Die Credits-Seite muss die offiziell vorgeschlagene Kurzform-Attribution zusaetzlich zum bestehenden Lizenztext zeigen."
        )
        // Bestehender Lizenztext/Attribution-Key bleibt erhalten (nicht ersetzt).
        XCTAssertTrue(source.contains("settings.credits.onlineFoodLookup.body"))
        XCTAssertTrue(source.contains("settings.credits.onlineFoodLookup.attribution"))

        let strings = try contents(of: "Resources/Localizable.xcstrings")
        for key in ["settings.credits.onlineFoodLookup.copyright", "nutrition.addMeal.onlineSearch.attribution"] {
            XCTAssertTrue(strings.contains("\"\(key)\": {"), "Localizable.xcstrings muss den Key \(key) enthalten.")
        }
        XCTAssertTrue(strings.contains("(c) Open Food Facts contributors"))
    }
}
