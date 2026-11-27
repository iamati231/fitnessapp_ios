import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor): `stepWeightText(_:)` baute
/// das Einheiten-Suffix der Warmup-Rampen-Gewichtsanzeige ueber ein hartcodiertes
/// `"kg"`/`"lbs"`-Literal statt ueber die bereits vorhandenen Catalog-Keys
/// `unit.kg.lower`/`unit.lbs.lower` (gleiches Muster wie `SetRow.swift`).
/// Quelltext-Pruefung auf kommentarbereinigtem Text (der Doc-Kommentar direkt ueber der
/// Funktion zitiert "kg"/"lbs" selbst in einem Beispiel).
final class ExerciseCardStepWeightUnitLocalizationTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private var source: String {
        get throws {
            try String(
                contentsOf: sourcesRoot.appendingPathComponent("Workout/ExerciseCard.swift"),
                encoding: .utf8
            )
        }
    }

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testStepWeightTextUsesLocalizedLowerUnitKeys() throws {
        let text = try source
        guard let start = text.range(of: "private func stepWeightText(_ step: WarmupStep) -> String {") else {
            return XCTFail("stepWeightText(_:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of stepWeightText(_:) not found")
        }
        let body = Self.stripLineComments(String(text[start.upperBound..<end.lowerBound]))

        XCTAssertFalse(body.contains("\"lbs\" : \"kg\""),
                       "stepWeightText must no longer hardcode the unit literal - use the localized lower-case catalog keys instead")
        XCTAssertTrue(body.contains("\"unit.lbs.lower\""))
        XCTAssertTrue(body.contains("\"unit.kg.lower\""))
        XCTAssertTrue(body.contains("String(localized:"))
    }

    func testCatalogHasLowerUnitKeys() throws {
        let catalogURL = sourcesRoot.appendingPathComponent("Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        XCTAssertTrue(catalog.contains("\"unit.kg.lower\""))
        XCTAssertTrue(catalog.contains("\"unit.lbs.lower\""))
    }
}
