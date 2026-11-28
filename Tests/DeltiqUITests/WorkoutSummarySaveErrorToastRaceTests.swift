import XCTest

/// Audit-Fund (Modul 23, WorkoutSummaryView+Health-Export). `showSaveErrorToast()`
/// plante einen unbedingten Dismiss-Timer ohne Generation-Token - ein zweiter
/// Save-Fehlschlag innerhalb desselben 3-Sekunden-Fensters wurde vom zuerst
/// geplanten Dismiss vorzeitig ausgeblendet. Gleiches Muster wie bereits
/// gefixt in `PlanEditorView.showTransientToast`.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe `ComebackPromptSheetPercentLocalizationTests`).
final class WorkoutSummarySaveErrorToastRaceTests: XCTestCase {
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

    func testSaveErrorToastHasGenerationCounter() throws {
        let text = try source
        XCTAssertTrue(text.contains("@State private var saveErrorToastGeneration"),
                      "WorkoutSummaryView needs a generation counter for its save-error toast, matching PlanEditorView.swapResultToastGeneration")
    }

    func testShowSaveErrorToastGuardsDismissWithGeneration() throws {
        let text = try source
        guard let start = text.range(of: "private func showSaveErrorToast() {") else {
            return XCTFail("showSaveErrorToast() not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of showSaveErrorToast() not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains("saveErrorToastGeneration += 1"),
                      "each call must bump the generation counter before scheduling the dismiss")
        guard let incrementRange = body.range(of: "saveErrorToastGeneration += 1") else {
            return XCTFail("increment statement not found")
        }
        guard let dismissScheduleRange = body.range(of: "asyncAfter", range: incrementRange.upperBound..<body.endIndex) else {
            return XCTFail("asyncAfter dismiss scheduling not found after the increment")
        }
        let dismissClosure = body[dismissScheduleRange.upperBound..<body.endIndex]
        XCTAssertTrue(dismissClosure.contains("guard saveErrorToastGeneration == generation else { return }"),
                      "the scheduled dismiss closure must bail out if a newer toast has since been shown - otherwise a second, still-visible error toast gets dismissed early by the first one's timer")
    }
}
