#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Full integration proof for the coaching-era lightweight migration.
///
/// Covers WP2 + WP3 + WP4 + WP5 from DEL-migration-proof ticket.
///
/// **WP2 — Entity identity proof**
/// The fixture was created by CoachingEraFixtureEnricher using a *local*
/// private class named `UserBodyProfile` (with 15 coaching columns). SwiftData
/// derives the SQLite entity name from the UNQUALIFIED class name, so the
/// fixture's entity name is "UserBodyProfile" — identical to
/// `DeltiqData.UserBodyProfile`. When this test opens the fixture with
/// `Schema(AppSchema.types)` (which references the production type), SwiftData
/// finds the matching entity by name, performs lightweight migration (drops the
/// coaching columns), and returns live objects — implicit identity proof.
///
/// **WP3 — Test isolation**
/// The fixture is copied to a unique per-test temporary directory. Each test
/// starts from an independent store, so execution order and parallelism cannot
/// cause interference.
///
/// **WP4 — Data integrity after migration**
/// All entity types written by the enricher are verified: counts, field values,
/// and relationships.
///
/// **WP5 — Write-reopen verification**
/// After checking migrated data the test writes new values, closes the
/// container (releasing ARC → WAL checkpoint), reopens, and verifies persistence.
///
/// Constraint: fixture is a real SwiftData store written by the generator +
/// enricher. No manual SQLite manipulation, no current models pretending to be
/// legacy.
final class CoachingSchemaLightweightMigrationTests: XCTestCase {

    // Path to the fixture produced by CI step "Coaching-Era Legacy-Fixture erzeugen".
    private static let sourcePath = "/tmp/deltiq_legacy_fixture.sqlite"

    // MARK: - WP2 + WP3 + WP4 + WP5: single sequential integration test

    func testFullMigrationIntegrity() throws {
        // WP3: copy to per-test temp dir — no shared mutable state between runs
        let url = try copyFixtureToTempDir()

        // ── Open: triggers lightweight migration on UserBodyProfile ──────────
        let (c1, ctx1) = try openContainer(at: url)

        // WP4: UserBodyProfile — non-coaching fields survived migration
        let profiles = try ctx1.fetch(FetchDescriptor<UserBodyProfile>())
        XCTAssertEqual(profiles.count, 1,
                       "UserBodyProfile row must survive migration")
        let p = try XCTUnwrap(profiles.first)
        XCTAssertEqual(p.heightCm,            178.0,          accuracy: 0.001)
        XCTAssertEqual(p.profile,             .male)
        XCTAssertEqual(p.environment,         .gym)
        XCTAssertEqual(p.firstName,           "Max")
        XCTAssertEqual(p.weeklyWorkoutGoal,   3)
        XCTAssertNotNil(p.goalWeightKg,       "goalWeightKg must survive")
        XCTAssertEqual(p.experienceTrackRaw,  "intermediate")

        // Coaching widget types that were removed must be silently filtered
        let typed = p.activeDashboardWidgets
        XCTAssertFalse(typed.map(\.rawValue).contains("runCoachCard"),
                       "runCoachCard must be filtered after rollback")
        XCTAssertFalse(typed.map(\.rawValue).contains("raceProgressCard"),
                       "raceProgressCard must be filtered after rollback")
        XCTAssertTrue(p.activeDashboardWidgetsRaw.contains("nextWorkout"))
        XCTAssertTrue(p.activeDashboardWidgetsRaw.contains("cardioPace"))

        // WP4: TrainingPlan
        let plans = try ctx1.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(plans.count, 1, "TrainingPlan count")
        XCTAssertEqual(plans.first?.name, "Hypertrophie 12 Wochen")

        // WP4: WorkoutSession
        let sessions = try ctx1.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1, "WorkoutSession count")
        XCTAssertTrue(sessions.first?.isCompleted == true)

