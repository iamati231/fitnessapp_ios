import XCTest
#if canImport(SwiftUI)
@testable import FitnessAppUI

/// Final whole-branch review (fix round 1), Finding 1 (Important): since
/// main-navigation Task 1 made `NutritionDayView` a long-lived `TabView` tab
/// root (`isTabRoot: true` in `RootView.MainTabView`), SwiftUI keeps the view
/// alive across tab switches instead of recreating it — so `selectedDate`
/// (a plain `@State` initialized once to `Date()`) never reset back to today
/// after the user browsed to an earlier day, switched tabs, and returned.
/// That violated the spec's "Standarddatum: heute" and silently logged new
/// meals under the stale date.
///
/// `NutritionDayView.body` is a private, opaque `some View` property with no
/// runtime surface to assert against without a SwiftUI render harness, which
/// this package doesn't have — same situation `MainTabStructureTests` and
/// `DashboardNutritionCardTabSwitchTests` already document. These tests read
/// the source file directly, the established pattern in this suite.
@available(iOS 17.0, macOS 14.0, *)
final class NutritionDayViewTabReentryResetTests: XCTestCase {

    private var nutritionDayViewSource: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // this file
                .deletingLastPathComponent() // FitnessAppUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/FitnessAppUI/Nutrition/NutritionDayView.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    /// Isolates `body`'s modifier chain (from `.deltiqSwipeBackEnabled()` —
    /// the last modifier before where the fix was added — up to the first
    /// `.sheet(` call) so assertions can't accidentally match an unrelated
    /// `isTabRoot`/`selectedDate` reference elsewhere in the file (e.g. the
    /// `changeDay(by:)` action or the type-level doc comment).
    private func bodyModifierTail(in source: String) throws -> String {
        guard let start = source.range(of: ".deltiqSwipeBackEnabled()") else {
            XCTFail("could not find .deltiqSwipeBackEnabled() in NutritionDayView.body")
            return ""
        }
        guard let end = source.range(of: ".sheet(", range: start.upperBound..<source.endIndex) else {
            XCTFail("could not find the first .sheet( modifier after .deltiqSwipeBackEnabled()")
            return ""
        }
        return String(source[start.upperBound..<end.lowerBound])
    }

    func testOnAppearResetsSelectedDateToTodayGatedByIsTabRoot() throws {
        let tail = try bodyModifierTail(in: try nutritionDayViewSource)
        XCTAssertTrue(
            tail.contains(".onAppear"),
            "body must gain an .onAppear hook to catch tab (re-)entry."
        )
        XCTAssertTrue(
            tail.contains("if isTabRoot {") && tail.contains("selectedDate = Date()"),
            "the .onAppear reset must be gated by isTabRoot and reset selectedDate to today."
        )
    }

    /// The reset must be scoped to the `.onAppear` hook specifically — not
    /// added to `.task(id: insightContext)` (which also re-runs on every
    /// day-change, i.e. far more often than tab re-entry) or to any other
    /// always-running hook, since the brief explicitly calls out that a
    /// sheet/pushed-child's `.onAppear` would be the wrong place and the fix
    /// must not reset on every body re-render.
    func testResetIsScopedToOnAppearNotToTaskOrSheets() throws {
        let source = try nutritionDayViewSource
        guard let onAppearStart = source.range(of: ".onAppear {") else {
            XCTFail(".onAppear hook not found")
            return
        }
        guard let onAppearEnd = source.range(of: "\n        }", range: onAppearStart.upperBound..<source.endIndex) else {
            XCTFail("could not find end of .onAppear block")
            return
        }
        let onAppearBlock = String(source[onAppearStart.lowerBound..<onAppearEnd.upperBound])
        XCTAssertTrue(
            onAppearBlock.contains("selectedDate = Date()"),
            "selectedDate reset must live inside the .onAppear block itself."
        )

        // `.task(id: insightContext)` must remain untouched by this fix —
        // it must not also reset selectedDate (that would defeat its own
        // cancellation-on-day-change logic and reset far too often).
        guard let taskStart = source.range(of: ".task(id: insightContext) {") else {
            XCTFail(".task(id: insightContext) not found")
            return
        }
        guard let taskEnd = source.range(of: ".sheet(", range: taskStart.upperBound..<source.endIndex) else {
            XCTFail("could not find end of .task(id: insightContext) block")
            return
        }
        let taskBlock = String(source[taskStart.upperBound..<taskEnd.lowerBound])
        XCTAssertFalse(
            taskBlock.contains("selectedDate = Date()"),
            ".task(id: insightContext) must not also reset selectedDate — the fix belongs only in .onAppear."
        )
    }
}
#endif
