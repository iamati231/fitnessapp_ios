#if canImport(SwiftUI)
import XCTest

/// Task 9 (docs/superpowers/sdd/2026-10-25-equipment-vielfalt-laufcoaching-dual-path,
/// Review-Nachbesserung, dritte Runde): ein weiterer Twin, gefunden ueber die
/// noch breitere Idiom-Variante `allPlans.first { $0.isActive }` (Closure-
/// Form, nicht `plans.first(where: \.isActive)`). `ProfileEditorView.
/// activePlan` ist laut der eigenen Doku auf `coachAdjustmentModel`
/// ausdruecklich der DRITTE von drei identischen Leitplanke-6-Geschwistern
/// (`DashboardView`, `PlansListView`, `ProfileEditorView`) - alle drei
/// muessen denselben Resolver verwenden. Source-introspection (kein
/// SwiftUI-Render-Harness in diesem Repo), gleiches Muster wie
/// `DashboardActivePlanDeterminismTests`/`PlansListActivePlanResolverTests`.
final class ProfileEditorActivePlanResolverTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// `activePlan` speist sowohl `coachAdjustmentModel` als auch das
    /// `showingCoachAdjustmentPreview`-Sheet - ein einziger Fix an dieser
    /// einen Stelle deckt beide Konsumenten ab.
    func testActivePlanUsesActivePlanResolver() throws {
        let source = try contents(of: "Settings/ProfileEditorView.swift")
        guard let propertyRange = source.range(of: "private var activePlan: TrainingPlan? {") else {
            XCTFail("activePlan property not found")
            return
        }
        let body = source[propertyRange.upperBound...].prefix(100)
        XCTAssertTrue(
            body.contains("ActivePlanResolver.cardioRelevantPlan(among: allPlans)"),
            "activePlan muss ActivePlanResolver.cardioRelevantPlan(among:) verwenden"
        )
        XCTAssertFalse(
            body.contains("allPlans.first"),
            "activePlan darf allPlans.first nicht mehr direkt verwenden"
        )
    }
}
#endif
