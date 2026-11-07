import XCTest
@testable import DeltiqCore

final class DashboardWidgetTypeRunCoachCardTests: XCTestCase {

    func testRunCoachCardCaseExistsAndHasLocalizationKey() {
        XCTAssertEqual(DashboardWidgetType.runCoachCard.localizationKey, "widget.runCoachCard.name")
    }

    func testRunCoachCardIsPartOfDefaultOrderForNewInstalls() {
        XCTAssertTrue(DashboardWidgetType.defaultOrder.contains(.runCoachCard))
    }

    func testRunCoachCardAppearsAfterNextWorkoutInDefaultOrder() {
        let order = DashboardWidgetType.defaultOrder
        guard let nextIdx = order.firstIndex(of: .nextWorkout),
              let runIdx = order.firstIndex(of: .runCoachCard) else {
            XCTFail("nextWorkout oder runCoachCard fehlt in defaultOrder")
            return
        }
        XCTAssertGreaterThan(runIdx, nextIdx,
                             "runCoachCard soll nach nextWorkout in defaultOrder stehen")
    }

    func testExistingUserRawListWithoutRunCoachCardStaysUnaffected() {
        let legacyRaw = ["nextWorkout", "coachingInsight", "weeklyVolume"]
        let decoded = legacyRaw.compactMap { DashboardWidgetType(rawValue: $0) }
        XCTAssertFalse(decoded.contains(.runCoachCard),
                       "Bestandsnutzer ohne runCoachCard im gespeicherten Array erhalten ihn nicht automatisch")
    }
}
