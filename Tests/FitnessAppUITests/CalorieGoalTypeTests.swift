#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
@testable import FitnessAppUI

/// writing-block.md Punkt 5 ("Tagesziel-Rechner um Bulk/Cut ergaenzen"):
/// `CalorieGoalType` centralizes the cut/maintenance/bulk adjustment that
/// used to be three magic numbers inline in `TDEEView.resultsCard` — both
/// `TDEEView`'s result rows and `NutritionGoalsView`'s "Aus TDEE übernehmen"
/// now compute through this one function.
@available(iOS 17.0, macOS 14.0, *)
final class CalorieGoalTypeTests: XCTestCase {

    func testMaintenanceAddsNoAdjustment() {
        XCTAssertEqual(CalorieGoalType.maintenance.dailyGoalKcal(tdee: 2500), 2500)
    }

    func testCutSubtractsFiveHundred() {
        XCTAssertEqual(CalorieGoalType.cut.dailyGoalKcal(tdee: 2500), 2000)
    }

    func testBulkAddsThreeHundred() {
        XCTAssertEqual(CalorieGoalType.bulk.dailyGoalKcal(tdee: 2500), 2800)
    }

    /// Final-review ruling: project-wide truncate-not-round convention
    /// applies here too — 2500.9 must become 2500, not 2501, before the
    /// adjustment is added.
    func testTruncatesTheRawTDEEBeforeAdjustingNotRounding() {
        XCTAssertEqual(CalorieGoalType.maintenance.dailyGoalKcal(tdee: 2500.9), 2500)
        XCTAssertEqual(CalorieGoalType.bulk.dailyGoalKcal(tdee: 2500.9), 2800)
    }

    func testEachCaseHasADistinctAdjustment() {
        let adjustments = Set(CalorieGoalType.allCases.map(\.adjustmentKcal))
        XCTAssertEqual(adjustments.count, CalorieGoalType.allCases.count, "jede Zielart muss ein eindeutig unterscheidbares Ergebnis liefern")
    }
}
#endif
