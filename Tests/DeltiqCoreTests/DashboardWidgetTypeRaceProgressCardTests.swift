import XCTest
@testable import DeltiqCore

/// Dashboard-Fix "doppelte Coach-Karten" (siehe Abschlussbericht): die
/// Wettkampf-Fortschritts-Karte war fest an `.runCoachCard` gehaengt statt
/// ein eigener, unabhaengig konfigurierbarer Widget-Typ zu sein.
final class DashboardWidgetTypeRaceProgressCardTests: XCTestCase {

    func testRaceProgressCardCaseExistsAndHasLocalizationKey() {
        XCTAssertEqual(DashboardWidgetType.raceProgressCard.localizationKey, "widget.raceProgressCard.name")
    }

    func testRaceProgressCardIsPartOfDefaultOrderForNewInstalls() {
        XCTAssertTrue(DashboardWidgetType.defaultOrder.contains(.raceProgressCard))
    }

    func testRaceProgressCardAppearsAfterRunCoachCardInDefaultOrder() {
        let order = DashboardWidgetType.defaultOrder
        guard let runIdx = order.firstIndex(of: .runCoachCard),
              let raceIdx = order.firstIndex(of: .raceProgressCard) else {
            XCTFail("runCoachCard oder raceProgressCard fehlt in defaultOrder")
            return
        }
        XCTAssertGreaterThan(raceIdx, runIdx,
                             "raceProgressCard soll nach runCoachCard in defaultOrder stehen")
    }

    func testExistingUserRawListWithoutRaceProgressCardStaysUnaffected() {
        let legacyRaw = ["nextWorkout", "coachingInsight", "runCoachCard"]
        let decoded = legacyRaw.compactMap { DashboardWidgetType(rawValue: $0) }
        XCTAssertFalse(decoded.contains(.raceProgressCard),
                       "Bestandsnutzer ohne raceProgressCard im gespeicherten Array erhalten ihn nicht automatisch")
    }

    /// Beide Lauf-Coaching-Karten sind unabhaengige, verschiedene Cases -
    /// keine Karte kann die andere stillschweigend verdraengen.
    func testRaceProgressCardAndRunCoachCardAreDistinctCases() {
        XCTAssertNotEqual(DashboardWidgetType.raceProgressCard, DashboardWidgetType.runCoachCard)
    }
}
