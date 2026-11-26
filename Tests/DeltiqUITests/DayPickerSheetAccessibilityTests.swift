import XCTest

/// Audit-Fund (Modul 20, Workout-Helpers). `dayRow` zeigte sein
/// Auswahl-Checkmark und `actionButton` sein Siegel-Icon ohne jeden
/// Accessibility-Modifier - VoiceOver las die automatisch generierten
/// SF-Symbol-Namen ("Haken, Kreis, gefuellt" / "Haken, Siegel, gefuellt")
/// vor, statt den Auswahlzustand semantisch zu melden.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe WorkoutHistoryTimedFormatStatsAccessibilityTests).
final class DayPickerSheetAccessibilityTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/DayPickerSheet.swift"),
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

    func testDayRowHidesCheckmarkIconAndReportsSelectionAsTrait() throws {
        let cleaned = Self.stripLineComments(try source)

        guard let start = cleaned.range(of: "private func dayRow(weekday: Int, label: String, short: String) -> some View {") else {
            return XCTFail("dayRow not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of dayRow not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let iconRange = body.range(of: "Image(systemName: \"checkmark.circle.fill\")") else {
            return XCTFail("checkmark icon not found")
        }
        XCTAssertTrue(body[iconRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(".symbolRenderingMode(.hierarchical)"),
                      "expected symbolRenderingMode to immediately follow the icon (sanity check on the match)")
        XCTAssertTrue(body.contains(".accessibilityHidden(true)"),
                      "the selection checkmark must be hidden from VoiceOver - it is purely decorative, the row's own accessibilityAddTraits reports the state")
        XCTAssertTrue(body.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"),
                      "dayRow's button must report its selection state as a VoiceOver trait, matching AddMealView.categoryChip's pattern")
    }

    func testActionButtonHidesSealIconFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try source)

        guard let start = cleaned.range(of: "private var actionButton: some View {") else {
            return XCTFail("actionButton not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of actionButton not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let iconRange = body.range(of: "Image(systemName: \"checkmark.seal.fill\")") else {
            return XCTFail("seal icon not found")
        }
        XCTAssertTrue(body[iconRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(".accessibilityHidden(true)"),
                      "the seal icon must be hidden from VoiceOver - it is purely decorative, the button's own label text already announces the action")
    }
}
