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
