#if canImport(SwiftUI)
import XCTest

/// Task 9 (docs/superpowers/sdd/2026-10-25-equipment-vielfalt-laufcoaching-dual-path,
/// Controller-Nachbesserung nach dem urspruenglichen Report): `save()`
/// waehlte den Plan fuer die Post-Aktivierungs-Vorschau
/// (`CoachAdjustmentPreviewView` ueber `planForAdjustmentPreview`) bisher
/// ueber dasselbe nicht-deterministische `activePlans.first` wie die beiden
/// Dashboard-Cardio-Karten - derselbe Resolver muss auch hier gelten.
/// Source-introspection (kein SwiftUI-Render-Harness in diesem Repo),
/// gleiches Muster wie `DashboardActivePlanDeterminismTests`.
final class CardioGoalEditorActivePlanResolverTests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func testPostActivationAdjustmentPreviewUsesActivePlanResolver() throws {
        let source = try contents(of: "Settings/CardioGoalEditorView.swift")
        // Nachbesserung ("Tatsächlichen Zielwechsel über CardioGoalEditorView
        // absichern"): die Aktivieren-ODER-Zielwechsel-Entscheidung lebt jetzt
        // in `ActivePlanResolver.planRequiringAdjustment` (siehe dessen Doku
        // und behaviorale Tests in `ActivePlanResolverTests`), das intern
        // weiterhin `cardioRelevantPlan(among:)` verwendet - nicht mehr
        // `activePlans.first` direkt in dieser View.
        XCTAssertTrue(
            source.contains("if let plan = ActivePlanResolver.planRequiringAdjustment("),
            "die Post-Aktivierungs-/Zielwechsel-Vorschau muss ActivePlanResolver.planRequiringAdjustment verwenden"
        )
        XCTAssertFalse(
            source.contains("let plan = activePlans.first"),
            "CardioGoalEditorView darf activePlans.first nicht mehr direkt verwenden"
        )
    }
}
#endif
