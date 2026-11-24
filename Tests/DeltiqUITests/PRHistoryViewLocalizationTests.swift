import XCTest

/// Modul-12-Audit (History), Fund 4 (+ Fund 6). Drei permanente oder haeufig
/// gesehene Textstellen in `PRHistoryView.swift` waren hartcodiert Deutsch,
/// obwohl der Rest der Datei konsequent `String(localized:..., bundle:
/// .module)` nutzt:
///   1. Der Rebuild-Erfolgs-Toast ("N Rekorde detektiert").
///   2. Die permanent sichtbare PR-Anzahl + Datum pro Trophy-Karte.
///   3. Der komplette `detailLine`-Switch (eine Zeile pro PR-Eintrag) - jetzt
///      gespiegelt an `WorkoutSummaryView.detailLine` (DEL-126), die
///      dieselben wiederverwendbaren Keys (`pr.previousShort`,
///      `pr.volumeSuffix`, `unit.seconds.short`, `unit.reps.short`) nutzt.
/// `LocalizationCatalogParityTests` validiert generisch, dass jeder
/// referenzierte Key in allen drei Sprachen existiert - dieser Test prueft
/// stattdessen, dass der Quelltext selbst keine der alten hartcodierten
/// Strings mehr enthaelt.
final class PRHistoryViewLocalizationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/History/PRHistoryView.swift"),
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

    private static func body(of signature: String, in text: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            throw XCTSkip("\(signature) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            throw XCTSkip("end of \(signature) not found")
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testRebuildToastIsLocalized() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func rebuild() {", in: cleaned)

        XCTAssertFalse(body.contains("\"\\(inserted) Rekorde detektiert\""),
                       "must not hardcode the success toast in German")
        XCTAssertTrue(body.contains("String(localized: \"trophy.rebuild.toast.result\", bundle: .module)"))
    }

    func testExerciseCardSummaryLineIsLocalized() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private var headerLabel: some View {") else {
            return XCTFail("headerLabel not found")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of headerLabel not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("PR\\(group.entries.count == 1"),
                       "must not hardcode English \"PR\"/\"PRs\" pluralization mixed with hardcoded German \"zuletzt\"")
        XCTAssertTrue(body.contains("String(localized: \"trophy.exercise.summary\", bundle: .module)"))
    }

    func testDetailLineUsesSharedLocalizedUnitsInsteadOfHardcodedGerman() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private var detailLine: String {", in: cleaned)

        for key in ["pr.previousShort", "pr.volumeSuffix", "unit.seconds.short", "unit.reps.short"] {
            XCTAssertTrue(body.contains("String(localized: \"\(key)\", bundle: .module)"),
                          "must reuse the same localized unit key WorkoutSummaryView.detailLine (DEL-126) already uses: \(key)")
        }

        XCTAssertFalse(body.contains("Wdh (vorher"), "must not hardcode \"Wdh (vorher\" literally anymore")
        XCTAssertFalse(body.contains("Sek (vorher"), "must not hardcode \"Sek (vorher\" literally anymore")
        XCTAssertFalse(body.contains("kg-Vol"), "must not hardcode \"kg-Vol\" literally anymore")

        // Fund 6: maxReps must repeat the unit on the "previous" side too, like every sibling case.
        guard let maxRepsRange = body.range(of: "case .maxReps:") else {
            return XCTFail("maxReps case not found")
        }
        guard let maxHoldRange = body.range(of: "case .maxHoldSeconds:", range: maxRepsRange.upperBound..<body.endIndex) else {
            return XCTFail("maxHoldSeconds case not found")
        }
        let maxRepsCase = body[maxRepsRange.upperBound..<maxHoldRange.lowerBound]
        XCTAssertTrue(maxRepsCase.contains("\\(prevReps) \\(repUnit)"),
                      "maxReps must show the unit on the previous-value side too, matching every other case")
    }
}
