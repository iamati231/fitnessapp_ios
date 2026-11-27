import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor): `revertToSnapshot()`
/// schrieb den verworfenen Zustand nur in den Live-`modelContext`, ohne
/// `modelContext.save()` - ein zwischenzeitlicher impliziter Autosave
/// (App-Hintergrund) konnte den eigentlich verworfenen Wert ueberleben,
/// analog zu den bereits gefixten `DayEditorView`/`PlanEditorView`-Pendants.
/// Quelltext-Pruefung, da `revertToSnapshot()` `private` ist und reines
/// SwiftUI-View-Verhalten ohne Test-Seam fuer einen echten Save-Fehlschlag.
final class ExerciseEditorRevertSnapshotSaveTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ExerciseEditorView.swift"),
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

    func testRevertToSnapshotSavesTheRevertedState() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private func revertToSnapshot() {") else {
            return XCTFail("revertToSnapshot() not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of revertToSnapshot() not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains("modelContext.save()"),
                      "revertToSnapshot() must save the reverted state, not just mutate it in memory - " +
                      "otherwise a backgrounded-app autosave racing the discard can resurrect the discarded value")
    }

    func testCallSiteStillRevertsBeforeDismissing() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let confirmRange = cleaned.range(of: ".discardChangesConfirmation(isPresented: $showingDiscardConfirm) {") else {
            return XCTFail("discardChangesConfirmation call site not found")
        }
        guard let end = cleaned.range(of: "\n        }", range: confirmRange.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of discardChangesConfirmation closure not found")
        }
        let closureBody = cleaned[confirmRange.upperBound..<end.lowerBound]

        guard let revertRange = closureBody.range(of: "revertToSnapshot()") else {
            return XCTFail("revertToSnapshot() call not found in discard closure")
        }
        guard let dismissRange = closureBody.range(of: "dismiss()") else {
            return XCTFail("dismiss() call not found in discard closure")
        }
        XCTAssertTrue(revertRange.upperBound < dismissRange.lowerBound,
                      "revertToSnapshot() must still run before dismiss() at the call site, " +
                      "so its internal save completes before the sheet closes")
    }
}
