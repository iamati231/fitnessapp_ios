#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Issue #12: Beweist die drei Kern-Garantien des Trainingsortwechsels:
/// 1. Custom-Exercise mit unbekanntem Equipment wird NICHT still archiviert.
/// 2. Archivierte Custom-/System-Exercises kommen beim Rückwechsel zurück.
/// 3. Vorschau und tatsächliche Migration stimmen überein.
///
/// Läuft nur auf macOS (SwiftData) — auf Linux nur kompilieren.
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

    /// Erstellt einen Plan mit einem Tag und den angegebenen Exercises.
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

    /// Legt eine bereits archivierte Exercise direkt an (simuliert Legacy-Zustand).
    private func makeArchivedCustomExercise(
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

    // MARK: - Custom exercises: nil equipment bleibt aktiv

    /// Issue #12 P0: Custom-Exercise ohne Equipment-Angabe darf beim Wechsel
    /// zu NoEquipment NICHT still archiviert werden ("unknown ≠ noEquipment").
    func testCustomExerciseWithNilEquipmentStaysActiveOnNoEquipmentMigration() throws {
        let plan = makePlan(exercises: [("MeinCustom", nil)])
        let result = PlanEnvironmentMigrator.migrate(
            plan: plan, toEnvironment: .noEquipment, modelContext: context
        )

        let day = try XCTUnwrap(plan.days.first)
        let ex = try XCTUnwrap(day.exercises.first)
        XCTAssertFalse(ex.isArchived, "nil-equipment Custom-Exercise darf nicht archiviert werden")
        XCTAssertFalse(ex.archivedByEnvironmentChange)
        XCTAssertEqual(result.kept, 0)
        XCTAssertEqual(result.compatible, 1)
    }

    /// Custom-Exercise MIT bekanntem Gym-Equipment (Hantel) WIRD archiviert,
    /// weil das Equipment im NoEquipment-Modus nicht vorhanden ist.
    func testCustomExerciseWithDumbbellArchivedOnNoEquipmentMigration() throws {
        let plan = makePlan(exercises: [("MeinCustomDH", .dumbbell)])
        PlanEnvironmentMigrator.migrate(
            plan: plan, toEnvironment: .noEquipment, modelContext: context
        )

        let day = try XCTUnwrap(plan.days.first)
        let ex = try XCTUnwrap(day.exercises.first)
        XCTAssertTrue(ex.isArchived)
        XCTAssertTrue(ex.archivedByEnvironmentChange)
    }

    /// Bodyweight-Custom-Exercise bleibt in jedem Environment aktiv.
    func testCustomExerciseBodyweightStaysActiveEverywhere() throws {
        for env: EnvironmentType in [.gym, .homeGym, .noEquipment] {
            let plan = makePlan(exercises: [("BWCustom", .bodyweight)])
            PlanEnvironmentMigrator.migrate(
                plan: plan, toEnvironment: env, modelContext: context
            )
            let ex = try XCTUnwrap(plan.days.first?.exercises.first)
            XCTAssertFalse(ex.isArchived, "BW custom muss in \(env) aktiv bleiben")
        }
    }

    // MARK: - Restore: archivierte Custom-Exercises wiederherstellen

    /// Issue #12 P0 Restore: Custom-Exercise mit Hantel, die bei NoEquipment
    /// archiviert wurde, muss beim Rückwechsel zu Gym reaktiviert werden.
    func testArchivedCustomExerciseWithDumbbellRestoredOnGymRestore() throws {
        let plan = makePlan(exercises: [])  // leerer Plan, direkt archivierte Exercise anlegen
        let ex = makeArchivedCustomExercise(name: "MeinCustomDH", equipment: .dumbbell, in: plan)

        let result = PlanEnvironmentMigrator.restoreOriginals(
            plan: plan, toEnvironment: .gym, modelContext: context
        )

        XCTAssertFalse(ex.isArchived, "Dumbbell-Custom-Exercise muss nach Restore aktiv sein")
        XCTAssertFalse(ex.archivedByEnvironmentChange)
        XCTAssertEqual(result.restored, 1)
    }

    /// Issue #12 P0 Restore: Legacy-Daten — Custom-Exercise ohne Equipment-Angabe,
    /// die in der Vergangenheit archiviert wurde, muss beim Rückwechsel zu Gym
    /// wiederhergestellt werden.
    func testLegacyArchivedCustomExerciseWithNilEquipmentRestoredOnGym() throws {
        let plan = makePlan(exercises: [])
        let ex = makeArchivedCustomExercise(name: "LegacyCustom", equipment: nil, in: plan)

        let result = PlanEnvironmentMigrator.restoreOriginals(
            plan: plan, toEnvironment: .gym, modelContext: context
        )

        XCTAssertFalse(ex.isArchived, "nil-equipment Legacy-Exercise muss nach Restore aktiv sein")
        XCTAssertFalse(ex.archivedByEnvironmentChange)
        XCTAssertEqual(result.restored, 1)
    }

    /// System-Exercise, die via `.keep` (kein Mapping zu NoEquipment) archiviert
    /// wurde, muss beim Rückwechsel zu Gym reaktiviert werden.
    /// Verwendet "Kabelrudern sitzend" — hat nur homeGym-Mapping, kein noEquipment.
    func testSystemExerciseKeepArchivedByEnvChangeRestoredOnGym() throws {
        let plan = makePlan(exercises: [])
        let ex = makeArchivedCustomExercise(
            name: "Kabelrudern sitzend",  // System-Name in Library, aber nil equipment in Exercise
            equipment: nil,
            in: plan
        )
        // Simuliere isSystemExercise via Name-Fallback: "Kabelrudern sitzend" ist im Catalog.
        // isArchivedExerciseCompatible prüft bei System-Exercises isCompatibleWith(.gym) → true.
        // Da exerciseTemplateID nil, fällt isSystemExercise auf byName-Lookup zurück.

        let result = PlanEnvironmentMigrator.restoreOriginals(
            plan: plan, toEnvironment: .gym, modelContext: context
        )

        XCTAssertFalse(ex.isArchived, "System-Exercise (.keep) muss nach Restore zu Gym aktiv sein")
        XCTAssertEqual(result.restored, 1)
    }

    // MARK: - Vollständiger Zyklus: Gym → NoEquipment → Gym

    /// Gym → NoEquipment → Gym: Custom-Exercise ohne Equipment bleibt
    /// durchgehend aktiv (wird nie archiviert, daher auch kein Restore nötig).
    func testGymToNoEquipmentToGymCustomNilEquipmentNeverArchived() throws {
        let plan = makePlan(exercises: [("MeinCustom", nil)])

        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .gym, modelContext: context)

        let day = try XCTUnwrap(plan.days.first)
        let activeExercises = day.activeExercises
        XCTAssertEqual(activeExercises.count, 1)
        XCTAssertFalse(activeExercises[0].isArchived)
    }

    /// Gym → NoEquipment → Gym: Custom-Exercise mit Hantel wird archiviert,
    /// dann beim Rückwechsel wiederhergestellt.
    func testGymToNoEquipmentToGymCustomDumbbellArchivedAndRestored() throws {
        let plan = makePlan(exercises: [("MeinCustomDH", .dumbbell)])
        let day = try XCTUnwrap(plan.days.first)
        let original = try XCTUnwrap(day.exercises.first)

        // Schritt 1: zu NoEquipment → archivieren
        PlanEnvironmentMigrator.migrate(plan: plan, toEnvironment: .noEquipment, modelContext: context)
        XCTAssertTrue(original.isArchived)

        // Schritt 2: zurück zu Gym → wiederherstellen
        let restoreResult = PlanEnvironmentMigrator.restoreOriginals(
            plan: plan, toEnvironment: .gym, modelContext: context
        )
        XCTAssertFalse(original.isArchived, "Exercise muss nach Gym-Restore aktiv sein")
        XCTAssertFalse(original.archivedByEnvironmentChange)
        XCTAssertEqual(restoreResult.restored, 1)
    }

    // MARK: - Preview-Konsistenz (Issue #12 P1)

    /// previewMigrateAll zeigt nil-equipment Custom-Exercise NICHT als archived.
    func testPreviewMigrateCustomNilEquipmentNotInArchivedList() throws {
        let plan = makePlan(exercises: [("MeinCustom", nil)])
        let previews = PlanEnvironmentMigrator.previewMigrateAll(
            plans: [plan], toEnvironment: .noEquipment
        )
        // nil-equipment Custom-Exercise ist kompatibel → kein Preview-Eintrag nötig
        XCTAssertTrue(previews.isEmpty || previews.allSatisfy { !$0.archived.contains("MeinCustom") })
    }

    /// previewMigrateAll zeigt dumbbell-Custom-Exercise korrekt als archived.
    func testPreviewMigrateCustomDumbbellInArchivedList() throws {
        let plan = makePlan(exercises: [("MeinCustomDH", .dumbbell)])
        let previews = PlanEnvironmentMigrator.previewMigrateAll(
            plans: [plan], toEnvironment: .noEquipment
        )
        XCTAssertTrue(previews.contains { $0.archived.contains("MeinCustomDH") })
    }

    /// previewRestoreAll zeigt nil-equipment archivierte Exercise als restored.
    func testPreviewRestoreNilEquipmentLegacyArchivedShownAsRestored() throws {
        let plan = makePlan(exercises: [])
        makeArchivedCustomExercise(name: "LegacyCustom", equipment: nil, in: plan)
        plan.targetEnvironment = .noEquipment

        let previews = PlanEnvironmentMigrator.previewRestoreAll(
            plans: [plan], toEnvironment: .gym
        )
        XCTAssertTrue(previews.contains { $0.restored.contains("LegacyCustom") })
    }
}
#endif
