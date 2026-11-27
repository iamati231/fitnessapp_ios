import XCTest

/// Audit-Fund (Modul 21, Plan-Builder/Editor-Follow-up): `revertToSnapshot()`
/// war die einzige mutierende Aktion in dieser Datei ohne ein explizites
/// `modelContext.save()` - ein zwischenzeitlicher impliziter Autosave
/// (App-Hintergrund) konnte den eigentlich verworfenen Wert ueberleben.
/// Quelltext-Pruefung, da `revertToSnapshot()` `private` ist und reines
/// SwiftUI-View-Verhalten ohne Test-Seam fuer einen echten Save-Fehlschlag.
final class DayEditorRevertSnapshotSaveTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/DayEditorView.swift"),
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

    func testRevertToSnapshotSavesBeforeDismissing() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private func revertToSnapshot() {") else {
            return XCTFail("revertToSnapshot() not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of revertToSnapshot() not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let saveRange = body.range(of: "modelContext.save()") else {
            return XCTFail("revertToSnapshot() must save the reverted state, not just mutate it in memory")
        }
        guard let dismissRange = body.range(of: "dismiss()") else {
            return XCTFail("dismiss() not found")
        }
        XCTAssertTrue(saveRange.upperBound < dismissRange.lowerBound,
                      "the save must happen before dismiss(), not after")
    }
}
