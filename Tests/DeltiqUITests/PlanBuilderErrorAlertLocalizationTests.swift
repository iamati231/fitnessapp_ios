import XCTest

/// Audit-Fund (Modul 21, PlanBuilderView). Die beiden Fehler-Alerts
/// (`missingProfileErrorMessage`/`adoptSaveErrorMessage`) nutzten
/// `Button("OK") { ... }` - ein hartcodiertes, nicht lokalisiertes Literal,
/// waehrend jede andere Beschriftung in dieser Datei (u.a. "Abbrechen" ueber
/// `common.cancel`) durch den Catalog geht.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class PlanBuilderErrorAlertLocalizationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/PlanBuilderView.swift"),
                encoding: .utf8
            )
        }
    }

    func testErrorAlertsDoNotHardcodeOKButton() throws {
        let text = try source
        // Kommentare vor dem Vergleich strippen (Modul-11/19/20-Pitfall:
        // ein erklaerender Kommentar koennte den alten String zitieren).
        let codeOnly = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentStart = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentStart.lowerBound]
            }
            .joined(separator: "\n")

        XCTAssertFalse(codeOnly.contains("Button(\"OK\")"),
                        "beide Fehler-Alerts duerfen den Bestaetigungs-Button nicht mehr als hartcodiertes \"OK\"-Literal bauen")
        XCTAssertTrue(codeOnly.contains("Text(\"common.ok\", bundle: .module)"),
                      "die Fehler-Alerts muessen den lokalisierten common.ok-Catalog-Key nutzen, analog zum bestehenden common.cancel-Muster")
    }

    func testCatalogHasCommonOkKeyWithAllThreeLanguages() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        XCTAssertTrue(catalog.contains("\"common.ok\""))
        XCTAssertTrue(catalog.contains("\"Tamam\""),
                      "common.ok braucht eine tuerkische Uebersetzung wie die anderen common.*-Keys")
    }
}
