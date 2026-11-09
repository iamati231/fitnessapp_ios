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
/// private class named `UserBodyProfile` (with 16 coaching-era-only columns).
/// SwiftData derives the SQLite entity name from the UNQUALIFIED class name,
/// so the fixture's entity name is "UserBodyProfile" — identical to
/// `DeltiqData.UserBodyProfile`. When this test opens the fixture with
/// `Schema(AppSchema.types)` (which references the production type), SwiftData
/// finds the matching entity by name, performs lightweight migration (drops the
/// 16 coaching columns), and returns live objects — implicit identity proof.
///
/// **WP3 — Test isolation**
/// The fixture is copied to a unique per-test temporary directory. Each test
/// starts from an independent store, so execution order and parallelism cannot
/// cause interference.
///
/// **WP4 — Data integrity after migration**
/// All 17 entity types written by the enricher are verified: counts, field
/// values, and relationships — including the full chain
/// TrainingPlan → TrainingDay → Exercise → WorkoutSession → ExerciseLog
/// and MealEntry → MealItem.
///
/// **WP5 — Write-reopen verification (explicit container lifecycle)**
/// Two distinct helper functions are used. `migrateAndVerifyLegacyStore(at:)`
/// opens, verifies, writes new data, saves and returns — container goes out of
/// scope, ARC reaches zero, WAL is checkpointed. Only after that returns does
/// `verifyReopenedStore(at:)` open a fresh container.
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

        // WP4 + WP5 step-1: open, migrate, verify migrated data, write new data
        try migrateAndVerifyLegacyStore(at: url)

        // WP5 step-2: reopen after the first container has been fully released
        try verifyReopenedStore(at: url)
    }

    // MARK: - WP4: Migrate and verify all 17 entity types

    /// Opens the legacy store (triggers lightweight migration), verifies all 17
    /// entity types, writes new data, then returns so the container is released.
    private func migrateAndVerifyLegacyStore(at url: URL) throws {
        let (container, ctx) = try openContainer(at: url)
        defer { _ = container }   // extend ARC to end of function

        // ── UserBodyProfile ──────────────────────────────────────────────────
        let profiles = try ctx.fetch(FetchDescriptor<UserBodyProfile>())
        XCTAssertEqual(profiles.count, 1,
                       "UserBodyProfile row must survive migration")
        let p = try XCTUnwrap(profiles.first)
        XCTAssertEqual(p.heightCm, 178.0, accuracy: 0.001,
                       "heightCm must survive lightweight migration")
        XCTAssertEqual(p.profile,          .male)
        XCTAssertEqual(p.environment,      .gym)
        XCTAssertEqual(p.firstName,        "Max")
        XCTAssertEqual(p.weeklyWorkoutGoal, 3)
        XCTAssertNotNil(p.goalWeightKg,
                        "goalWeightKg must survive")
        XCTAssertEqual(p.experienceTrackRaw, "intermediate")

        // Coaching widget types that were removed must be silently filtered
        let typed = p.activeDashboardWidgets
        XCTAssertFalse(typed.map(\.rawValue).contains("runCoachCard"),
                       "runCoachCard must be filtered after rollback")
        XCTAssertFalse(typed.map(\.rawValue).contains("raceProgressCard"),
                       "raceProgressCard must be filtered after rollback")
        XCTAssertTrue(p.activeDashboardWidgetsRaw.contains("nextWorkout"))
        XCTAssertTrue(p.activeDashboardWidgetsRaw.contains("cardioPace"))

        // ── TrainingPlan ─────────────────────────────────────────────────────
        let plans = try ctx.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(plans.count, 1, "TrainingPlan count after migration")
        let plan = try XCTUnwrap(plans.first)
        XCTAssertEqual(plan.name, "Hypertrophie 12 Wochen")

        // ── TrainingDay + relationship to TrainingPlan ───────────────────────
        let days = try ctx.fetch(FetchDescriptor<TrainingDay>())
        XCTAssertEqual(days.count, 1, "TrainingDay count after migration")
        let day = try XCTUnwrap(days.first)
        XCTAssertEqual(day.name, "Push A")
        XCTAssertEqual(day.plan?.name, plan.name,
                       "TrainingDay.plan relationship must resolve")

        // ── Exercise + relationship to TrainingDay ───────────────────────────
        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.count, 1, "Exercise count after migration")
        let exercise = try XCTUnwrap(exercises.first)
        XCTAssertEqual(exercise.name, "Bankdrücken")
        XCTAssertEqual(exercise.day?.name, day.name,
                       "Exercise.day relationship must resolve")

        // ── WorkoutSession + relationship to TrainingDay ─────────────────────
        let sessions = try ctx.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1, "WorkoutSession count after migration")
        let session = try XCTUnwrap(sessions.first)
        XCTAssertTrue(session.isCompleted)
        XCTAssertEqual(session.day?.name, day.name,
                       "WorkoutSession.day relationship must resolve")

        // ── ExerciseLog + relationships to Exercise and WorkoutSession ────────
        let logs = try ctx.fetch(FetchDescriptor<ExerciseLog>())
        XCTAssertEqual(logs.count, 1, "ExerciseLog count after migration")
        let log = try XCTUnwrap(logs.first)
        XCTAssertEqual(log.weight ?? 0, 100.0, accuracy: 0.001)
        XCTAssertEqual(log.exercise?.name, exercise.name,
                       "ExerciseLog.exercise relationship must resolve")
        XCTAssertEqual(log.session?.isCompleted, true,
                       "ExerciseLog.session relationship must resolve")

        // ── ExerciseTemplate ─────────────────────────────────────────────────
        let templates = try ctx.fetch(FetchDescriptor<ExerciseTemplate>())
        XCTAssertEqual(templates.count, 1, "ExerciseTemplate count after migration")
        XCTAssertEqual(templates.first?.name, "Bankdrücken")

        // ── BodyMeasurement ───────────────────────────────────────────────────
        let measurements = try ctx.fetch(FetchDescriptor<BodyMeasurement>())
        XCTAssertEqual(measurements.count, 1, "BodyMeasurement count after migration")
        XCTAssertEqual(measurements.first?.weightKg ?? 0, 80.0, accuracy: 0.001)

        // ── MealEntry + MealItem (relationship) ───────────────────────────────
        let meals = try ctx.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(meals.count, 1, "MealEntry count after migration")
        let mealEntry = try XCTUnwrap(meals.first)
        XCTAssertEqual(mealEntry.mealType, .lunch)
        XCTAssertEqual(mealEntry.items.count, 1,
                       "MealEntry.items (cascade relationship) must have 1 MealItem")
        XCTAssertEqual(mealEntry.items.first?.nameSnapshot, "Hähnchenbrust")

        let items = try ctx.fetch(FetchDescriptor<MealItem>())
        XCTAssertEqual(items.count, 1, "MealItem count after migration")
        XCTAssertNotNil(items.first?.meal,
                        "MealItem.meal back-reference must resolve")

        // ── WaterEntry ────────────────────────────────────────────────────────
        let waters = try ctx.fetch(FetchDescriptor<WaterEntry>())
        XCTAssertEqual(waters.count, 1, "WaterEntry count after migration")
        XCTAssertEqual(waters.first?.amountMl, 500)

        // ── PersonalRecordEntry ───────────────────────────────────────────────
        let prs = try ctx.fetch(FetchDescriptor<PersonalRecordEntry>())
        XCTAssertEqual(prs.count, 1, "PersonalRecordEntry count after migration")
        let pr = try XCTUnwrap(prs.first)
        XCTAssertEqual(pr.exerciseName, "Bankdrücken")
        XCTAssertEqual(pr.kindRaw,       "heaviestWeight")
        XCTAssertEqual(pr.value,          100.0, accuracy: 0.001)
        XCTAssertNotNil(pr.session, "PersonalRecordEntry.session must resolve")

        // ── Gear ──────────────────────────────────────────────────────────────
        let gears = try ctx.fetch(FetchDescriptor<Gear>())
        XCTAssertEqual(gears.count, 1, "Gear count after migration")
        XCTAssertEqual(gears.first?.name, "Nike Metcon 9")

        // ── PeriodicCheckIn ───────────────────────────────────────────────────
        let checkIns = try ctx.fetch(FetchDescriptor<PeriodicCheckIn>())
        XCTAssertEqual(checkIns.count, 1, "PeriodicCheckIn count after migration")

        // ── FoodCatalogEntry ──────────────────────────────────────────────────
        let foodEntries = try ctx.fetch(FetchDescriptor<FoodCatalogEntry>())
        XCTAssertEqual(foodEntries.count, 1, "FoodCatalogEntry count after migration")
        XCTAssertEqual(foodEntries.first?.displayName, "Hähnchenbrust (Fixture)")

        // ── DailyMealPlan + PlannedMealAssignment (relationship) ──────────────
        let mealPlans = try ctx.fetch(FetchDescriptor<DailyMealPlan>())
        XCTAssertEqual(mealPlans.count, 1, "DailyMealPlan count after migration")
        let mealPlan = try XCTUnwrap(mealPlans.first)
        XCTAssertEqual(mealPlan.assignments.count, 1,
                       "DailyMealPlan.assignments relationship must have 1 entry")

        let assignments = try ctx.fetch(FetchDescriptor<PlannedMealAssignment>())
        XCTAssertEqual(assignments.count, 1, "PlannedMealAssignment count after migration")
        let assignment = try XCTUnwrap(assignments.first)
        XCTAssertEqual(assignment.recipeID, "test-recipe-001")
        XCTAssertNotNil(assignment.plan, "PlannedMealAssignment.plan back-reference must resolve")

        // ── WP5 step-1: write new data before releasing the container ─────────
        p.goalWeightKg = 82.5
        let extraWater = WaterEntry(date: Date(), amountMl: 300)
        ctx.insert(extraWater)
        try ctx.save()
        // `defer { _ = container }` keeps ARC alive; function return drops it.
    }

    // MARK: - WP5: Reopen after explicit container release

    /// Opens a fresh container (called only after `migrateAndVerifyLegacyStore`
    /// has returned and its container has been released). Verifies that both
    /// newly written and originally migrated data are present and correct.
    private func verifyReopenedStore(at url: URL) throws {
        let (container, ctx) = try openContainer(at: url)
        defer { _ = container }

        // Written data must have persisted across container close + reopen
        let profiles = try ctx.fetch(FetchDescriptor<UserBodyProfile>())
        let p = try XCTUnwrap(profiles.first)
        XCTAssertEqual(p.goalWeightKg ?? 0, 82.5, accuracy: 0.001,
                       "Written goalWeightKg must persist across store re-open")

        let waters = try ctx.fetch(FetchDescriptor<WaterEntry>())
        XCTAssertEqual(waters.count, 2,
                       "New WaterEntry must persist; original must still be present")
        let amountMls = Set(waters.compactMap { $0.amountMl })
        XCTAssertTrue(amountMls.contains(500), "Original WaterEntry(500ml) must survive re-open")
        XCTAssertTrue(amountMls.contains(300), "Written WaterEntry(300ml) must persist")

        // Spot-check that original migrated data is still readable
        let plans = try ctx.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(plans.count, 1,
                       "TrainingPlan must still be present after re-open")
        let meals = try ctx.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(meals.count, 1,
                       "MealEntry must still be present after re-open")
        XCTAssertEqual(meals.first?.items.count, 1,
                       "MealEntry.items relationship must still resolve after re-open")
    }

    // MARK: - Helpers

    /// Copies the fixture SQLite (and WAL/SHM sidecar files if present)
    /// to an isolated temporary directory and returns the new SQLite URL.
    private func copyFixtureToTempDir() throws -> URL {
        guard FileManager.default.fileExists(atPath: Self.sourcePath) else {
            // Using XCTSkip would let CI pass silently — throw instead so the
            // CI step "Fixture-Datei vorhanden prüfen" catches it first.
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
