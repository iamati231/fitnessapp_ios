import XCTest
@testable import FitnessAppCore

/// DEL-109: Sanity-Tests fuer den Dashboard-Widget-Enum. Hauptzweck:
/// sicherstellen, dass `defaultOrder` keinen Case vergisst, damit
/// neue User immer das volle Widget-Set sehen.
final class DashboardWidgetTypeTests: XCTestCase {

    /// Wenn jemand einen neuen Case in `DashboardWidgetType` hinzufuegt
    /// aber vergisst, `defaultOrder` zu aktualisieren, faengt dieser Test
    /// das. Defaults sind die Erst-User-Experience — kein Widget darf
    /// versehentlich versteckt werden.
    func testDefaultOrderCoversAllCases() {
        let allCases = Set(DashboardWidgetType.allCases)
        let inDefault = Set(DashboardWidgetType.defaultOrder)
        XCTAssertEqual(allCases, inDefault,
                       "DashboardWidgetType.defaultOrder muss alle Cases enthalten — neuer Case ohne Update?")
    }

    /// `defaultOrder` darf keine Duplikate haben — sonst rendert das
    /// Dashboard zweimal die selbe Card.
    func testDefaultOrderHasNoDuplicates() {
        let order = DashboardWidgetType.defaultOrder
        XCTAssertEqual(order.count, Set(order).count, "Duplikate in defaultOrder")
    }

    /// rawValues sind Persistenz-Schluessel — wenn jemand einen umbenennt,
    /// landen Bestands-User mit dem alten String im RAW-Array und der
    /// Widget faellt durch das `compactMap` raus. Snapshot-Test verhindert
    /// stille Renames.
    func testRawValueSnapshot() {
        XCTAssertEqual(DashboardWidgetType.nextWorkout.rawValue, "nextWorkout")
        XCTAssertEqual(DashboardWidgetType.coachingInsight.rawValue, "coachingInsight")
        XCTAssertEqual(DashboardWidgetType.trophyRoom.rawValue, "trophyRoom")
        XCTAssertEqual(DashboardWidgetType.workoutHistory.rawValue, "workoutHistory")
        XCTAssertEqual(DashboardWidgetType.weeklyVolume.rawValue, "weeklyVolume")
        XCTAssertEqual(DashboardWidgetType.muscleHeatmap.rawValue, "muscleHeatmap")
        XCTAssertEqual(DashboardWidgetType.weightTrend.rawValue, "weightTrend")
        XCTAssertEqual(DashboardWidgetType.compoundLifts.rawValue, "compoundLifts")
        XCTAssertEqual(DashboardWidgetType.cardioPace.rawValue, "cardioPace")
        XCTAssertEqual(DashboardWidgetType.recentWorkouts.rawValue, "recentWorkouts")
    }

    /// Localization-Key-Format ist stabil — Catalog-Lookups bauen darauf.
    func testLocalizationKeyFormat() {
        XCTAssertEqual(DashboardWidgetType.trophyRoom.localizationKey, "widget.trophyRoom.name")
        XCTAssertEqual(DashboardWidgetType.muscleHeatmap.localizationKey, "widget.muscleHeatmap.name")
    }
}
