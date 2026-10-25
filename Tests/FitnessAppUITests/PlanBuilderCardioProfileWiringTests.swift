#if canImport(SwiftUI)
import XCTest

/// Task 6 (Laufcoaching-Plan-Integration, Requirement A): `currentInput`s
/// `GoalDrivenPlanSelectionBuilder.makeSelections`-Aufruf (goal-driven Branch)
/// ist die EINZIGE Produktionsstelle, die `cardioRunProfile` befuellt - ohne
/// diese Verdrahtung hat der in frueheren Tasks gebaute Lauf-Coach keine
/// Wirkung. Source-introspection (kein SwiftUI-Render-Harness in diesem
/// Repo), gleiches Muster wie `MehrInformationArchitectureTests`.
final class PlanBuilderCardioProfileWiringTests: XCTestCase {

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

    func testCurrentInputPassesCardioRunProfileWhenCoachIsEnabled() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")
        guard let range = source.range(of: "private var currentInput: PlanGeneratorInput {") else {
            XCTFail("currentInput not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: range.upperBound))
        XCTAssertTrue(block.contains("cardioRunProfile:"), "GoalDrivenPlanSelectionBuilder.makeSelections must receive a cardio profile")
        XCTAssertTrue(block.contains("cardioCoachingEnabled"), "the profile must only be built when the coach is actually enabled")
    }

    /// Final-review Fix 4: `updateConfig`/`updateTimeFormat` rebuild a
    /// `PlanGeneratorTypeSelection` field-by-field from `current` and already
    /// preserve `current.timeFormat` explicitly (README 2.35) - they missed
    /// doing the same for `current.cardioRunProfile` (added later, Task
    /// 3/4), so editing days/duration/experience/time-format on an existing
    /// selection silently wiped the pace baseline back to "nach Gefuehl".
    func testUpdateHelpersPreserveCardioRunProfile() throws {
        let source = try contents(of: "Workout/PlanBuilderView.swift")

        guard let updateConfigRange = source.range(of: "private func updateConfig(") else {
            XCTFail("updateConfig not found"); return
        }
        guard let updateConfigBraceRange = source.range(of: "{", range: updateConfigRange.upperBound..<source.endIndex) else {
            XCTFail("updateConfig body not found"); return
        }
        let updateConfigBody = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: updateConfigBraceRange.upperBound))
        XCTAssertTrue(updateConfigBody.contains("cardioRunProfile: current.cardioRunProfile"), "updateConfig must preserve the existing cardioRunProfile")

        guard let updateTimeFormatRange = source.range(of: "private func updateTimeFormat(") else {
            XCTFail("updateTimeFormat not found"); return
        }
        guard let updateTimeFormatBraceRange = source.range(of: "{", range: updateTimeFormatRange.upperBound..<source.endIndex) else {
            XCTFail("updateTimeFormat body not found"); return
        }
        let updateTimeFormatBody = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: updateTimeFormatBraceRange.upperBound))
        XCTAssertTrue(updateTimeFormatBody.contains("cardioRunProfile: current.cardioRunProfile"), "updateTimeFormat must preserve the existing cardioRunProfile")
    }
}
#endif
