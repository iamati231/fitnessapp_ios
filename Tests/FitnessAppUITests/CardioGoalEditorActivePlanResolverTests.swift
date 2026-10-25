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
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func testPostActivationAdjustmentPreviewUsesActivePlanResolver() throws {
        let source = try contents(of: "Settings/CardioGoalEditorView.swift")
        guard let coachJustActivatedRange = source.range(of: "if coachJustActivated, let plan = ") else {
            XCTFail("coachJustActivated-Zweig in save() nicht gefunden")
            return
        }
        let body = source[coachJustActivatedRange.upperBound...].prefix(100)
        XCTAssertTrue(
            body.hasPrefix("ActivePlanResolver.cardioRelevantPlan(among: activePlans)"),
            "die Post-Aktivierungs-Vorschau muss ActivePlanResolver.cardioRelevantPlan(among:) verwenden statt activePlans.first"
        )
        XCTAssertFalse(
            source.contains("let plan = activePlans.first"),
            "CardioGoalEditorView darf activePlans.first nicht mehr direkt verwenden"
        )
    }
}
#endif
