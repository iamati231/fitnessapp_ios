#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// WP2 + WP3: Opens the coaching-era SQLite fixture (created by
/// CoachingEraFixtureGenerator BEFORE this test suite runs in CI) with the
/// current production schema and verifies:
///   WP2 — all non-coaching user data survived lightweight migration
///   WP3 — the migrated store remains writable (insert + re-read)
///
/// The fixture contains a UserBodyProfile with 15 coaching properties that no
/// longer exist in the current DeltiqData.UserBodyProfile schema. SwiftData's
/// lightweight migration silently drops those extra columns when opening.
///
/// Constraint (from ticket): no manually manipulated SQLite, no current
/// models pretending to be old. The fixture is a real SwiftData store written
/// by the generator target using the genuine old schema definition.
final class CoachingSchemaLightweightMigrationTests: XCTestCase {

    private static let fixturePath = "/tmp/deltiq_legacy_fixture.sqlite"

    // MARK: - WP2: Non-coaching data survives migration

    func testLegacyStoreOpensWithCurrentSchemaAndRetainsEssentialData() throws {
        guard FileManager.default.fileExists(atPath: Self.fixturePath) else {
            XCTFail(
                "Legacy fixture not found at \(Self.fixturePath). " +
                "Run CoachingEraFixtureGenerator before this test suite."
            )
            return
        }

        let profiles = try openAndFetch()
        XCTAssertEqual(profiles.count, 1,
                       "Migration must not destroy the profile row")

        let p = try XCTUnwrap(profiles.first,
                               "Profile must be fetchable after migration")

        // Essential non-coaching fields must survive
        XCTAssertEqual(p.heightCm, 178.0, accuracy: 0.001,
                       "heightCm muss nach Migration erhalten bleiben")
        XCTAssertEqual(p.profile, .male,
                       "profile muss nach Migration erhalten bleiben")
        XCTAssertEqual(p.environment, .gym,
                       "environment muss nach Migration erhalten bleiben")
        XCTAssertEqual(p.firstName, "Max",
                       "firstName muss nach Migration erhalten bleiben")
        XCTAssertEqual(p.weeklyWorkoutGoal, 3,
                       "weeklyWorkoutGoal muss nach Migration erhalten bleiben")
        // goalWeightKg is verified alive (non-nil); exact value not checked here
        // because testMigratedStoreAcceptsNewWrites modifies it to prove writability.
        XCTAssertNotNil(p.goalWeightKg,
                        "goalWeightKg muss nach Migration erhalten bleiben")
        XCTAssertEqual(p.experienceTrackRaw, "intermediate",
                       "experienceTrackRaw muss nach Migration erhalten bleiben")

        // Coaching widget types that were removed must be silently filtered
        let typed = p.activeDashboardWidgets
        XCTAssertFalse(typed.map(\.rawValue).contains("runCoachCard"),
                       "runCoachCard must be filtered by compactMap after rollback")
        XCTAssertFalse(typed.map(\.rawValue).contains("raceProgressCard"),
                       "raceProgressCard must be filtered by compactMap after rollback")
        // Surviving widget types must still be present in the raw column
        XCTAssertTrue(p.activeDashboardWidgetsRaw.contains("nextWorkout"))
        XCTAssertTrue(p.activeDashboardWidgetsRaw.contains("cardioPace"))
    }

    // MARK: - WP3: Migrated store is writable

    func testMigratedStoreAcceptsNewWrites() throws {
        guard FileManager.default.fileExists(atPath: Self.fixturePath) else {
            XCTFail(
                "Legacy fixture not found at \(Self.fixturePath). " +
                "Run CoachingEraFixtureGenerator before this test suite."
            )
            return
        }

        let newWeight = 82.5

        // Write to the migrated store (container named to keep ARC count alive)
        do {
            let (c1, ctx1) = try openContainer()
            let all = try ctx1.fetch(FetchDescriptor<UserBodyProfile>())
            let pw = try XCTUnwrap(all.first)
            pw.goalWeightKg = newWeight
            try ctx1.save()
            _ = c1
        }

        // Re-open and verify the write persisted
        let (c2, ctx2) = try openContainer()
        let profiles2 = try ctx2.fetch(FetchDescriptor<UserBodyProfile>())
        let p2 = try XCTUnwrap(profiles2.first)
        XCTAssertEqual(p2.goalWeightKg ?? 0, newWeight, accuracy: 0.001,
                       "Write after migration must persist across store re-opens")
        _ = c2
    }

    // MARK: - Helpers

    private func openContainer() throws -> (ModelContainer, ModelContext) {
        let url = URL(fileURLWithPath: Self.fixturePath)
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: schema, configurations: config)
        return (container, ModelContext(container))
    }

    private func openAndFetch() throws -> [UserBodyProfile] {
        let (c, ctx) = try openContainer()
        let result = try ctx.fetch(FetchDescriptor<UserBodyProfile>())
        _ = c
        return result
    }
}
#endif
