import XCTest

/// Audit-Fund (Modul 19, Workout-Helpers). `label(for:)` baute das
/// Prozent-Label im Nicht-empfohlen-Zweig hartcodiert als "\(percent) %"
/// ohne Lokalisierung, waehrend der empfohlene Zweig direkt daneben korrekt
/// ueber String(localized:) ging - TR setzt das Prozentzeichen vor die Zahl
/// ("%15"), das hartcodierte Format kann das nie abbilden.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class ComebackPromptSheetPercentLocalizationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ComebackPromptSheet.swift"),
                encoding: .utf8
            )
        }
    }

    func testLabelForNonRecommendedReductionIsLocalizedNotHardcoded() throws {
        let text = try source
        guard let start = text.range(of: "private func label(for reduction: Double) -> String {") else {
            return XCTFail("label(for:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of label(for:) not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("\"\\(percent) %\""),
                       "the non-recommended branch must no longer hardcode \"<percent> %\" - TR formats this differently (percent sign before the number)")
        XCTAssertTrue(body.contains("comeback.prompt.percentOnly"),
                      "the non-recommended branch must use a localized catalog key, matching the recommended branch's pattern")
    }

    func testCatalogHasPercentOnlyKeyWithTurkishPrefixFormat() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        XCTAssertTrue(catalog.contains("\"comeback.prompt.percentOnly\""))
        XCTAssertTrue(catalog.contains("\"%%%lld\""),
                      "Turkish localization must put the percent sign before the number, matching comeback.prompt.recommended's TR convention")
    }
}
