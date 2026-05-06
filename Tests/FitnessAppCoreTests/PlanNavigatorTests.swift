import XCTest
@testable import FitnessAppCore

private struct TestDay: WeekdayProvider, Equatable {
    let weekday: Int
    let label: String
}

final class PlanNavigatorTests: XCTestCase {

    // MARK: europeanWeekdayOrder

    func testEuropeanOrderMondayIsFirst() {
        XCTAssertEqual(PlanNavigator.europeanWeekdayOrder(2), 0, "Monday → 0")
    }

    func testEuropeanOrderSundayIsLast() {
        XCTAssertEqual(PlanNavigator.europeanWeekdayOrder(1), 6, "Sunday → 6")
    }

    func testEuropeanOrderSaturdayIsSecondToLast() {
        XCTAssertEqual(PlanNavigator.europeanWeekdayOrder(7), 5, "Saturday → 5")
    }

    // MARK: sortByWeekdayMondayFirst

    func testSortPlacesMondayFirstSundayLast() {
        let days = [
            TestDay(weekday: 1, label: "So"),  // Sun
            TestDay(weekday: 3, label: "Di"),  // Tue
            TestDay(weekday: 7, label: "Sa"),  // Sat
            TestDay(weekday: 2, label: "Mo")   // Mon
        ]
        let sorted = PlanNavigator.sortByWeekdayMondayFirst(days).map(\.label)
        XCTAssertEqual(sorted, ["Mo", "Di", "Sa", "So"])
    }

    func testSortIsStableForEqualWeekdays() {
        // Two days both at weekday=2 (Monday) — input order should be preserved.
        let days = [
            TestDay(weekday: 2, label: "Push A"),
            TestDay(weekday: 4, label: "Pull"),
            TestDay(weekday: 2, label: "Push B")  // also Monday
        ]
        let sorted = PlanNavigator.sortByWeekdayMondayFirst(days).map(\.label)
        XCTAssertEqual(sorted, ["Push A", "Push B", "Pull"])
    }

    func testSortEmptyArray() {
        let result: [TestDay] = PlanNavigator.sortByWeekdayMondayFirst([])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: nextScheduledIndex

    func testNextIndexFirstSession() {
        XCTAssertEqual(PlanNavigator.nextScheduledIndex(dayCount: 3, completedSessions: 0), 0)
    }

    func testNextIndexRotatesThroughDays() {
        // 3-day plan: completed 0,1,2 → next index 0,1,2; completed 3,4,5 → 0,1,2 again
        XCTAssertEqual(PlanNavigator.nextScheduledIndex(dayCount: 3, completedSessions: 1), 1)
        XCTAssertEqual(PlanNavigator.nextScheduledIndex(dayCount: 3, completedSessions: 2), 2)
        XCTAssertEqual(PlanNavigator.nextScheduledIndex(dayCount: 3, completedSessions: 3), 0)
        XCTAssertEqual(PlanNavigator.nextScheduledIndex(dayCount: 3, completedSessions: 4), 1)
    }

    func testNextIndexNilForZeroDays() {
        XCTAssertNil(PlanNavigator.nextScheduledIndex(dayCount: 0, completedSessions: 5))
    }

    func testNegativeCompletedClampsToZero() {
        // Defensive — should never happen in the app, but guard prevents Int modulo crash
        XCTAssertEqual(PlanNavigator.nextScheduledIndex(dayCount: 3, completedSessions: -10), 0)
    }
}
