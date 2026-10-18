#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// TEMPORÄRER Diagnose-Test (siehe docs/P8_STUFE2_VERSIONIERUNG_PLAN.md,
/// Abschnitt "Ergebnis Paket A+B"): prüft die Hypothese, dass
/// `try makeContainer().mainContext` (Container nicht separat gehalten,
/// anders als bei JEDER bestehenden, nie abstürzenden Testmethode in
/// `FourWeekReviewAssemblerTests`, die durchgehend `let container = try
/// makeContainer()` als eigene Variable hält) den `ModelContainer` vorzeitig
/// dealloziert, während der daraus gezogene `ModelContext` noch verwendet
/// wird — ein Use-after-free, das exakt zum beobachteten SwiftData-internen
/// Signal-5-Trap passen würde.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ContainerLifetimeDiagnosticTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    func testMinimalInsertWithRetainedContainer() throws {
        let container = try makeContainer()

        try withExtendedLifetime(container) {
            let context = container.mainContext
            let plan = TrainingPlan(
                name: "Diagnose",
                programType: "custom",
                isActive: true
            )
            context.insert(plan)
            try context.save()
            XCTAssertEqual(plan.name, "Diagnose")
        }
    }
}
#endif
