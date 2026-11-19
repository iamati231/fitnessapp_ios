#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Issue #12: Tests für Restore-Lücken die `PlanEditorPersistenceTests` (UIKit-only)
/// nicht abdecken. Läuft auf macOS (SwiftData) ohne UIKit.
///
/// Bestehende Abdeckung in `PlanEditorPersistenceTests` (UIKit-Guard):
/// - Custom bodyweight aktiv bei NoEquipment ✓
/// - Custom barbell archiviert bei NoEquipment ✓
/// - Custom barbell beim Gym-Restore reaktiviert ✓
/// - nil equipment konservativ archiviert ✓
/// - Trainingshistorie erhalten ✓
/// - Preview barbell als archived ✓
/// - Preview restore als restored ✓
///
/// Neue Abdeckung hier: Restore-Pfad für nil-equipment-Archive (P0-Lücke).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanEnvironmentMigratorTests: XCTestCase {

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

    // MARK: - Helpers

    @discardableResult
    private func makePlan(exercises: [(name: String, equipment: Equipment?)]) -> TrainingPlan {
        let plan = TrainingPlan(name: "Test", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .legs, plan: plan)
        day.generatorSequenceIndex = 1
        context.insert(day)
        for (index, item) in exercises.enumerated() {
            let ex = Exercise(
                name: item.name,
                sets: 3, repsMin: 8, repsMax: 12,
                restSeconds: 90,
                orderIndex: index,
                equipment: item.equipment,
                day: day
            )
            context.insert(ex)
        }
        return plan
    }

    private func makeArchivedExercise(
        name: String,
        equipment: Equipment?,
        in plan: TrainingPlan
    ) -> Exercise {
        let day = plan.days.first!
        let ex = Exercise(
            name: name,
            sets: 3, repsMin: 8, repsMax: 12,
            restSeconds: 90,
            orderIndex: 99,
            isArchived: true,
            archivedByEnvironmentChange: true,
            equipment: equipment,
            day: day
        )
        context.insert(ex)
        return ex
    }

    // MARK: - P0 Restore: nil-equipment-Archive sind wiederherstellbar

    /// Issue #12 P0 Kern-Fix: Custom-Exercise mit nil equipment wird konservativ
    /// archiviert (bestehender Vertrag), aber beim Rückwechsel zu Gym WIEDER
    /// aktiviert. Zuvor blockierte `?? false` in `isArchivedExerciseCompatible`
    /// den Restore — die Exercise war auf Dauer verloren.
    func testNilEquipmentArchivedExerciseIsRestoredToGym() throws {
        let plan = makePlan(exercises: [("MeinCustom-\(UUID().uuidString)", nil)])
        let day = try XCTUnwrap(plan.days.first)
        let exercise = try XCTUnwrap(day.exercises.first)

        // Schritt 1: konservative Archivierung beim Wechsel zu NoEquipment
        let migrateResult = PlanEnvironmentMigrator.migrate(
            plan: plan, toEnvironment: .noEquipment, modelContext: context
        )
        XCTAssertTrue(exercise.isArchived, "nil-equipment → konservativ archiviert")
        XCTAssertTrue(exercise.archivedByEnvironmentChange)
        XCTAssertEqual(migrateResult.kept, 1)

        // Schritt 2: Restore zu Gym — das war der P0-Bug (Exercise blieb verloren)
        let restoreResult = PlanEnvironmentMigrator.restoreOriginals(
            plan: plan, toEnvironment: .gym, modelContext: context
        )
        XCTAssertFalse(exercise.isArchived, "nil-equipment archivierte Exercise MUSS nach Gym-Restore aktiv sein")
        XCTAssertFalse(exercise.archivedByEnvironmentChange)
        XCTAssertEqual(restoreResult.restored, 1)
    }

    /// Legacy-Daten-Szenario: Exercise wurde mit `isArchived=true,
    /// archivedByEnvironmentChange=true` aber ohne equipment gespeichert
    /// (z.B. Backup von vor dem Equipment-Feld). Restore muss trotzdem klappen.
    func testLegacyArchivedNilEquipmentExerciseIsRestoredToGym() throws {
        let plan = makePlan(exercises: [])
        let ex = makeArchivedExercise(name: "LegacyCustom-\(UUID().uuidString)", equipment: nil, in: plan)

        let result = PlanEnvironmentMigrator.restoreOriginals(
            plan: plan, toEnvironment: .gym, modelContext: context
        )

        XCTAssertFalse(ex.isArchived, "Legacy nil-equipment-Archive muss zu Gym wiederherstellbar sein")
        XCTAssertFalse(ex.archivedByEnvironmentChange)
        XCTAssertEqual(result.restored, 1)
    }

    // MARK: - Restore: System-Exercise via .keep-Pfad

    /// System-Exercise ohne noEquipment-Mapping (z.B. "Kabelrudern sitzend") wird
    /// archiviert und beim Rückwechsel zu Gym reaktiviert.
    func testSystemExerciseKeepArchivedByEnvChangeRestoredToGym() throws {
        let plan = makePlan(exercises: [("Kabelrudern sitzend", nil)])
        let day = try XCTUnwrap(plan.days.first)
        let exercise = try XCTUnwrap(day.exercises.first)

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        XCTAssertTrue(exercise.isArchived, "System-Exercise ohne noEquipment-Mapping → archiviert")

        let result = PlanEnvironmentMigrator.restoreOriginals(
            plan: plan, toEnvironment: .gym, modelContext: context
        )
        XCTAssertFalse(exercise.isArchived)
        XCTAssertEqual(result.restored, 1)
    }

    // MARK: - Preview-Konsistenz

    /// previewRestoreAll zeigt nil-equipment archivierte Exercise als restored
    /// (konsistent mit restoreOriginals-Verhalten).
    func testPreviewRestoreShowsNilEquipmentArchivedExerciseAsRestored() throws {
        let plan = makePlan(exercises: [("LegacyCustom-\(UUID().uuidString)", nil)])
        let day = try XCTUnwrap(plan.days.first)
        let exercise = try XCTUnwrap(day.exercises.first)
        let name = exercise.name

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        XCTAssertTrue(exercise.isArchived)

        let previews = PlanEnvironmentMigrator.previewRestoreAll(plans: [plan], toEnvironment: .gym)
        XCTAssertTrue(previews.contains { $0.restored.contains(name) },
            "nil-equipment archivierte Exercise muss in preview.restored erscheinen")
    }

    /// hasRestorableOriginals erkennt nil-equipment archivedByEnvironmentChange-Exercise.
    func testHasRestorableOriginalsForNilEquipmentLegacyArchive() throws {
        let plan = makePlan(exercises: [])
        makeArchivedExercise(name: "LegacyCustom-\(UUID().uuidString)", equipment: nil, in: plan)

        let hasRestorable = PlanEnvironmentMigrator.hasAnyRestorableOriginals(plans: [plan], forEnvironment: .gym)
        XCTAssertTrue(hasRestorable)
    }
}
#endif
