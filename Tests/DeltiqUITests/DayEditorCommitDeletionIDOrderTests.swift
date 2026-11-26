import XCTest

/// Audit-Fund (Modul 21, Plan-Builder/Editor). `commitExerciseDeletion(exercises:snapshot:)`
/// gab die geloeschten IDs aus `pendingExerciseDeleteIDs` frei, BEVOR der
/// `modelContext.save()` ueberhaupt versucht wurde - `orderedExercises` zeigt
/// eine Uebung aber wieder an, sobald ihre ID nicht mehr in
/// `pendingExerciseDeleteIDs` steht. Bei einem Save-Fehlschlag erscheint die
/// eigentlich geloeschte Uebung dadurch sofort wieder, obwohl sie im
/// `modelContext` bereits als geloescht vorgemerkt ist.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe DayEditorSaveErrorHandlingTests).
final class DayEditorCommitDeletionIDOrderTests: XCTestCase {
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

    func testPendingDeleteIDsAreOnlyReleasedAfterSuccessfulSave() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private func commitExerciseDeletion(exercises: [Exercise], snapshot: [Exercise]) {") else {
            return XCTFail("commitExerciseDeletion not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of commitExerciseDeletion not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let saveRange = body.range(of: "try modelContext.save()") else {
            return XCTFail("must call modelContext.save() in a do/catch")
        }
        guard let catchRange = body.range(of: "} catch {", range: saveRange.upperBound..<body.endIndex) else {
            return XCTFail("catch block not found")
        }
        guard let removeRange = body.range(of: "pendingExerciseDeleteIDs.remove(id)") else {
            return XCTFail("pendingExerciseDeleteIDs.remove(id) not found")
        }

        XCTAssertTrue(removeRange.lowerBound > saveRange.upperBound,
                      "pendingExerciseDeleteIDs must only be released AFTER modelContext.save() is attempted, not before")
        XCTAssertTrue(removeRange.upperBound < catchRange.lowerBound,
                      "pendingExerciseDeleteIDs must be released on the success path (inside the do block, before catch), not unconditionally")
    }
}
