#if canImport(SwiftUI)
import XCTest

/// Phase E Regressionstests: Filterkorrektheit von `daysSinceLastRunSession`
/// und `priorRunSessionCount` in DashboardView.
///
/// Die beiden computed vars sind private und koennen nicht direkt aufgerufen
/// werden — Source-Introspection (gleiches Muster wie
/// `DashboardActivePlanDeterminismTests` / `DashboardCardioCardPriorityTests`)
/// sichert die Filterbedingungen gegen spaeteren Abbau ab.
///
/// Test A: Krafttraining-Sessions (keine Cardio-Logs) duerfen den
/// Lauf-Zaehler und den Lauf-Abstand nicht beeinflussen.
/// Test B: Unvollstaendige Lauf-Sessions (isCompleted == false) duerfen
/// nicht als "zurueckliegender Lauf" gewertet werden.
final class DashboardRunReEntryFilterTests: XCTestCase {

    private var dashboardSource: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // this file
                .deletingLastPathComponent() // DeltiqUITests
                .deletingLastPathComponent() // Tests
                .appendingPathComponent("Sources/DeltiqUI/DashboardView.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    private func body(of propertyName: String, in source: String, maxLength: Int = 500) -> Substring? {
        guard let range = source.range(of: "private var \(propertyName)") else { return nil }
        return source[range.lowerBound...].prefix(maxLength)
    }

    // MARK: - Test A: Krafttraining darf Lauf-Filter nicht umgehen

    /// `daysSinceLastRunSession` muss auf Sessions einschraenken, die
    /// mindestens ein Cardio-Log enthalten. Fehlt diese Bedingung, wuerden
    /// Krafttraining-Sessions den letzten "Lauf" faelschlich zuruecksetzen.
    func testDaysSinceLastRunSessionFiltersOnCardioLogs() throws {
        let source = try dashboardSource
        guard let propertyBody = body(of: "daysSinceLastRunSession", in: source) else {
            XCTFail("daysSinceLastRunSession nicht in DashboardView gefunden")
            return
        }
        XCTAssertTrue(
            propertyBody.contains("resolvedIsCardio"),
            "daysSinceLastRunSession muss resolvedIsCardio pruefen — sonst zaehlen Krafttraining-Sessions als letzter Lauf"
        )
    }

    /// `priorRunSessionCount` muss ebenfalls auf Cardio-Logs einschraenken,
    /// damit Krafttraining-Sessions die Lauf-Anzahl nicht erhoehen.
    func testPriorRunSessionCountFiltersOnCardioLogs() throws {
        let source = try dashboardSource
        guard let propertyBody = body(of: "priorRunSessionCount", in: source) else {
            XCTFail("priorRunSessionCount nicht in DashboardView gefunden")
            return
        }
        XCTAssertTrue(
            propertyBody.contains("resolvedIsCardio"),
            "priorRunSessionCount muss resolvedIsCardio pruefen — sonst zaehlen Krafttraining-Sessions als Lauf-Sessions"
        )
    }

    // MARK: - Test B: Unvollstaendige Sessions duerfen nicht zaehlen

    /// `daysSinceLastRunSession` muss `isRealWorkout` pruefen (= isCompleted
    /// && !isRestDay). Fehlt diese Bedingung, wuerden abgebrochene oder noch
    /// aktive Lauf-Sessions den Abstand faelschlich auf 0 setzen.
    func testDaysSinceLastRunSessionRequiresRealWorkout() throws {
        let source = try dashboardSource
        guard let propertyBody = body(of: "daysSinceLastRunSession", in: source) else {
            XCTFail("daysSinceLastRunSession nicht in DashboardView gefunden")
            return
        }
        XCTAssertTrue(
            propertyBody.contains("isRealWorkout"),
            "daysSinceLastRunSession muss isRealWorkout pruefen — sonst zaehlen unvollstaendige Sessions als letzter Lauf"
        )
    }

    /// `priorRunSessionCount` muss `isRealWorkout` pruefen, damit
    /// abgebrochene Lauf-Sessions den Anfaenger-Guard nicht faelschlich
    /// uebergehen.
    func testPriorRunSessionCountRequiresRealWorkout() throws {
        let source = try dashboardSource
        guard let propertyBody = body(of: "priorRunSessionCount", in: source) else {
            XCTFail("priorRunSessionCount nicht in DashboardView gefunden")
            return
        }
        XCTAssertTrue(
            propertyBody.contains("isRealWorkout"),
            "priorRunSessionCount muss isRealWorkout pruefen — sonst zaehlen unvollstaendige Sessions als Lauf-Sessions"
        )
    }

    // MARK: - Prioritaetskette: cardioReEntry vor generischem reEntry

    /// Der Lauf-Wiedereinstieg muss im Switch/Computed-Property frueher
    /// geprueft werden als der allgemeine Wiedereinstieg (`reEntry`), damit
    /// ein Laeufer mit >= 14 Tagen Pause den laufspezifischen Text bekommt
    /// und nicht den generischen Kraft-Text.
    func testCardioReEntryCheckedBeforeGenericReEntry() throws {
        let source = try dashboardSource
        guard let cardioIdx = source.range(of: ".cardioReEntry")?.lowerBound,
              let reEntryIdx = source.range(of: "return .reEntry")?.lowerBound else {
            XCTFail("cardioReEntry oder reEntry nicht in DashboardView gefunden")
            return
        }
        XCTAssertLessThan(
            cardioIdx, reEntryIdx,
            ".cardioReEntry muss im activeSoftCoachingContext vor return .reEntry geprueft werden"
        )
    }
}
#endif
