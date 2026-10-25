#if canImport(SwiftUI)
import XCTest

/// Task 9 (docs/superpowers/sdd/2026-10-25-equipment-vielfalt-laufcoaching-dual-path):
/// das Dashboard waehlte den fuer die Cardio-Karten relevanten Plan bisher
/// ueber das nicht-deterministische `activePlans.first` - bei mehreren
/// gleichzeitig aktiven Plaenen (z.B. ein Laufcoaching-generierter Plan neben
/// einem aelteren, manuell erstellten) haengt das Ergebnis dann von der
/// (undokumentierten) `@Query`-Reihenfolge ab. `ActivePlanResolver` ersetzt
/// das durch eine einzige, dokumentierte Regel. Source-introspection (kein
/// SwiftUI-Render-Harness in diesem Repo), gleiches Muster wie
/// `DashboardCardioCardPriorityTests`/`MehrInformationArchitectureTests`.
final class DashboardActivePlanDeterminismTests: XCTestCase {

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

    /// Die fixe Coach-Anpassungs-Karte (Task 8, `laufcoachingAdjustmentCard`)
    /// muss ihren Plan ueber `ActivePlanResolver` beziehen, nicht mehr ueber
    /// `activePlans.first`.
    func testCoachAdjustmentCardUsesActivePlanResolver() throws {
        let source = try contents(of: "DashboardView.swift")
        XCTAssertTrue(
            source.contains("let activePlan = ActivePlanResolver.cardioRelevantPlan(among: activePlans)"),
            "die fixe Coach-Anpassungs-Karte muss ActivePlanResolver.cardioRelevantPlan(among:) verwenden"
        )
    }

    /// Das Laufversaeumnis-Modell (`missedRunDaysModel`, Paket 3a) muss
    /// ebenfalls ueber `ActivePlanResolver` gehen.
    func testMissedRunDaysModelUsesActivePlanResolver() throws {
        let source = try contents(of: "DashboardView.swift")
        guard let propertyRange = source.range(of: "private var missedRunDaysModel: MissedRunDaysCardModel? {") else {
            XCTFail("missedRunDaysModel nicht gefunden")
            return
        }
        let body = source[propertyRange.upperBound...].prefix(400)
        XCTAssertTrue(
            body.contains("ActivePlanResolver.cardioRelevantPlan(among: activePlans)"),
            "missedRunDaysModel muss ActivePlanResolver.cardioRelevantPlan(among:) verwenden statt activePlans.first"
        )
        XCTAssertFalse(
            body.contains("activePlans.first"),
            "missedRunDaysModel darf activePlans.first nicht mehr direkt verwenden"
        )
    }

    /// Beide Cardio-Karten-Aufrufstellen duerfen nicht mehr direkt
    /// `activePlans.first` fuer die Plan-Auswahl benutzen (die uebrigen 11
    /// von 13 `activePlans.first`-Stellen im Dashboard sind laut Plan
    /// ausdruecklich NICHT Teil dieses Tasks - siehe Task-9-Report fuer die
    /// vollstaendige Klassifizierung).
    func testNeitherCardioCardSiteStillUsesActivePlansFirstDirectly() throws {
        let source = try contents(of: "DashboardView.swift")
        XCTAssertFalse(
            source.contains("let activePlan = activePlans.first,"),
            "die Coach-Anpassungs-Karte darf activePlans.first nicht mehr direkt verwenden"
        )
        XCTAssertFalse(
            source.contains("activePlan: activePlans.first, in: modelContext"),
            "missedRunDaysModel darf activePlans.first nicht mehr direkt verwenden"
        )
    }
}
#endif
