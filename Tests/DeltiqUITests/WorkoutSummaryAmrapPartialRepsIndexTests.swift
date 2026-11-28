import XCTest

/// Audit-Fund (Modul (e), WorkoutSummaryView). `amrapExerciseTotals(_:)` glich
/// die angebrochene AMRAP-Station bisher NUR ueber `partialRepsExerciseName`
/// (reiner Namens-Snapshot) ab - bei zwei gleichnamigen Zirkel-Stationen traf
/// `firstIndex { displayName == name }` immer die ERSTE, selbst wenn die
/// Restwiederholungen tatsaechlich zur ZWEITEN gehoerten.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class WorkoutSummaryAmrapPartialRepsIndexTests: XCTestCase {
    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    func testWorkoutSessionHasPartialRepsExerciseIndexField() throws {
        let text = try source("Sources/DeltiqData/WorkoutSession.swift")
        XCTAssertTrue(text.contains("public var partialRepsExerciseIndex: Int?"),
                      "WorkoutSession must carry an orderIndex snapshot alongside the name snapshot")
    }

    func testTimedWorkoutPlayerSetsIndexAlongsideName() throws {
        let text = try source("Sources/DeltiqUI/Workout/TimedWorkoutPlayerView.swift")
        guard let nameRange = text.range(of: "session.partialRepsExerciseName = partialReps > 0 ? partialRepsExercise?.displayName : nil") else {
            return XCTFail("saveNow() no longer sets partialRepsExerciseName at the expected line")
        }
        let afterName = text[nameRange.upperBound...]
        guard let firstNewline = afterName.range(of: "\n") else {
            return XCTFail("could not find end of line after partialRepsExerciseName assignment")
        }
        let afterFirstLine = afterName[firstNewline.upperBound...]
        guard let secondNewline = afterFirstLine.range(of: "\n") else {
            return XCTFail("could not find end of the following line")
        }
        let nextLine = afterFirstLine[afterFirstLine.startIndex..<secondNewline.lowerBound]
        XCTAssertTrue(nextLine.contains("session.partialRepsExerciseIndex = partialReps > 0 ? partialRepsExercise?.orderIndex : nil"),
                      "saveNow() must set partialRepsExerciseIndex on the very next line, mirroring the name snapshot")
    }

    func testAmrapExerciseTotalsPrefersIndexOverName() throws {
        let text = try source("Sources/DeltiqUI/Workout/WorkoutSummaryView.swift")
        guard let start = text.range(of: "private func amrapExerciseTotals(_ exercises: [TimedFormatDisplayExercise]) -> [Int: Int]? {") else {
            return XCTFail("amrapExerciseTotals(_:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of amrapExerciseTotals(_:) not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        let code = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")

        XCTAssertTrue(code.contains("session.partialRepsExerciseIndex"),
                      "the function must consult partialRepsExerciseIndex")
        guard let indexCheckRange = code.range(of: "if let orderIndex = session.partialRepsExerciseIndex") else {
            return XCTFail("index-based lookup branch not found")
        }
        guard let nameFallbackRange = code.range(of: "session.partialRepsExerciseName.flatMap") else {
            return XCTFail("name-based fallback branch not found")
        }
        XCTAssertTrue(indexCheckRange.lowerBound < nameFallbackRange.lowerBound,
                      "the index check must be attempted BEFORE falling back to the name comparison")
    }
}
