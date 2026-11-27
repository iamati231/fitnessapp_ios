import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor). `formatWeight(_:)`/
/// `formatKm(_:)` rundeten nur auf 1 Nachkommastelle statt wie der App-weite
/// Standard `Double.formattedWholeOrTwoDecimals` auf 2 - derselbe Datenpunkt
/// (z.B. 81.25 kg) zeigte hier "81.2 kg", in WorkoutSummaryView/SetRow/
/// PRHistoryView aber korrekt "81.25 kg".
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe ComebackPromptSheetPercentLocalizationTests).
final class ExerciseDetailViewPrecisionTests: XCTestCase {
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

    private func body(of signature: String, in text: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            throw XCTSkip("signature not found: \(signature)")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            throw XCTSkip("end of function not found for: \(signature)")
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testFormatWeightUsesSharedTwoDecimalFormatterNotOneDecimalTruncation() throws {
        let text = try source
        let body = try body(of: "private func formatWeight(_ kg: Double) -> String {", in: text)
        XCTAssertFalse(body.contains("truncated(to: 1)"),
                       "formatWeight must no longer round to only 1 decimal place")
        XCTAssertTrue(body.contains("formattedWholeOrTwoDecimals"),
                      "formatWeight must use the shared Double.formattedWholeOrTwoDecimals formatter, matching WorkoutSummaryView/SetRow/PRHistoryView")
    }

    func testFormatKmUsesSharedTwoDecimalFormatterNotOneDecimalTruncation() throws {
        let text = try source
        let body = try body(of: "private func formatKm(_ km: Double) -> String {", in: text)
        XCTAssertFalse(body.contains("truncated(to: 1)"),
                       "formatKm must no longer round to only 1 decimal place")
        XCTAssertTrue(body.contains("formattedWholeOrTwoDecimals"),
                      "formatKm must use the shared Double.formattedWholeOrTwoDecimals formatter, matching WorkoutSummaryView/SetRow/PRHistoryView")
    }
}
