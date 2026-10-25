#if canImport(SwiftUI)
import XCTest

/// Final-review Fix 3 (laufcoaching-plan-integration, 2026-10-25):
/// `PlansListView` never got the Leitplanke-6 gating its siblings
/// (`ProfileEditorView`/`DashboardView`) already have - its single fixed
/// cardio slot checked only `CardioFeasibilityCardModel.make`, always
/// showing the full "create a new plan" preview/button even when an
/// active, eligible plan existed and Task 7's in-place-adjustment path was
/// what tapping "accept" would actually run. Source-introspection (kein
/// SwiftUI-Render-Harness in diesem Repo), gleiches Muster wie
/// `DashboardCardioCardPriorityTests`.
final class PlansListCoachAdjustmentPriorityTests: XCTestCase {

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

    func testPlansListViewReferencesCoachAdjustmentModelAndPreview() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        XCTAssertTrue(source.contains("CoachAdjustmentCardModel.make"), "PlansListView must check CoachAdjustmentCardModel.make, same as ProfileEditorView/DashboardView")
        XCTAssertTrue(source.contains("CoachAdjustmentPreviewView"), "PlansListView must be able to present CoachAdjustmentPreviewView (Task 7's in-place-adjustment path)")
    }

    /// Leitplanke 6: the `CardioFeasibilityCardModel`-driven section must
    /// only render as the FALLBACK, relative to the coach-adjustment check -
    /// same relative-position pattern as
    /// `DashboardCardioCardPriorityTests.testDashboardChecksCoachAdjustmentBeforeCardioFeasibilityInTheFixedCardSlot`.
    func testCardioFeasibilitySectionOnlyRendersAsFallback() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        guard let coachAdjustmentIndex = source.range(of: "if let adjustmentModel = coachAdjustmentModel {")?.lowerBound else {
            XCTFail("coachAdjustmentModel check not found in body"); return
        }
        guard let fallbackIndex = source.range(of: "} else if let profile = profiles.first, let model = CardioFeasibilityCardModel.make(for: profile) {")?.lowerBound else {
            XCTFail("CardioFeasibilityCardModel fallback branch not found"); return
        }
        XCTAssertLessThan(coachAdjustmentIndex, fallbackIndex, "CoachAdjustmentCardModel (active-plan case) must be checked before the CardioFeasibilityCardModel fallback")
    }

    /// Mirrors `ProfileEditorView.coachAdjustmentModel`: must gate on BOTH a
    /// profile AND an active plan, same as the Dashboard's fixed slot.
    func testCoachAdjustmentModelRequiresProfileAndActivePlan() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        guard let range = source.range(of: "private var coachAdjustmentModel: CoachAdjustmentCardModel? {") else {
            XCTFail("coachAdjustmentModel property not found"); return
        }
        let tail = source[range.upperBound...].prefix(400)
        XCTAssertTrue(tail.contains("profiles.first"), "must require a profile")
        XCTAssertTrue(tail.contains("plans.first(where: \\.isActive)") || tail.contains("plans.first(where: { $0.isActive })"), "must require an active plan")
        XCTAssertTrue(tail.contains("CoachAdjustmentCardModel.make(for:"), "must delegate to CoachAdjustmentCardModel.make")
    }
}
#endif
