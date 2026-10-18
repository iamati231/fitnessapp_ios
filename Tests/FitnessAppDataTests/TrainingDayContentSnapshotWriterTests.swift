#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// TEMPORÄRER Diagnose-Stand (siehe Commit-Historie `d845301`..`eabd489`):
/// auf ein einziges, maximal triviales Minimalbeispiel reduziert, OHNE
/// jeden Bezug zu `WorkoutSession`/`TrainingDayContentSnapshotWriter`, um
/// zu prüfen, ob der Signal-5-Absturz an DIESER Testdatei/-klasse selbst
/// hängt (unabhängig vom Modellinhalt) oder an etwas im bisherigen
/// Testkörper. Wird nach der Diagnose durch die vollständige Testsuite
/// ersetzt.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class TrainingDayContentSnapshotWriterTests: XCTestCase {

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
