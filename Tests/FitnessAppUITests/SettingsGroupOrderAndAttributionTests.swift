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

    /// UI-Ticket ("Mehr-Informationsarchitektur"): die 5 Gruppen sind jetzt
    /// fuenf EIGENSTAENDIGE `DeltiqSection`s (`toolsSection`/
    /// `libraryEquipmentSection`/`appExperienceSection`/
    /// `dataConnectionsSection`/`helpInfoSection`) statt Zeilen unter einer
    /// gemeinsamen "Weitere Einstellungen"-Section - `groupNavigationSection`
    /// selbst ist nur noch ein `Group { ... }`, das sie in dieser Reihenfolge
    /// auflistet.
    func testGroupNavigationSectionRowsAreInTheNewOrder() throws {
        let source = try contents(of: "Settings/SettingsView.swift")
        guard let sectionRange = source.range(of: "private var groupNavigationSection: some View {") else {
            XCTFail("groupNavigationSection nicht gefunden")
            return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: sectionRange.upperBound))

        let sectionsInOrder = [
            "toolsSection",
            "libraryEquipmentSection",
            "appExperienceSection",
            "dataConnectionsSection",
            "helpInfoSection"
        ]
        let positions = sectionsInOrder.map { block.range(of: $0) }
        XCTAssertTrue(
            positions.allSatisfy { $0 != nil },
            "Alle 5 Gruppen-Sections muessen in groupNavigationSection referenziert sein."
        )
        let indices = positions.compactMap { $0?.lowerBound }
        XCTAssertEqual(
            indices, indices.sorted(),
            "Gewuenschte Endreihenfolge: Werkzeuge, Bibliothek & Ausruestung, App-Einstellungen, "
                + "Daten & Verbindungen, Hilfe & Informationen."
        )
    }

    /// Weder die gemeinsame "Weitere Einstellungen"-Ueberschrift noch die
    /// zugehoerige `settings.section.more`-Resource duerfen noch verwendet
    /// werden - das war die konkrete, fachlich falsche Zuordnung, die dieses
    /// Ticket beheben sollte.
    func testWeitereEinstellungenCollectiveSectionIsGone() throws {
        let source = try contents(of: "Settings/SettingsView.swift")
        XCTAssertFalse(
            source.contains("settings.section.more"),
            "Die Sammelueberschrift 'Weitere Einstellungen' darf nicht mehr verwendet werden - "
                + "Werkzeuge und Bibliothek & Ausruestung sind keine App-Einstellungen."
        )
    }

    /// Jede der 5 neuen Gruppen-Sections traegt genau EINE Zeile (ihre eigene
    /// `DeltiqSection`), deshalb muss jede Zeile `showsDivider: false` tragen
    /// - es gibt innerhalb der eigenen kleinen Karte nichts mehr, wovon sie
    /// sich per Trennlinie abgrenzen muesste.
    func testEachOfTheFiveGroupSectionsHasExactlyOneRowWithoutATrailingDivider() throws {
        let source = try contents(of: "Settings/SettingsView.swift")
        for sectionName in ["toolsSection", "libraryEquipmentSection", "appExperienceSection", "dataConnectionsSection", "helpInfoSection"] {
            guard let range = source.range(of: "private var \(sectionName): some View {") else {
                XCTFail("\(sectionName) nicht gefunden")
                continue
            }
            let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
            XCTAssertEqual(
                block.components(separatedBy: "NavigationLink").count - 1, 1,
                "\(sectionName) darf nur genau einen NavigationLink/eine Zeile enthalten."
            )
            XCTAssertTrue(
                block.contains("showsDivider: false"),
                "\(sectionName)s einzige Zeile muss showsDivider: false tragen."
            )
        }
    }

    /// UI-Ticket ("Mehr-Informationsarchitektur"): die Gruppe hiess vorher
    /// "App & Trainingserlebnis" - umbenannt, weil "App-Einstellungen" genauer
    /// beschreibt, was die Seite tatsaechlich zeigt (reine Konfiguration des
    /// App-Verhaltens: Einheiten, Darstellung, Timer, Erinnerungen, ...).
    func testAppExperienceGroupIsRenamedToAppSettingsInAllThreeLanguages() throws {
        let strings = try contents(of: "Resources/Localizable.xcstrings")
        guard let keyRange = strings.range(of: "\"settings.group.appExperience\": {") else {
            XCTFail("settings.group.appExperience nicht gefunden")
            return
        }
        guard let blockEnd = strings.range(of: "\n    },", range: keyRange.upperBound..<strings.endIndex) else {
            XCTFail("Ende des settings.group.appExperience-Eintrags nicht gefunden")
            return
        }
        let block = strings[keyRange.upperBound..<blockEnd.lowerBound]
        XCTAssertTrue(block.contains("App-Einstellungen"), "DE-Wert muss 'App-Einstellungen' sein")
        XCTAssertTrue(block.contains("App Settings"), "EN-Wert muss 'App Settings' sein")
        XCTAssertFalse(block.contains("App & Trainingserlebnis"), "der alte Name darf nicht mehr vorkommen")
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
