import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl). `equipmentStatusRow`s Status-Icon
/// hatte kein `.accessibilityHidden(true)`, obwohl der direkt daneben
/// stehende `title`-Text den Status bereits vollstaendig traegt - VoiceOver
/// las zusaetzlich den SF-Symbol-Namen vor statt nur den Status. Gleiches
/// Fix-Muster wie `DayPickerSheet.swift:145/187` (Modul 20).
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe ComebackPromptSheetPercentLocalizationTests).
final class ProgramPickerEquipmentStatusIconAccessibilityTests: XCTestCase {
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

    func testEquipmentStatusRowIconIsAccessibilityHidden() throws {
        let text = try source
        guard let start = text.range(of: "private func equipmentStatusRow(icon: String, tint: Color, title: String, detail: String?) -> some View {") else {
            return XCTFail("equipmentStatusRow(icon:tint:title:detail:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of equipmentStatusRow(icon:tint:title:detail:) not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        guard let iconRange = body.range(of: "Image(systemName: icon)") else {
            return XCTFail("Image(systemName: icon) not found inside equipmentStatusRow")
        }
        guard let nextIconRange = body.range(of: "Image(systemName:", range: iconRange.upperBound..<body.endIndex) else {
            // No further Image(...) call after this one - search to the end of the function body.
            XCTAssertTrue(body[iconRange.upperBound...].contains(".accessibilityHidden(true)"),
                          "the decorative status icon must be .accessibilityHidden(true) - title already carries the status as text")
            return
        }
        let iconModifiers = body[iconRange.upperBound..<nextIconRange.lowerBound]
        XCTAssertTrue(iconModifiers.contains(".accessibilityHidden(true)"),
                      "the decorative status icon must be .accessibilityHidden(true) - title already carries the status as text")
    }
}
