import XCTest

/// Audit-Fund (Modul (e), WorkoutSummaryView). `SetSummaryRow` hielt eine
/// live `@Bindable var log: ExerciseLog` und las deren Properties direkt in
/// `readOnlyRow`/`rowText` - dasselbe SwiftData-Observation-Crash-Muster,
/// das `PlanRowContent` (PlansListView.swift) als Ursache des bestaetigten
/// TestFlight-Crashs 0.1.0/175 dokumentiert. Fix extrahiert einen
/// `SetSummaryRowContent`-Snapshot fuer die reinen Anzeigepfade; `editRow`
/// behaelt bewusst live `log`-Zugriff fuer seine Zwei-Wege-Bindings.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe `ComebackPromptSheetPercentLocalizationTests`).
final class WorkoutSummarySetRowLiveModelCrashTests: XCTestCase {
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

    /// Strips `//`-comments before any `.contains()` check, so an
    /// explanatory comment quoting the old pattern can't false-positive
    /// the check (Modul-19-Pitfall).
    private func stripComments(_ text: Substring) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testSetSummaryRowContentSnapshotExists() throws {
        let text = try source
        XCTAssertTrue(text.contains("private struct SetSummaryRowContent: Equatable"),
                      "SetSummaryRowContent snapshot struct must exist, analogous to PlanRowContent")
        for field in ["setIndex", "weight", "reps", "rir", "distanceKm", "durationSeconds", "resolvedIsCardio", "resolvedIsTimeBased"] {
            XCTAssertTrue(text.contains("let \(field):"),
                          "SetSummaryRowContent must snapshot '\(field)'")
        }
    }

    func testReadOnlyRowAndRowTextNeverReadLiveLogDirectly() throws {
        let text = try source
        // readOnlyRow and rowText are checked SEPARATELY, excluding editRow's
        // body in between (Zeilen dazwischen) - editRow deliberately keeps
        // live $log.* two-way bindings for its TextField/Stepper, which would
        // false-positive a single combined start-of-readOnlyRow..<end-of-file
        // scan (caught by the calling session: the first version of this test
        // included editRow's ~154 lines and failed on its own correct bindings).
        guard let readOnlyStart = text.range(of: "private var readOnlyRow: some View {") else {
            return XCTFail("readOnlyRow not found at the expected signature")
        }
        guard let editRowStart = text.range(of: "private var editRow: some View {", range: readOnlyStart.upperBound..<text.endIndex) else {
            return XCTFail("editRow not found after readOnlyRow")
        }
        let readOnlyBody = stripComments(text[readOnlyStart.lowerBound..<editRowStart.lowerBound])

        guard let rowTextStart = text.range(of: "private var rowText: String {", range: editRowStart.upperBound..<text.endIndex) else {
            return XCTFail("rowText not found after editRow")
        }
        // rowText is the last computed property in SetSummaryRow - its closing
        // brace is the struct's own closing brace, so take the rest of the file.
        let rowTextBody = stripComments(text[rowTextStart.lowerBound..<text.endIndex])

        let combined = readOnlyBody + rowTextBody
        XCTAssertFalse(combined.contains("log.setIndex") || combined.contains("log.weight")
                       || combined.contains("log.reps") || combined.contains("log.rir")
                       || combined.contains("log.distanceKm") || combined.contains("log.durationSeconds")
                       || combined.contains("log.resolvedIsCardio") || combined.contains("log.resolvedIsTimeBased"),
                       "readOnlyRow/rowText must read ONLY the frozen 'content' snapshot, never 'log' directly - that is the crash risk this fix removes")
        XCTAssertTrue(combined.contains("content.setIndex") && combined.contains("content.resolvedIsCardio"),
                      "readOnlyRow/rowText must read from 'content'")
    }

    func testEditRowStillHasLiveWriteBindingsForEditing() throws {
        let text = try source
        // editRow's TextField/Stepper bindings must still write through the
        // live model - only the display-only paths were snapshotted.
        XCTAssertTrue(text.contains("value: $log.weight") || text.contains("$log.weight"),
                      "editRow must keep a live two-way binding to log.weight for its TextField")
        XCTAssertTrue(text.contains("$log.reps"),
                      "editRow must keep a live two-way binding to log.reps for its TextField")
        XCTAssertTrue(text.contains("$log.rir"),
                      "editRow must keep a live two-way binding to log.rir for its Stepper")
    }

    func testAllThreeSetSummaryRowCallSitesPassContent() throws {
        let text = try source
        let occurrences = text.components(separatedBy: "SetSummaryRow(log: log, content: SetSummaryRowContent(log)").count - 1
        XCTAssertEqual(occurrences, 3,
                       "All three SetSummaryRow call sites (editable section, non-editable section, orphaned-logs section) must construct and pass the content snapshot")
        XCTAssertFalse(text.contains("SetSummaryRow(log: log, isEditable:"),
                       "no call site may construct SetSummaryRow without the content snapshot anymore")
    }
}
