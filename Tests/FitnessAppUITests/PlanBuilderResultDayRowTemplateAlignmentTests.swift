#if canImport(SwiftUI)
import XCTest

/// UI-Ticket ("Plan Bauen Schritt 3: Template-Layout und
/// Übungsalternativen"). Source-introspection test (no SwiftUI render
/// harness in this repo - same pattern as `OnlineFoodLookupFlowTests`):
///
/// 1. `resultDayRow`'s per-exercise row must match
///    `ProgramTemplatePickerView.dayCard`'s typography/spacing/divider
///    exactly, not an invented alternative.
/// 2. Every exercise row must offer an "Alternative wählen" action.
/// 3. The alternative dialog/toast wiring must exist and gate on the day's
///    time format (AMRAP/EMOM/Auf Zeit stay excluded, same as
///    `ExerciseSubstitutionEngine.isEligibleForSubstitution`).
final class PlanBuilderResultDayRowTemplateAlignmentTests: XCTestCase {

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

    /// Finds `marker` (any unique, stable prefix of a function's signature)
    /// and brace-matches the body of the first function whose signature
    /// starts there. `marker` may already include the trailing opening `{`
    /// (for a single-line signature) or stop right before it (letting this
    /// helper find it, for a signature whose parameter list wraps across
    /// lines) - either way the SAME brace is used as the body's start, never
    /// one found by scanning further forward (which would silently pick up
    /// the function's first NESTED brace, e.g. an early `if`/`guard`, as a
    /// false start).
    private func functionBody(startingAt marker: String, in source: String) throws -> String {
        guard let markerRange = source.range(of: marker) else {
            XCTFail("\(marker) not found")
            return ""
        }
        let openBraceIndex: String.Index
        if marker.trimmingCharacters(in: .whitespaces).hasSuffix("{") {
            openBraceIndex = source.index(before: markerRange.upperBound)
        } else {
            guard let found = source[markerRange.upperBound...].firstIndex(of: "{") else {
                XCTFail("no opening brace found after \(marker)")
                return ""
            }
            openBraceIndex = found
        }
        guard let body = Self.matchingBraceBlock(in: source, afterOpenBrace: source.index(after: openBraceIndex)) else {
            XCTFail("could not brace-match the body following \(marker)")
            return ""
        }
        return body
    }

    // MARK: 1. Typography/spacing/divider match the template's dayCard

    func testExerciseRowUsesTheSameTypographyAsTheTemplateDayCard() throws {
        let resultDayRowBody = try functionBody(
            startingAt: "private func resultDayRow(_ day: DraftDay, loadLevel: PlanLoadLevel?) -> some View {",
            in: try contents(of: "Workout/PlanBuilderView.swift")
        )
        let dayCardBody = try functionBody(
            startingAt: "private func dayCard(_ day: DaySpec) -> some View {",
            in: try contents(of: "Workout/ProgramTemplatePickerView.swift")
        )
        for sharedStyleToken in [
            ".font(.body.weight(.medium))", ".foregroundStyle(Color.primary)",
            ".font(.caption)", ".foregroundStyle(Color.Deltiq.textSecondary)",
            ".padding(.horizontal, 14)", ".padding(.vertical, 10)",
            "Color.Deltiq.divider",
        ] {
            XCTAssertTrue(dayCardBody.contains(sharedStyleToken), "sanity check: template itself should contain \(sharedStyleToken)")
            XCTAssertTrue(
                resultDayRowBody.contains(sharedStyleToken),
                "resultDayRow must reuse the template's own \(sharedStyleToken), not an invented alternative"
            )
        }
        XCTAssertTrue(resultDayRowBody.contains("detailLine(for: draftExercise.spec, dayFormat: spec.timeFormat)"))
    }

    // MARK: 2. Every exercise offers "Alternative wählen"

    func testEveryExerciseRowOffersAnAlternativeAction() throws {
        let resultDayRowBody = try functionBody(
            startingAt: "private func resultDayRow(_ day: DraftDay, loadLevel: PlanLoadLevel?) -> some View {",
            in: try contents(of: "Workout/PlanBuilderView.swift")
        )
        XCTAssertTrue(
            resultDayRowBody.contains("presentExerciseAlternatives("),
            "each exercise row must trigger the per-exercise alternative picker"
        )
        XCTAssertTrue(resultDayRowBody.contains("exerciseID: draftExercise.id"), "the stable DraftExerciseID must be passed, not an array index")
    }

    // MARK: 3. Dialog gates on the day's time format, matches toast wiring

    func testPresentExerciseAlternativesExcludesTimedFormatDaysAndShowsAnUnderstandableHint() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        let body = try functionBody(startingAt: "private func presentExerciseAlternatives(", in: source)
        XCTAssertTrue(body.contains("dayFormat == nil"), "AMRAP/EMOM/Auf Zeit days must stay excluded, same as ExerciseSubstitutionEngine")
        XCTAssertTrue(body.contains("guard !candidates.isEmpty else"), "an empty result must show the no-alternatives hint, not silently do nothing")
        XCTAssertTrue(body.contains("planBuilder.result.noExerciseAlternatives.toast"))
    }

    func testApplyExerciseAlternativeOnlyTouchesTheTargetedExerciseViaPlanDraft() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        let body = try functionBody(
            startingAt: "private func applyExerciseAlternative(_ alternative: ExerciseTemplateSpec, to target: ExerciseAlternativeTarget) {",
            in: source
        )
        XCTAssertTrue(body.contains("ExerciseAlternativeFinder.adjustedSpec"), "sets/reps/rest must be checked for fit, not copied blindly")
        XCTAssertTrue(body.contains("currentDraft.replaceExercise("), "must delegate to PlanDraft's single-exercise replacement")
    }
}
#endif
