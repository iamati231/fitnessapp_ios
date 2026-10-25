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
///
/// Nachbesserung (Controller-Entscheidung nach Task-9-Report): zusaetzlich
/// zu den urspruenglichen 2 Cardio-Karten-Aufrufstellen gehoeren auch das
/// `CoachAdjustmentPreviewView`-Sheet (dieselbe View, die die Karten-CTAs
/// oeffnen) und die "Long Run ueberfaellig"-Erkennung zum Scope - beide
/// haetten sonst weiterhin unabhaengig von der Karte eine abweichende
/// Plan-Auswahl treffen koennen.
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

    /// Das `.sheet(isPresented: $showingMissedRunAdjustmentPreview)`, das von
    /// BEIDEN Karten-CTAs geoeffnet wird (siehe Doku auf
    /// `laufcoachingAdjustmentCard`: "das Sheet loest Profil/Plan selbst
    /// frisch aus der Query auf") - muss DENSELBEN Resolver verwenden wie die
    /// Karte selbst, sonst koennten Karte und Sheet bei mehreren aktiven
    /// Plaenen unterschiedliche Plaene meinen.
    func testMissedRunAdjustmentPreviewSheetUsesActivePlanResolver() throws {
        let source = try contents(of: "DashboardView.swift")
        guard let sheetRange = source.range(of: ".sheet(isPresented: $showingMissedRunAdjustmentPreview)") else {
            XCTFail("showingMissedRunAdjustmentPreview-Sheet nicht gefunden")
            return
        }
        let body = source[sheetRange.upperBound...].prefix(400)
        XCTAssertTrue(
            body.contains("let plan = ActivePlanResolver.cardioRelevantPlan(among: activePlans)"),
            "das Sheet muss ActivePlanResolver.cardioRelevantPlan(among:) verwenden statt activePlans.first"
        )
        XCTAssertFalse(
            body.contains("activePlans.first"),
            "das Sheet darf activePlans.first nicht mehr direkt verwenden"
        )
    }

    /// `isLongRunOverdueForActivePlan` (DEL-248, `.cardioMissedLongRun`) ist
    /// eine eigene Cardio-Karten-Aufrufstelle (separate Soft-Coaching-
    /// Kontext-Prioritaet neben `.cardioMissedRunDays`) und muss denselben
    /// Resolver verwenden.
    func testLongRunOverdueCheckUsesActivePlanResolver() throws {
        let source = try contents(of: "DashboardView.swift")
        guard let propertyRange = source.range(of: "private var isLongRunOverdueForActivePlan: Bool {") else {
            XCTFail("isLongRunOverdueForActivePlan nicht gefunden")
            return
        }
        let body = source[propertyRange.upperBound...].prefix(200)
        XCTAssertTrue(
            body.contains("let plan = ActivePlanResolver.cardioRelevantPlan(among: activePlans)"),
            "isLongRunOverdueForActivePlan muss ActivePlanResolver.cardioRelevantPlan(among:) verwenden statt activePlans.first"
        )
        XCTAssertFalse(
            body.contains("activePlans.first"),
            "isLongRunOverdueForActivePlan darf activePlans.first nicht mehr direkt verwenden"
        )
    }

    /// Die urspruenglichen 2 Cardio-Karten-Aufrufstellen duerfen nicht mehr
    /// direkt `activePlans.first` fuer die Plan-Auswahl benutzen (von den
    /// insgesamt 13 `activePlans.first`-Stellen im gesamten Repo sind jetzt
    /// 5 cardio-relevant und gefixt, die uebrigen 8 - 7 im Dashboard, 1 in
    /// `FourWeekReviewEntryView` - sind laut Plan ausdruecklich NICHT Teil
    /// dieses Tasks - siehe Task-9-Report fuer die vollstaendige
    /// Klassifizierung).
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
