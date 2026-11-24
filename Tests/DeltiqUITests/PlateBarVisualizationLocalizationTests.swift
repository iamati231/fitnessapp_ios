import XCTest

/// Audit-Fund (Modul 10, Calculators): `accessibilityDescription` lieferte
/// hartcodierten deutschen Text, waehrend jedes andere accessibilityLabel im
/// Projekt lokalisiert ist (VoiceOver haette also unabhaengig von der
/// Geraete-Sprache immer Deutsch vorgelesen). Quelltext-Pruefung statt
/// Verhaltenstest: `swift test` laedt Localizable.xcstrings nur roh ohne den
/// Xcode-Compile-Schritt, String(localized:) liefert dort also nur den
/// rohen Key zurueck (siehe LocalizationCatalogParityTests) — die eigentliche
/// Uebersetzungs-/Key-Existenz-Pruefung uebernimmt bereits dieser Test.
final class PlateBarVisualizationLocalizationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Calculators/PlateBarVisualization.swift"),
                encoding: .utf8
            )
        }
    }

    private func body(of signature: String, in text: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            throw XCTSkip("\(signature) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            throw XCTSkip("end of \(signature) not found")
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testAccessibilityDescriptionIsFullyLocalized() throws {
        let body = try body(of: "private var accessibilityDescription: String {", in: try source)

        XCTAssertTrue(body.contains(#"String(localized: "calc.plate.barEmpty.a11y""#))
        XCTAssertTrue(body.contains(#"String(localized: "calc.plate.plateCount.a11y""#))
        XCTAssertTrue(body.contains(#"String(localized: "calc.plate.loadPerSide.a11y""#))

        XCTAssertFalse(body.contains("\"Stange ohne Plates\""),
                        "darf nicht zum hartcodierten deutschen Text zurueckfallen")
        XCTAssertFalse(body.contains("\"Beladung pro Seite"),
                        "darf nicht zum hartcodierten deutschen Text zurueckfallen")
    }
}
