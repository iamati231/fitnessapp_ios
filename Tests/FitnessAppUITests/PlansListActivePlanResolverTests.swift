#if canImport(SwiftUI)
import XCTest

/// Task 9 (docs/superpowers/sdd/2026-10-25-equipment-vielfalt-laufcoaching-dual-path,
/// Review-Nachbesserung): `PlansListView` hatte zwei eigene Twins desselben
/// Bugs, nur unter dem anderen, nicht nach `activePlans.first` gegreppten
/// Idiom `plans.first(where: \.isActive)` - `plans` ist hier der
/// clientseitig (alphabetisch, aktive-zuerst) sortierte `@Query`-Wrapper
/// dieser View, also eine ANDERE, ebenso willkuerliche Regel als Dashboards
/// damaliges `@Query`-Reihenfolge-`.first`. Source-introspection (kein
/// SwiftUI-Render-Harness in diesem Repo), gleiches Muster wie
/// `DashboardActivePlanDeterminismTests`.
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

    /// Dasselbe Sheet wie `DashboardView`s Laufversaeumnis-Karte (siehe
    /// Kommentar direkt darueber in `PlansListView.swift`) - muss denselben
    /// Resolver verwenden. Review-Nachbesserung (fuenfte Runde): `plans` ist
    /// nur aktive-ZUERST SORTIERT (siehe `plans`-Doku, Zeile 19-27), NICHT
    /// auf aktive gefiltert - `ActivePlanResolver` erzwingt "unter den
    /// aktiven Plaenen" nicht selbst, nur der Aufrufer kann das. Ohne
    /// `.filter(\.isActive)` wuerde z.B. ein deaktivierter Cardio-Coach-Plan
    /// in der Bibliothek faelschlich den case-1-Zweig treffen. Diese
    /// Assertion prueft deshalb explizit die GEFILTERTE Eingabe, nicht nur
    /// dass die Resolver-Funktion ueberhaupt aufgerufen wird.
    func testCoachAdjustmentPreviewSheetUsesActivePlanResolver() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        guard let sheetRange = source.range(of: ".sheet(isPresented: $showingCoachAdjustmentPreview)") else {
            XCTFail("showingCoachAdjustmentPreview-Sheet nicht gefunden")
            return
        }
        let body = source[sheetRange.upperBound...].prefix(400)
        XCTAssertTrue(
            body.contains("let activePlan = ActivePlanResolver.cardioRelevantPlan(among: plans.filter(\\.isActive))"),
            "das Sheet muss ActivePlanResolver.cardioRelevantPlan(among: plans.filter(\\.isActive)) verwenden - plans allein ist nur sortiert, nicht gefiltert"
        )
        XCTAssertFalse(
            body.contains("plans.first(where:"),
            "das Sheet darf plans.first(where: \\.isActive) nicht mehr direkt verwenden"
        )
    }

    /// `coachAdjustmentModel` ist der literale Twin der Dashboard-Karten-
    /// Quelle (identischer `CoachAdjustmentCardModel.make`-Aufruf, dieselbe
    /// Vorrang-Rolle vor `CardioFeasibilityCardModel`). Gleicher
    /// ungefilterte-Eingabe-Blindspot wie oben - siehe Doku dort.
    func testCoachAdjustmentModelUsesActivePlanResolver() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        guard let propertyRange = source.range(of: "private var coachAdjustmentModel: CoachAdjustmentCardModel? {") else {
            XCTFail("coachAdjustmentModel nicht gefunden")
            return
        }
        let body = source[propertyRange.upperBound...].prefix(300)
        XCTAssertTrue(
            body.contains("let activePlan = ActivePlanResolver.cardioRelevantPlan(among: plans.filter(\\.isActive))"),
            "coachAdjustmentModel muss ActivePlanResolver.cardioRelevantPlan(among: plans.filter(\\.isActive)) verwenden - plans allein ist nur sortiert, nicht gefiltert"
        )
        XCTAssertFalse(
            body.contains("plans.first(where:"),
            "coachAdjustmentModel darf plans.first(where: \\.isActive) nicht mehr direkt verwenden"
        )
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
