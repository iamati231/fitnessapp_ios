import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor). `prSection`s
/// Trophy-Icon und `emptyState`s Hero-Icon hatten keinerlei Accessibility-
/// Modifier - VoiceOver las zusaetzlich den SF-Symbol-Namen vor, obwohl der
/// direkt daneben/darunter stehende Text (Kind/Datum/Gewicht bzw. Leertext)
/// den Inhalt bereits vollstaendig traegt.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe DayPickerSheetAccessibilityTests).
final class ExerciseDetailPRIconAccessibilityTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ExerciseDetailView.swift"),
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

    func testPRSectionHidesTrophyIconFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try source)

        guard let start = cleaned.range(of: "private var prSection: some View {") else {
            return XCTFail("prSection not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of prSection not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let iconRange = body.range(of: "Image(systemName: \"trophy.fill\")") else {
            return XCTFail("trophy icon not found")
        }
        let afterIcon = body[iconRange.upperBound...]
        XCTAssertTrue(afterIcon.contains(".accessibilityHidden(true)"),
                      "the trophy icon must be hidden from VoiceOver - it is purely decorative, the row's own text (kind/date/weight) already announces the content")
    }

    func testEmptyStateHidesHeroIconFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try source)

        guard let start = cleaned.range(of: "private var emptyState: some View {") else {
            return XCTFail("emptyState not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of emptyState not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let iconRange = body.range(of: "Image(systemName: \"chart.xyaxis.line\")") else {
            return XCTFail("hero icon not found")
        }
        let afterIcon = body[iconRange.upperBound...]
        XCTAssertTrue(afterIcon.contains(".accessibilityHidden(true)"),
                      "the empty-state hero icon must be hidden from VoiceOver - the text below it already announces the empty state")
    }
}
