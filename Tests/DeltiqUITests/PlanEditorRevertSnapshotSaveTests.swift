import XCTest

/// Audit-Fund (Modul 21, Nachtrag). `revertToSnapshot()` mutierte den
/// Live-`plan`-Objektgraphen (snapshot.apply, revertDayOrder, isActive-
/// Reaktivierung) und rief danach `dismiss()`, ohne vorher `modelContext.save()`
/// aufzurufen - anders als jede andere mutierende Aktion dieser Datei
/// (siehe `saveAndDismiss()`). Derselbe Fehler war bereits in
/// `DayEditorView.revertToSnapshot()` gefunden und behoben worden
/// (`DayEditorRevertSnapshotSaveTests`).
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class PlanEditorRevertSnapshotSaveTests: XCTestCase {
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

    func testRevertToSnapshotSavesBeforeDismiss() throws {
        let text = try source
        guard let start = text.range(of: "private func revertToSnapshot() {") else {
            return XCTFail("revertToSnapshot() not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of revertToSnapshot() not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        // Strip "//"-comments before checking: this function's own
        // explanatory comment quotes "dismiss()" and "modelContext.save()",
        // which would otherwise make the ordering check below unreliable
        // against prose instead of code (Modul-11/19/20-Pitfall).
        let code = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")

        guard let saveRange = code.range(of: "try modelContext.save()") else {
            return XCTFail("revertToSnapshot() must call modelContext.save() before dismiss()")
        }
        guard let dismissRange = code.range(of: "dismiss()") else {
            return XCTFail("revertToSnapshot() must still call dismiss()")
        }
        XCTAssertTrue(saveRange.lowerBound < dismissRange.lowerBound,
                      "modelContext.save() must run BEFORE dismiss(), so a discard is actually persisted")
    }
}
