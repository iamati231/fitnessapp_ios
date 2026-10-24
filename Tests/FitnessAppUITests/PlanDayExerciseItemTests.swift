#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// Crash fix (real-device TestingBot crash log, "letzten Plan loeschen"):
/// `DashboardView.planDayCard` now renders its exercise list from a plain-
/// value `PlanDayExerciseItem` snapshot instead of reading the live
/// `TrainingDay.activeExercises` relationship inside a nested ViewBuilder
/// closure — the real crash log showed SwiftUI/Observation re-invoking that
/// nested closure independently, hitting a Fatal Error on an already-
/// invalidated `Exercise` once the owning `TrainingDay` is mid-deletion.
/// This test only proves the snapshot's sort/mapping is correct — the fix
/// itself is a SwiftUI rendering-timing issue with no automated UI-test
/// harness in this repo, so it still needs a real-device re-test of
/// "delete the last/only plan" to be considered confirmed.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanDayExerciseItemTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    func testMakeListSortsByOrderIndexRegardlessOfInputOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let second = Exercise(name: "Kniebeuge", orderIndex: 1)
        let first = Exercise(name: "Bankdruecken", orderIndex: 0)
        let third = Exercise(name: "Kreuzheben", orderIndex: 2)
        context.insert(second)
        context.insert(first)
        context.insert(third)
        try context.save()

        let items = DashboardView.PlanDayExerciseItem.makeList(from: [second, first, third])

        XCTAssertEqual(items.map(\.displayName), ["Bankdruecken", "Kniebeuge", "Kreuzheben"])
    }

    func testMakeListPreservesPersistentIdentityAsID() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Klimmzug", orderIndex: 0)
        context.insert(exercise)
        try context.save()

        let items = DashboardView.PlanDayExerciseItem.makeList(from: [exercise])

        XCTAssertEqual(items.first?.id, exercise.persistentModelID)
    }

    func testMakeListOnEmptyInputIsEmpty() {
        XCTAssertTrue(DashboardView.PlanDayExerciseItem.makeList(from: []).isEmpty)
    }
}
#endif
