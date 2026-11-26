import XCTest

/// Audit-Fund (Modul 21, Plan-Builder/Editor). `equipmentGapSection`s
/// Warndreieck-Icon stand ohne jeden Accessibility-Modifier neben dem
/// Banner-Text - VoiceOver las den SF-Symbol-Namen vor, statt ihn als
/// rein dekorativ zu ignorieren (Titel/Detail-Text tragen die volle
/// Information bereits ohne das Icon).
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe DayPickerSheetAccessibilityTests).
final class PlanEditorEquipmentGapIconAccessibilityTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/PlanEditorView.swift"),
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

    func testEquipmentGapWarningIconIsHiddenFromVoiceOver() throws {
        let cleaned = Self.stripLineComments(try source)

        guard let start = cleaned.range(of: "private var equipmentGapSection: some View {") else {
            return XCTFail("equipmentGapSection not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of equipmentGapSection not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let iconRange = body.range(of: "Image(systemName: \"exclamationmark.triangle.fill\")") else {
            return XCTFail("warning triangle icon not found")
        }
        let afterIcon = body[iconRange.upperBound...]
        guard let vstackRange = afterIcon.range(of: "VStack(alignment: .leading, spacing: 4) {") else {
            return XCTFail("VStack after the icon not found (sanity check on the match)")
        }
        let modifiers = afterIcon[afterIcon.startIndex..<vstackRange.lowerBound]
        XCTAssertTrue(modifiers.contains(".accessibilityHidden(true)"),
                      "the warning triangle must be hidden from VoiceOver - it is purely decorative, the title/detail Text views already carry the full information")
    }
}
