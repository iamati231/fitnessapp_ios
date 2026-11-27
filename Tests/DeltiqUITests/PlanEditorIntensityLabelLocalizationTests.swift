#if canImport(SwiftUI) && canImport(SwiftData) && canImport(UIKit)
import XCTest

/// Audit-Fund Modul 21 (PlanEditorView, DayRow): `intensityLabel(_:)` baute
/// das Intensitaets-Wort hartcodiert Deutsch ("Normal"/"Leicht"/"Schwer")
/// statt `DayIntensity.localizedName` zu nutzen, obwohl `DayEditorView`s
/// Intensitaets-Picker denselben Enum bereits korrekt lokalisiert.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe PlanEditorEquipmentGapBannerTests).
final class PlanEditorIntensityLabelLocalizationTests: XCTestCase {
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

    func testIntensityLabelUsesLocalizedNameNotHardcodedGerman() throws {
        let text = try source
        guard let start = text.range(of: "private func intensityLabel(_ intensity: DayIntensity) -> String {") else {
            return XCTFail("intensityLabel(_:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of intensityLabel(_:) not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains("intensity.localizedName"),
                      "intensityLabel must resolve via DayIntensity.localizedName, matching environmentLabel's pattern in the same file")
        XCTAssertFalse(body.contains("\"Normal\"") || body.contains("\"Leicht\"") || body.contains("\"Schwer\""),
                       "intensityLabel must no longer hardcode German literals - they bypass en/tr localization")
    }
}
#endif
