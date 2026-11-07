#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
@testable import DeltiqUI

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CardioRaceCalendarValuesTests: XCTestCase {

    // Gregorian UTC calendar for deterministic week boundary behaviour.
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(year: Int, month: Int, day: Int) -> Date {
        DateComponents(calendar: cal, year: year, month: month, day: day).date!
    }

    func testNoRaceDateGivesNil() {
        let (days, weeks) = cardioRaceCalendarValues(for: nil, now: date(year: 2026, month: 11, day: 7), calendar: cal)
        XCTAssertNil(days)
        XCTAssertNil(weeks)
    }

    func testPastRaceGivesNil() {
        let now = date(year: 2026, month: 11, day: 7)
        let race = date(year: 2026, month: 11, day: 6)
        let (days, weeks) = cardioRaceCalendarValues(for: race, now: now, calendar: cal)
        XCTAssertNil(days)
        XCTAssertNil(weeks)
    }

    func testRaceTodayGivesDaysZeroWeeksZero() {
        let today = date(year: 2026, month: 11, day: 7)
        let (days, weeks) = cardioRaceCalendarValues(for: today, now: today, calendar: cal)
        XCTAssertEqual(days, 0)
        XCTAssertEqual(weeks, 0)
    }

    func testRaceTomorrowGivesDaysOne() {
        let now = date(year: 2026, month: 11, day: 7)
        let race = date(year: 2026, month: 11, day: 8)
        let (days, _) = cardioRaceCalendarValues(for: race, now: now, calendar: cal)
        XCTAssertEqual(days, 1)
    }

    func testRaceIn14DaysGivesDays14() {
        let now = date(year: 2026, month: 11, day: 7)
        let race = date(year: 2026, month: 11, day: 21)
        let (days, _) = cardioRaceCalendarValues(for: race, now: now, calendar: cal)
        XCTAssertEqual(days, 14)
    }

    func testRaceIn15DaysGivesDays15() {
        let now = date(year: 2026, month: 11, day: 7)
        let race = date(year: 2026, month: 11, day: 22)
        let (days, _) = cardioRaceCalendarValues(for: race, now: now, calendar: cal)
        XCTAssertEqual(days, 15)
    }

    // Nov 7 2026 is Saturday (week 45), Nov 9 is Monday (week 46).
    // days = 2, old code 2/7 = 0 (WRONG), new code weekOfYear diff = 1 (CORRECT).
    func testWeekBoundaryCrossedGivesWeeks1NotZero() {
        let now = date(year: 2026, month: 11, day: 7)   // Saturday
        let race = date(year: 2026, month: 11, day: 9)  // Monday
        let (days, weeks) = cardioRaceCalendarValues(for: race, now: now, calendar: cal)
        XCTAssertEqual(days, 2)
        XCTAssertEqual(weeks, 1, "2 days spanning a week boundary must count as 1 calendar week, not 0")
    }
}
#endif