        // WP4: ExerciseLog
        let logs = try ctx1.fetch(FetchDescriptor<ExerciseLog>())
        XCTAssertEqual(logs.count, 1, "ExerciseLog count")
        XCTAssertEqual(logs.first?.weight ?? 0, 100.0, accuracy: 0.001)

        // WP4: BodyMeasurement
        let measurements = try ctx1.fetch(FetchDescriptor<BodyMeasurement>())
        XCTAssertEqual(measurements.count, 1, "BodyMeasurement count")
        XCTAssertEqual(measurements.first?.weightKg ?? 0, 80.0, accuracy: 0.001)

        // WP4: MealEntry + MealItem (relationship)
        let meals = try ctx1.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(meals.count, 1, "MealEntry count")
        XCTAssertEqual(meals.first?.items.count, 1, "MealItem count via relationship")

        // WP4: WaterEntry
        let waters = try ctx1.fetch(FetchDescriptor<WaterEntry>())
        XCTAssertEqual(waters.count, 1, "WaterEntry count")
        XCTAssertEqual(waters.first?.amountMl, 500)

        // WP4: PersonalRecordEntry
        let prs = try ctx1.fetch(FetchDescriptor<PersonalRecordEntry>())
        XCTAssertEqual(prs.count, 1, "PersonalRecordEntry count")
        XCTAssertEqual(prs.first?.exerciseName, "Bankdrücken")
        XCTAssertEqual(prs.first?.kindRaw, "heaviestWeight")

        // WP4: Gear
        let gears = try ctx1.fetch(FetchDescriptor<Gear>())
        XCTAssertEqual(gears.count, 1, "Gear count")
        XCTAssertEqual(gears.first?.name, "Nike Metcon 9")

        // ── WP5: write new data, close container (WAL checkpoint) ────────────
        p.goalWeightKg = 82.5
        let extraWater = WaterEntry(date: Date(), amountMl: 300)
        ctx1.insert(extraWater)
        try ctx1.save()
        _ = c1  // keep ARC alive until here; deinit checkpoints WAL

        // ── WP5: reopen and verify persistence ───────────────────────────────
        let (c2, ctx2) = try openContainer(at: url)
        let profiles2 = try ctx2.fetch(FetchDescriptor<UserBodyProfile>())
        let p2 = try XCTUnwrap(profiles2.first)
        XCTAssertEqual(p2.goalWeightKg ?? 0, 82.5, accuracy: 0.001,
                       "Written goalWeightKg must persist across store re-open")

        let waters2 = try ctx2.fetch(FetchDescriptor<WaterEntry>())
        XCTAssertEqual(waters2.count, 2,
                       "New WaterEntry must persist across store re-open")
        _ = c2
    }

    // MARK: - Helpers

    /// Copies the fixture SQLite (and WAL/SHM sidecar files if present)
    /// to an isolated temporary directory and returns the new SQLite URL.
    private func copyFixtureToTempDir() throws -> URL {
        guard FileManager.default.fileExists(atPath: Self.sourcePath) else {
            throw XCTSkip(
                "Legacy fixture not found at \(Self.sourcePath). " +
                "Run CoachingEraFixtureGenerator + CoachingEraFixtureEnricher before this test suite."
            )
        }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("deltiq_migration_\(ProcessInfo.processInfo.globallyUniqueString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destURL = tempDir.appendingPathComponent("fixture.sqlite")
        try FileManager.default.copyItem(
            atPath: Self.sourcePath,
            toPath: destURL.path
        )
        // Copy WAL and SHM sidecar files if present (they are part of the store)
        for ext in ["-wal", "-shm"] {
            let sidecar = Self.sourcePath + ext
            if FileManager.default.fileExists(atPath: sidecar) {
                try FileManager.default.copyItem(
                    atPath: sidecar,
                    toPath: destURL.path + ext
                )
            }
        }
        return destURL
    }

    private func openContainer(at url: URL) throws -> (ModelContainer, ModelContext) {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: schema, configurations: config)
        return (container, ModelContext(container))
    }
}
#endif
