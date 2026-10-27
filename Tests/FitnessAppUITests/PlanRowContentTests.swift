#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// Crash fix (TestFlight 0.1.0/175, see `PlanRowContent`'s own doc comment
/// in `PlansListView.swift`): `PlanRow` now renders from a plain-value
/// `PlanRowContent` snapshot instead of a live `TrainingPlan`, so it never
/// re-reads an `@Model` property that could be invalidated mid-deletion.
/// This test only proves the snapshot itself is accurate and stays in sync
/// with the live plan at extraction time — the crash this fixes is a
/// SwiftUI rendering-timing issue with no automated UI-test harness in this
/// repo (see the file's own extensive, device-tested fix history), so the
/// actual fix needs a real-device re-test of "delete a plan from the Plan
/// tab" to be considered confirmed.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanRowContentTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    func testContentMatchesTheLivePlanAtExtractionTime() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(
            name: "Ganzkoerper 3x",
            weeks: 8,
            isActive: true,
            targetEnvironment: .homeGym
        )
        context.insert(plan)
        context.insert(TrainingDay(name: "Tag A", weekday: 2, plan: plan))
        context.insert(TrainingDay(name: "Tag B", weekday: 4, plan: plan))
        try context.save()

        let content = PlanRowContent(plan)

        XCTAssertEqual(content.displayName, "Ganzkoerper 3x")
        XCTAssertEqual(content.isActive, true)
        XCTAssertEqual(content.daysCount, 2)
        XCTAssertEqual(content.weeks, 8)
        XCTAssertEqual(content.targetEnvironment, .homeGym)
    }

    /// `TrainingPlan.displayName` prefers `customName`, then
    /// `localizationKey`-resolved name, then falls back to the raw `name` —
    /// the snapshot must go through that same logic, not read `name`
    /// directly.
    func testContentUsesDisplayNameNotRawName() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Interner Systemname", customName: "Mein Plan")
        context.insert(plan)
        try context.save()

        let content = PlanRowContent(plan)

        XCTAssertEqual(content.displayName, "Mein Plan")
    }

    func testContentReflectsEmptyPlanAsZeroDays() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Leerer Plan")
        context.insert(plan)
        try context.save()

        XCTAssertEqual(PlanRowContent(plan).daysCount, 0)
    }
}
#endif
