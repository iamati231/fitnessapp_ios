import XCTest

/// Audit-Fund (Modul 20, Circuit-Player). `exerciseCheckRow` zeigte den
/// Abhak-Status jeder Uebung im `.fixedReps`-Modus NUR per Checkmark-/Kreis-
/// Icon an - ohne `.accessibilityHidden(true)` darauf und ohne einen
/// verlaesslichen Status am Button selbst, las VoiceOver fuer abgehakte und
/// nicht abgehakte Uebungen denselben Name+Ziel-Text vor, der einzige
/// Unterschied war die automatisch aus dem SF-Symbol-Namen abgeleitete
/// Beschreibung ("checkmark circle fill" vs. "circle").
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe WorkoutHistoryTimedFormatStatsAccessibilityTests).
final class CircuitExerciseCheckRowAccessibilityTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/CircuitWorkoutPlayerView.swift"),
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

    func testExerciseCheckRowExposesCheckedStateToVoiceOver() throws {
        let text = try source
        guard let start = text.range(of: "private func exerciseCheckRow(_ exercise: Exercise, showsDivider: Bool) -> some View {") else {
            return XCTFail("exerciseCheckRow not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of exerciseCheckRow not found")
        }
        let body = Self.stripLineComments(String(text[start.upperBound..<end.lowerBound]))

        XCTAssertTrue(body.contains("Image(systemName: checked ? \"checkmark.circle.fill\" : \"circle\")"),
                      "the check icon itself must still be there - this test targets its accessibility modifiers, not its removal")
        XCTAssertTrue(body.contains(".accessibilityHidden(true)"),
                      "the decorative check/circle icon must be hidden from VoiceOver - its state is purely visual redundancy once the row exposes a real status")
        XCTAssertTrue(body.contains(".accessibilityAddTraits(checked ? .isSelected : [])"),
                      "the row's button must expose the checked state as a real accessibility trait, matching the .isSelected pattern already used elsewhere in DeltiqUI (e.g. AddMealView, OnboardingView, Theme)")
    }
}
