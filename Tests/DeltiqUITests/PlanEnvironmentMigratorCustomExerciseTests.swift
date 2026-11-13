// Issue #12 regression suite — SwiftData in-memory integration tests for custom-exercise migration.
#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import DeltiqCore
import DeltiqData
@testable import DeltiqUI

/// Issue #12: Regressionstests für Custom-Exercise-Behandlung in PlanEnvironmentMigrator.
///
/// Szenarien:
/// 1. Custom-Bodyweight-Exercise bleibt aktiv im noEquipment-Modus.
/// 2. Custom-Barbell-Exercise wird archiviert (archivedByEnvironmentChange=true) im noEquipment-Modus.
/// 3. Beim Restore (Gym) wird die archivedByEnvironmentChange-Exercise reaktiviert.
/// 4. Custom-Exercise mit nil equipment → konservativ archiviert (kein Datenverlust).
/// 5. Trainingshistorie (ExerciseLog) bleibt bei archive+restore erhalten.
/// 6. Cancel-Semantik: kein archivedByEnvironmentChange ohne migrate().
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class PlanEnvironmentMigratorCustomExerciseTests: XCTestCase {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AppSchema.types),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makePlanWithCustomExercise(
        equipment: Equipment?,
        in context: ModelContext
    ) -> (plan: TrainingPlan, exercise: Exercise) {
        let plan = TrainingPlan(name: "Test", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Tag 1", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        // "Meine Custom-Übung" ist NICHT im Systemkatalog → Custom-Exercise
        let exercise = Exercise(
            name: "Meine Custom-Übung XYZ-\(UUID().uuidString)",
            orderIndex: 0,
            equipment: equipment,
            day: day
        )
        context.insert(exercise)
        return (plan, exercise)
    }

    // MARK: - Szenario 1: Bodyweight custom → bleibt aktiv

    func testCustomBodyweightExerciseStaysActiveInNoEquipmentMode() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: .bodyweight, in: context)
        try context.save()

        let result = PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)

        XCTAssertFalse(exercise.isArchived, "Bodyweight-Custom-Exercise muss aktiv bleiben")
        XCTAssertFalse(exercise.archivedByEnvironmentChange)
        XCTAssertEqual(result.compatible, 1)
        XCTAssertEqual(result.kept, 0)
    }

    // MARK: - Szenario 2: Barbell custom → archiviert mit archivedByEnvironmentChange

    func testCustomBarbellExerciseArchivedInNoEquipmentMode() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        try context.save()

        let result = PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)

        XCTAssertTrue(exercise.isArchived, "Barbell-Custom-Exercise muss archiviert werden")
        XCTAssertTrue(exercise.archivedByEnvironmentChange, "archivedByEnvironmentChange muss gesetzt sein")
        XCTAssertNil(exercise.swappedFromOriginal, "kein swappedFromOriginal-Link für .keep-Pfad")
        XCTAssertEqual(result.kept, 1)
        XCTAssertEqual(result.compatible, 0)
    }

    // MARK: - Szenario 3: Restore reaktiviert archivedByEnvironmentChange-Exercise

    func testCustomBarbellExerciseRestoredOnReturnToGym() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        try context.save()

        // Gym → noEquipment
        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        XCTAssertTrue(exercise.isArchived)
        XCTAssertTrue(exercise.archivedByEnvironmentChange)

        // noEquipment → Gym (Restore)
        let restoreResult = PlanEnvironmentMigrator.restoreOriginals(plan: plan, toEnvironment: .gym, modelContext: context)

        XCTAssertFalse(exercise.isArchived, "Exercise muss nach Restore reaktiviert sein")
        XCTAssertFalse(exercise.archivedByEnvironmentChange, "archivedByEnvironmentChange muss nach Restore gelöscht sein")
        XCTAssertEqual(restoreResult.restored, 1)
    }

    // MARK: - Szenario 4: nil equipment → konservativ archiviert

    func testCustomExerciseWithNilEquipmentArchivedConservatively() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: nil, in: context)
        try context.save()

        let result = PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)

        XCTAssertTrue(exercise.isArchived, "Custom-Exercise ohne Equipment-Info muss konservativ archiviert werden")
        XCTAssertTrue(exercise.archivedByEnvironmentChange)
        XCTAssertEqual(result.kept, 1)
    }

    // MARK: - Szenario 5: Trainingshistorie (ExerciseLog) bleibt erhalten

    func testTrainingHistoryPreservedAfterArchiveAndRestore() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, exercise) = makePlanWithCustomExercise(equipment: .barbell, in: context)

        // Log-Eintrag erstellen (Exercise als Kontext → Snapshots werden automatisch gefüllt)
        let log = ExerciseLog(
            setIndex: 0,
            weight: 100.0,
            reps: 5,
            rir: 2.0,
            exercise: exercise
        )
        context.insert(log)
        try context.save()

        // Archive
        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        try context.save()

        // Log muss noch existieren (deleteRule: .nullify)
        let logs = try context.fetch(FetchDescriptor<ExerciseLog>())
        XCTAssertEqual(logs.count, 1, "ExerciseLog muss beim Archivieren erhalten bleiben (.nullify delete rule)")
        XCTAssertEqual(logs.first?.exerciseNameSnapshot, exercise.name)

        // Restore
        PlanEnvironmentMigrator.restoreOriginals(plan: plan, toEnvironment: .gym, modelContext: context)

        XCTAssertFalse(exercise.isArchived, "Exercise muss nach Restore aktiv sein")
        let logsAfterRestore = try context.fetch(FetchDescriptor<ExerciseLog>())
        XCTAssertEqual(logsAfterRestore.count, 1, "Log muss auch nach Restore erhalten bleiben")
    }

    // MARK: - Szenario 6: Preview zeigt archivedByEnvironmentChange-Exercises korrekt an

    func testPreviewMigrateShowsCustomBarbellAsArchived() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, _) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        plan.targetEnvironment = .gym
        try context.save()

        let previews = PlanEnvironmentMigrator.previewMigrateAll(plans: [plan], toEnvironment: .noEquipment)

        XCTAssertEqual(previews.count, 1)
        XCTAssertEqual(previews.first?.archived.count, 1, "Barbell-Custom-Exercise muss in preview.archived erscheinen")
        XCTAssertTrue(previews.first?.swaps.isEmpty ?? false, "kein Swap für Custom-Exercise ohne System-Alternative")
    }

    func testPreviewRestoreShowsArchivedByEnvChangeAsRestored() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, _) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        plan.targetEnvironment = .gym
        try context.save()

        // Erst migrieren (archiviert)
        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        try context.save()

        // Preview Restore: muss die archivierte Exercise als restored anzeigen
        let previews = PlanEnvironmentMigrator.previewRestoreAll(plans: [plan], toEnvironment: .gym)

        XCTAssertEqual(previews.count, 1)
        XCTAssertEqual(previews.first?.restored.count, 1, "archivedByEnvironmentChange-Exercise muss in preview.restored erscheinen")
        XCTAssertTrue(previews.first?.swaps.isEmpty ?? false)
    }

    // MARK: - Szenario 7: hasAnyRestorableOriginals erkennt archivedByEnvironmentChange

    func testHasAnyRestorableOriginalsTrueForArchivedCustomExercise() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (plan, _) = makePlanWithCustomExercise(equipment: .barbell, in: context)
        plan.targetEnvironment = .gym
        try context.save()

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        try context.save()

        let hasRestorable = PlanEnvironmentMigrator.hasAnyRestorableOriginals(plans: [plan], forEnvironment: .gym)
        XCTAssertTrue(hasRestorable, "hasAnyRestorableOriginals muss true sein wenn archivedByEnvironmentChange-Exercise vorhanden")
    }
}
#endif
