#if canImport(SwiftUI)
import XCTest

/// UI-Ticket "Platzoptimierung Schritt 3": `resultDayRow`'s per-exercise row
/// used to put the exercise name and the FULL detail phrase ("3 Sätze •
/// 8-12 Wdh • 90s Pause") side by side with a `Spacer` between them - a long
/// name left too little room, so both sides wrapped and each exercise took
/// 2-3 lines. Source-introspection test (no SwiftUI render harness in this
/// repo - same pattern as `OnlineFoodLookupFlowTests`/
/// `DeltiqSegmentedPickerScalesDownInsteadOfWrappingTests`): verifies the new
/// compact layout structurally, since a real build/preview isn't available
/// in this environment either.
final class PlanBuilderResultDayRowCompactLayoutTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func matchingBraceBlock(in source: String, afterOpenBrace start: String.Index) -> String? {
        var depth = 1
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char == "{" { depth += 1 } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    /// Locates `exerciseDetailRow`'s own function body via its signature
    /// string, the same technique `OnlineFoodLookupFlowTests` uses for
    /// `onlineSearchFallback`.
    private func exerciseDetailRowBody(in source: String) throws -> String {
        guard let signatureRange = source.range(of: "private func exerciseDetailRow(for exercise: ExerciseSpec, dayFormat: WorkoutTimeFormat?) -> some View {") else {
            XCTFail("exerciseDetailRow not found")
            return ""
        }
        guard let body = Self.matchingBraceBlock(in: source, afterOpenBrace: signatureRange.upperBound) else {
            XCTFail("could not brace-match exerciseDetailRow's body")
            return ""
        }
        return body
    }

    func testExerciseNameNoLongerCompetesWithDetailTextForWidthViaASpacer() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        guard let rowRange = source.range(of: "private func resultDayRow(_ day: DraftDay, loadLevel: PlanLoadLevel?) -> some View {") else {
            XCTFail("resultDayRow not found")
            return
        }
        guard let body = Self.matchingBraceBlock(in: source, afterOpenBrace: rowRange.upperBound) else {
            XCTFail("could not brace-match resultDayRow's body")
            return
        }
        XCTAssertFalse(
            body.contains("Spacer(minLength: 8)"),
            "the exercise name must no longer be squeezed against the detail text by a Spacer"
        )
        XCTAssertTrue(
            body.contains("exerciseDetailRow(for: exercise, dayFormat: spec.timeFormat)"),
            "resultDayRow must delegate the per-exercise detail line to exerciseDetailRow"
        )
    }

    /// Core of the fix: a plain strength exercise (no `dayFormat`, not
    /// cardio) must show the rest time via a `timer` icon, never the old
    /// "90s Pause"/"rest"/"mola"-style combined text.
    func testStrengthExerciseShowsRestAsATimerIconNotTheOldCombinedPhrase() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        let body = try exerciseDetailRowBody(in: source)
        XCTAssertTrue(body.contains("setsRepsText(for: exercise)"), "sets/reps must use the no-rest-clause variant")
        XCTAssertTrue(body.contains("systemImage: \"timer\""), "rest time must be shown via a timer icon")
        XCTAssertTrue(body.contains("\\(exercise.restSeconds)s"), "the timer icon must still show the real rest-seconds number")
    }

    /// Cardio and timed-format (AMRAP/EMOM/Auf Zeit) days must keep using
    /// the existing, already-compact `detailLine` — this ticket's reported
    /// clutter is specific to multi-exercise strength days.
    func testCardioAndTimedDaysStillUseTheExistingDetailLine() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        let body = try exerciseDetailRowBody(in: source)
        XCTAssertTrue(
            body.contains("dayFormat != nil || exercise.isCardio") && body.contains("detailLine(for: exercise, dayFormat: dayFormat)"),
            "cardio/timed-format exercises must still render via detailLine unchanged"
        )
    }
}
#endif
