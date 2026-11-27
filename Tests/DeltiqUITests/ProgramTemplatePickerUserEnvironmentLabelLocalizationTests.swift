import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl). `userEnvironmentLabel` lieferte im
/// Fallback-Zweig (kein Profil mit `environment` vorhanden) hartcodiertes
/// Deutsch "alle" statt eines lokalisierten Werts, obwohl jede andere Stelle
/// dieser Datei konsequent ueber String(localized:) laeuft.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe ComebackPromptSheetPercentLocalizationTests).
final class ProgramTemplatePickerUserEnvironmentLabelLocalizationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ProgramTemplatePickerView.swift"),
                encoding: .utf8
            )
        }
    }

    func testUserEnvironmentLabelFallbackIsLocalizedNotHardcoded() throws {
        let text = try source
        guard let start = text.range(of: "private var userEnvironmentLabel: String {") else {
            return XCTFail("userEnvironmentLabel not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of userEnvironmentLabel not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        // Strip "//"-comments before checking: this function's own explanatory
        // comment quotes the old hardcoded literal, which would otherwise make
        // the .contains() check below a false positive against prose, not code.
        let code = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")

        XCTAssertFalse(code.contains("return \"alle\""),
                       "the nil-environment fallback must no longer hardcode \"alle\" - other locales need their own word")
        XCTAssertTrue(code.contains("environment.allFallback"),
                      "the fallback must use a localized catalog key, matching every other string in this file")
    }

    func testCatalogHasAllFallbackKeyForAllThreeLocales() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        XCTAssertTrue(catalog.contains("\"environment.allFallback\""))
        XCTAssertTrue(catalog.contains("\"value\" : \"alle\"") || catalog.contains("\"value\": \"alle\""),
                      "German translation must keep the original lowercase word")
        XCTAssertTrue(catalog.contains("\"value\" : \"all\"") || catalog.contains("\"value\": \"all\""))
        XCTAssertTrue(catalog.contains("tümü"))
    }
}
