import XCTest

/// Online-Food-Lookup (Task 3, docs/superpowers/sdd/2026-10-22-online-food-lookup):
/// reiner Quelltext-Regressionstest (kein SwiftUI-Import noetig, laeuft auch
/// auf dem macOS-CI-Runner ohne UIKit) nach dem Muster von
/// `SetDisplayModeSettingTests` — stellt sicher, dass der Opt-in-Toggle fuer
/// die kommende Online-Suche (Task 4/5) denselben Persistenz-Mechanismus
/// (`@AppStorage`, Default aus) nutzt wie das Vorbild `externalWorkoutImportEnabled`,
/// und dass Task 4/5 genau den Key `onlineFoodLookupEnabled` lesen koennen.
final class OnlineFoodLookupSettingPersistenceTests: XCTestCase {
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

    func testOnlineFoodLookupToggleUsesAppStorageWithExpectedKeyAndDefault() throws {
        let source = try contents(of: "Settings/SettingsDataConnectionsView.swift")
        XCTAssertTrue(
            source.contains("@AppStorage(\"onlineFoodLookupEnabled\") private var onlineFoodLookupEnabled: Bool = false"),
            "Task 4/5 liest den Opt-in-Zustand ueber den exakten AppStorage-Key \"onlineFoodLookupEnabled\" "
                + "(Default false) — ein abweichender Key oder Default wuerde die Einstellung dort still "
                + "wirkungslos machen."
        )
    }

    func testOnlineFoodLookupToggleFooterReactsToToggleState() throws {
        let source = try contents(of: "Settings/SettingsDataConnectionsView.swift")
        XCTAssertTrue(
            source.contains("settings.foodLookup.toggle.footer.off"),
                "Der Help-Text braucht einen eigenen OFF-Text, sonst reagiert er nicht auf den Toggle-Zustand."
        )
        XCTAssertTrue(
            source.contains("settings.foodLookup.toggle.footer.on"),
                "Der Help-Text braucht einen eigenen ON-Text, sonst reagiert er nicht auf den Toggle-Zustand."
        )
        XCTAssertTrue(
            source.contains("onlineFoodLookupEnabled\n                    ?"),
                "Die beiden Footer-Texte muessen ueber den Toggle-Zustand " +
                "`onlineFoodLookupEnabled` ausgewaehlt werden, sonst zeigt der Footer " +
                "immer denselben Text, egal wie der Toggle steht."
        )

        let strings = try contents(of: "Resources/Localizable.xcstrings")
        XCTAssertFalse(
            strings.contains("\"settings.foodLookup.toggle.footer\":"),
            "Der alte, zustandslose Einzel-Key darf nicht mehr existieren, sonst bleibt " +
                "ungewiss, ob er noch irgendwo verwendet wird."
        )
        for key in ["settings.foodLookup.toggle.footer.off", "settings.foodLookup.toggle.footer.on"] {
            XCTAssertTrue(
                strings.contains("\"\(key)\": {"),
                "Localizable.xcstrings muss den Key \(key) enthalten."
            )
        }
        // Echte, unterschiedliche DE/EN/TR-Werte statt Platzhaltern fuer beide Keys.
        XCTAssertTrue(strings.contains("Würde unbekannte Lebensmittel online bei Open Food Facts suchen"))
        XCTAssertTrue(strings.contains("Would search Open Food Facts online for unknown foods"))
        XCTAssertTrue(strings.contains("Bilinmeyen besinleri Open Food Facts üzerinden çevrimiçi arar. Arama sorguları harici bir hizmete gönderilirdi"))
        XCTAssertTrue(strings.contains("Aktiv: Wird in der Lebensmittelsuche als Option angeboten"))
        XCTAssertTrue(strings.contains("Active: offered as an option in food search"))
        XCTAssertTrue(strings.contains("Aktif: Besin aramasında bir seçenek olarak sunulur"))
    }

    func testOnlineFoodLookupCreditsViewExistsAndShowsODblAttribution() throws {
        let source = try contents(of: "Settings/OnlineFoodLookupCreditsView.swift")
        XCTAssertTrue(
            source.contains("settings.credits.onlineFoodLookup.attribution"),
            "Die ODbL-Lizenz von Open Food Facts verlangt einen sichtbaren Lizenzhinweis - "
                + "OnlineFoodLookupCreditsView muss den Attribution-Text anzeigen."
        )
        XCTAssertTrue(
            source.contains("openfoodfacts.org"),
            "Die ODbL-Attribution muss einen sichtbaren Link/Text zur Open-Food-Facts-Projektseite enthalten."
        )
    }
}
