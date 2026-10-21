import XCTest
@testable import FitnessAppCore

final class DashboardWidgetTypeNutritionTests: XCTestCase {
    func testNutritionCaseExistsAndHasLocalizationKey() {
        XCTAssertEqual(DashboardWidgetType.nutrition.localizationKey, "widget.nutrition.name")
    }

    func testNutritionIsPartOfDefaultOrderForNewInstalls() {
        XCTAssertTrue(DashboardWidgetType.defaultOrder.contains(.nutrition))
    }

    func testExistingUserRawListWithoutNutritionStaysUnaffected() {
        // Simuliert einen Bestandsnutzer: sein gespeichertes Raw-Array enthaelt
        // "nutrition" nicht. Der typed accessor (UserBodyProfile.activeDashboardWidgets,
        // Data-Layer) filtert nur auf bekannte rawValues — hier wird nur geprueft,
        // dass ein Bestands-Array ohne den neuen Case ihn nicht automatisch erhaelt.
        let legacyRaw = ["nextWorkout", "coachingInsight"]
        let decoded = legacyRaw.compactMap { DashboardWidgetType(rawValue: $0) }
        XCTAssertFalse(decoded.contains(.nutrition))
    }
}
