import XCTest

/// Audit-Fund (Modul (e), WorkoutSummaryView). `PRBadge.detailLine`s
/// `.mostRounds`-Zweig baute das Runden-Label hartcodiert als "Runden"
/// statt lokalisiert, waehrend jeder andere Zweig direkt daneben korrekt
/// ueber String(localized:) ging.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe ComebackPromptSheetPercentLocalizationTests).
final class WorkoutSummaryMostRoundsLocalizationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/WorkoutSummaryView.swift"),
                encoding: .utf8
            )
        }
    }

    private var catalogSource: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings"),
                encoding: .utf8
            )
        }
    }

    func testMostRoundsDetailLineIsLocalizedNotHardcoded() throws {
        let text = try source
        guard let start = text.range(of: "private var detailLine: String {") else {
            return XCTFail("detailLine not found at the expected signature")
        }
        guard let caseStart = text.range(of: "case .mostRounds:", range: start.upperBound..<text.endIndex) else {
            return XCTFail(".mostRounds case not found inside detailLine")
        }
        guard let caseEnd = text.range(of: "case .fastestTime:", range: caseStart.upperBound..<text.endIndex) else {
            return XCTFail("end of .mostRounds case not found")
        }
        let body = text[caseStart.upperBound..<caseEnd.lowerBound]
        // Strip "//"-comments before checking: the audit-fix comment right
        // above this case literally quotes "Runden", which would otherwise
        // make the .contains() check below a false positive against prose.
        let code = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")

        XCTAssertFalse(code.contains("\"Runden"),
                       "the .mostRounds case must no longer hardcode the German word \"Runden\"")
        XCTAssertTrue(code.contains("roundsUnit"),
                      "the .mostRounds case must use the localized roundsUnit, matching the other detailLine cases' pattern")
    }

    func testCatalogHasRoundsShortKeyForAllThreeLocales() throws {
        let catalog = try catalogSource
        XCTAssertTrue(catalog.contains("\"unit.rounds.short\""))
        guard let keyRange = catalog.range(of: "\"unit.rounds.short\"") else {
            return XCTFail("unit.rounds.short key not found")
        }
        let windowEnd = catalog.index(keyRange.upperBound, offsetBy: 400, limitedBy: catalog.endIndex) ?? catalog.endIndex
        let window = catalog[keyRange.upperBound..<windowEnd]
        for locale in ["\"de\"", "\"en\"", "\"tr\""] {
            XCTAssertTrue(window.contains(locale), "unit.rounds.short is missing a \(locale) translation")
        }
    }
}
