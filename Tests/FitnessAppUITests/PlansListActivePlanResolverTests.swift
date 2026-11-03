#if canImport(SwiftUI)
import XCTest

/// Task 9 (docs/superpowers/sdd/2026-10-25-equipment-vielfalt-laufcoaching-dual-path,
/// Review-Nachbesserung): `PlansListView` hatte einen Bug im Idiom
/// `plans.first(where: \.isActive)` - `plans` ist hier der
/// clientseitig (alphabetisch, aktive-zuerst) sortierte `@Query`-Wrapper
/// dieser View, also eine ANDERE, ebenso willkuerliche Regel. Source-introspection
/// (kein SwiftUI-Render-Harness in diesem Repo).
final class PlansListActivePlanResolverTests: XCTestCase {

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

    /// Die reine Anzeige-Stelle (Kontextzeilen-Plan-Name) ist bewusst NICHT
    /// Teil dieses Tasks (gleiche Kategorie wie `DashboardView`s
    /// `dashboardContextRow`/`shouldShowCardioChart`) - dieser Test haelt
    /// fest, dass sie unveraendert bleibt, damit ein versehentliches
    /// Mit-Aendern auffiele.
    func testContextRowPlanNameDisplayIsDeliberatelyLeftUnchanged() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        XCTAssertTrue(
            source.contains("let activeName = plans.first(where: \\.isActive)?.displayName"),
            "die reine Anzeige-Stelle ist bewusst ausserhalb des Scopes von Task 9 und sollte unveraendert bleiben"
        )
    }
}
#endif
