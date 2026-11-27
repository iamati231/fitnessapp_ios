import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor). Der OK-Button des
/// plans.delete.error.title-Alerts war hartcodiertes "OK" statt des
/// existierenden common.ok-Katalog-Keys, inkonsistent zu den beiden direkt
/// danebenstehenden Buttons common.delete/common.cancel im selben Alert.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe ComebackPromptSheetPercentLocalizationTests).
final class PlansListDeleteErrorOkLocalizationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/PlansListView.swift"),
                encoding: .utf8
            )
        }
    }

    func testDeleteErrorAlertOkButtonIsLocalizedNotHardcoded() throws {
        let text = try source
        guard let start = text.range(of: "Text(\"plans.delete.error.title\", bundle: .module)") else {
            return XCTFail("plans.delete.error.title alert not found at the expected anchor")
        }
        guard let end = text.range(of: ".confirmationDialog(", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of the delete-error alert block not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("Button(\"OK\")"),
                       "the alert's OK button must no longer be a hardcoded \"OK\" literal")
        XCTAssertTrue(body.contains("\"common.ok\""),
                      "the alert's OK button must use the common.ok catalog key, matching the common.delete/common.cancel buttons in the same alert")
    }

    func testCatalogHasCommonOkKeyWithAllThreeLocales() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        guard let start = catalog.range(of: "\"common.ok\": {") else {
            return XCTFail("common.ok key not found in catalog")
        }
        guard let end = catalog.range(of: "\n    }", range: start.upperBound..<catalog.endIndex) else {
            return XCTFail("end of common.ok entry not found")
        }
        let entry = catalog[start.upperBound..<end.lowerBound]
        XCTAssertTrue(entry.contains("\"en\""))
        XCTAssertTrue(entry.contains("\"de\""))
        XCTAssertTrue(entry.contains("\"tr\""))
    }
}
