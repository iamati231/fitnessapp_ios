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
    /// einen Stelle deckt beide Konsumenten ab. Review-Nachbesserung
    /// (fuenfte Runde): `allPlans` laedt laut der eigenen DEL-047-Doku (siehe
    /// `allPlans`-Deklaration) BEWUSST auch inaktive Plaene - ungefiltert an
    /// `ActivePlanResolver` durchgereicht, haette z.B. ein einzelner
    /// deaktivierter Cardio-Coach-Plan in der Bibliothek den case-1-Zweig
    /// getroffen und wurde faelschlich zurueckgeliefert. Diese Assertion
    /// prueft deshalb explizit die GEFILTERTE Eingabe, nicht nur dass die
    /// Resolver-Funktion ueberhaupt aufgerufen wird.
    func testActivePlanUsesActivePlanResolver() throws {
        let source = try contents(of: "Settings/ProfileEditorView.swift")
        guard let propertyRange = source.range(of: "private var activePlan: TrainingPlan? {") else {
            XCTFail("activePlan property not found")
            return
        }
        let body = source[propertyRange.upperBound...].prefix(100)
        XCTAssertTrue(
            body.contains("ActivePlanResolver.cardioRelevantPlan(among: allPlans.filter(\\.isActive))"),
            "activePlan muss ActivePlanResolver.cardioRelevantPlan(among: allPlans.filter(\\.isActive)) verwenden - allPlans allein enthaelt auch inaktive Plaene (DEL-047)"
        )
        XCTAssertFalse(
            body.contains("allPlans.first"),
            "activePlan darf allPlans.first nicht mehr direkt verwenden"
        )
    }

    /// Haelt fest, dass `allPlans` bewusst auch inaktive Plaene laedt (DEL-047,
    /// Trainingsort-Sync) - diese Doku ist die Grundlage dafuer, warum
    /// `.filter(\.isActive)` an der `activePlan`-Aufrufstelle zwingend ist,
    /// nicht optional. Faellt dieser Test aus, weil sich die Query geaendert
    /// hat, muss die `.filter(\.isActive)`-Notwendigkeit oben neu bewertet
    /// werden.
    func testAllPlansQueryLoadsAllPlansIncludingInactiveOnes() throws {
        let source = try contents(of: "Settings/ProfileEditorView.swift")
        XCTAssertTrue(
            source.contains("@Query(sort: \\TrainingPlan.name)\n    private var allPlans: [TrainingPlan]"),
            "allPlans muss weiterhin ungefiltert (auch inaktive Plaene) laden - sonst ist die Praemisse fuer die .filter(\\.isActive)-Notwendigkeit oben ungueltig"
        )
    }
}
#endif
