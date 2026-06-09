import XCTest
@testable import FitnessAppCore

final class TrainingCalendarAggregatorTests: XCTestCase {

    /// Fixe Kalender-Basis (DE-Konvention, Montag-Start) — Tests dürfen
    /// nicht vom Geräte-Locale des CI-Runners abhängen.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2   // Montag
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    // MARK: workoutDays

    func testWorkoutDaysNormalizesToStartOfDay() {
        let days = TrainingCalendarAggregator.workoutDays(
            of: [date(2026, 6, 1, hour: 7), date(2026, 6, 1, hour: 19), date(2026, 6, 3)],
            calendar: calendar
        )
        XCTAssertEqual(days.count, 2)   // zwei Sessions am selben Tag = ein Dot
        XCTAssertTrue(days.contains(calendar.startOfDay(for: date(2026, 6, 1))))
    }

    // MARK: weekStreak

    func testEmptyDatesGiveZeroStreak() {
        XCTAssertEqual(
            TrainingCalendarAggregator.weekStreak(workoutDates: [], now: date(2026, 6, 10), calendar: calendar),
            0
        )
    }

    func testSingleWorkoutThisWeekGivesOne() {
        // Mi 10.06.2026; Workout am Mo 08.06. (gleiche Woche)
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: [date(2026, 6, 8)],
            now: date(2026, 6, 10),
            calendar: calendar
        )
        XCTAssertEqual(streak, 1)
    }

    func testThreeConsecutiveWeeks() {
        // Workouts in KW des 25.05., 01.06., 08.06. — now Mi 10.06.
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: [date(2026, 5, 26), date(2026, 6, 2), date(2026, 6, 9)],
            now: date(2026, 6, 10),
            calendar: calendar
        )
        XCTAssertEqual(streak, 3)
    }

    func testCurrentWeekEmptyDoesNotBreakStreak() {
        // now = Mo 08.06., noch kein Workout diese Woche — Streak läuft
        // über die Vorwochen weiter (Grace), zählt aber die laufende
        // Woche nicht mit.
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: [date(2026, 5, 26), date(2026, 6, 2)],
            now: date(2026, 6, 8),
            calendar: calendar
        )
        XCTAssertEqual(streak, 2)
    }

    func testFullyElapsedEmptyWeekBreaksStreak() {
        // Workouts KW 18.05. und KW 01.06., Lücke KW 25.05. — now 10.06.
        // → Streak = nur die KW vom 01.06. + aktuelle? Aktuelle (08.06.)
        // ist leer → Grace → zählt ab KW 01.06. = 1.
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: [date(2026, 5, 19), date(2026, 6, 2)],
            now: date(2026, 6, 10),
            calendar: calendar
        )
        XCTAssertEqual(streak, 1)
    }

    func testMultipleWorkoutsSameWeekCountOnce() {
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: [date(2026, 6, 8), date(2026, 6, 9), date(2026, 6, 10)],
            now: date(2026, 6, 10),
            calendar: calendar
        )
        XCTAssertEqual(streak, 1)
    }

    func testOldWorkoutsAfterLongGapGiveZero() {
        // Letztes Workout vor 6 Wochen, aktuelle + Vorwoche leer → 0.
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: [date(2026, 4, 20)],
            now: date(2026, 6, 10),
            calendar: calendar
        )
        XCTAssertEqual(streak, 0)
    }
}
