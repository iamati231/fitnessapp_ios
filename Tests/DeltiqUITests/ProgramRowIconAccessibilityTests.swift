import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl). `ProgramRow.body`s Haupt-Icon
/// (`template.iconSystemName`) war nicht `.accessibilityHidden(true)`,
/// obwohl Name/Fokus/Tagline/Description direkt daneben den gesamten
/// Zeileninhalt bereits tragen - VoiceOver las zusaetzlich den SF-Symbol-
/// Namen vor.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe ComebackPromptSheetPercentLocalizationTests).
final class ProgramRowIconAccessibilityTests: XCTestCase {
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

    func testProgramRowIconIsAccessibilityHidden() throws {
        let text = try source
        guard let structStart = text.range(of: "private struct ProgramRow: View {") else {
            return XCTFail("ProgramRow not found at the expected declaration")
        }
        guard let bodyStart = text.range(of: "Image(systemName: template.iconSystemName)", range: structStart.upperBound..<text.endIndex) else {
            return XCTFail("ProgramRow's icon Image not found")
        }
        guard let chainEnd = text.range(of: "\n\n", range: bodyStart.upperBound..<text.endIndex) else {
            return XCTFail("end of icon modifier chain not found")
        }
        let modifierChain = text[bodyStart.upperBound..<chainEnd.lowerBound]

        XCTAssertTrue(modifierChain.contains(".accessibilityHidden(true)"),
                      "ProgramRow's decorative icon must be .accessibilityHidden(true) - the row's text already carries the full content")
    }
}
