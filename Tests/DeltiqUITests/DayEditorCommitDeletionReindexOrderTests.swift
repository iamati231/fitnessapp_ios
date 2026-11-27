import XCTest

/// Audit-Fund (Modul 21, DayEditorView): `commitExerciseDeletion` renummerierte
/// `orderIndex` anhand der Element-Position im beim Swipe eingefrorenen
/// `snapshot`-Array statt anhand des aktuellen `orderIndex` - ein Drag&Drop-
/// Reorder (`moveExercises`) waehrend des 3s-Undo-Fensters einer anderen,
/// bereits geloeschten Uebung wurde dadurch beim spaeteren Commit wieder auf
/// die alte, vor dem Loeschen gueltige Reihenfolge zurueckgesetzt.
final class DayEditorCommitDeletionReindexOrderTests: XCTestCase {
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

    func testCommitExerciseDeletionReindexesByCurrentOrderIndexNotSnapshotPosition() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private func commitExerciseDeletion(exercises: [Exercise], snapshot: [Exercise]) {") else {
            return XCTFail("commitExerciseDeletion(exercises:snapshot:) not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of commitExerciseDeletion not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        guard let filterRange = body.range(of: "let remaining = snapshot") else {
            return XCTFail("expected remaining to still be derived from snapshot")
        }
        guard let enumerateRange = body.range(of: "remaining.enumerated()", range: filterRange.upperBound..<body.endIndex) else {
            return XCTFail("expected the re-index loop over remaining.enumerated()")
        }
        let between = body[filterRange.upperBound..<enumerateRange.lowerBound]
        XCTAssertTrue(between.contains(".sorted") && between.contains("orderIndex"),
                      "remaining must be re-sorted by the current orderIndex before re-numbering - otherwise a concurrent drag reorder during the undo window gets silently reverted on commit")
    }
}
