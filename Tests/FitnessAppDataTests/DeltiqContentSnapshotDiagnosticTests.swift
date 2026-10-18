#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// TEMPORÄRER Diagnose-Stand (siehe Commit-Historie `d845301`..`1a12faa`):
/// auch ein maximal triviales Minimalbeispiel OHNE jeden Bezug zu
/// `WorkoutSession`/`TrainingDayContentSnapshotWriter` stürzte unter dem
/// Datei-/Klassennamen `TrainingDayContentRecordTests`/
/// `TrainingDayContentSnapshotWriterTests` auf Apple-CI ab. Diese Fassung
/// testet, ob der Signal-5-Absturz am NAMEN dieser Datei/Klasse hängt
/// (z. B. ein über viele vorherige CI-Läufe mit demselben Pfad/Namen
/// korrumpierter Build-/Modul-Cache auf dem CI-Host) oder an der
/// Dispatch-POSITION im Testlauf unabhängig vom Namen. Wird nach der
/// Diagnose durch die vollständige Testsuite ersetzt.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DeltiqContentSnapshotDiagnosticTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    func testMinimalDiagnosticInsertOfUnrelatedModel() throws {
        let context = try makeContainer().mainContext
        let plan = TrainingPlan(name: "Diagnose", programType: "custom", isActive: true)
        context.insert(plan)
        try context.save()

        XCTAssertEqual(plan.name, "Diagnose")
    }
}
#endif
