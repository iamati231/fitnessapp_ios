#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Phase B (Laufcoaching Dual-Path, Task 5): this is a MODEL-DEFAULT-AND-
/// PERSISTENCE test, explicitly NOT a migration test — it proves the new
/// `TrainingDay.isAutoFilledPlaceholder` field's default works and round-
/// trips through a real `ModelContainer`, nothing more. It does NOT prove an
/// on-disk store created before this field existed opens/migrates correctly
/// (no test in this project proves that for any comparable field — the
/// automatic lightweight migration is a documented assumption, not a tested
/// one). Same `ModelContainer`/`Schema(AppSchema.types)`/
/// `ModelConfiguration(isStoredInMemoryOnly: true)` setup as
/// `ExperienceTrackBackfillTests.setUpWithError()`.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class TrainingDayIsAutoFilledPlaceholderDefaultTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    private var context: ModelContext { container.mainContext }

    func test_modelContainer_trainingDayWithoutExplicitFlag_defaultsToFalse() throws {
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        // Deliberately NOT passing `isAutoFilledPlaceholder` — exercises the
        // init's default, same as every pre-existing call site.
        let day = TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: plan)
        context.insert(day)
        try context.save()

        let dayID = day.persistentModelID
        let descriptor = FetchDescriptor<TrainingDay>()
        let refetched = try context.fetch(descriptor)
        let found = try XCTUnwrap(refetched.first { $0.persistentModelID == dayID })

        XCTAssertFalse(found.isAutoFilledPlaceholder)
    }
}
#endif
