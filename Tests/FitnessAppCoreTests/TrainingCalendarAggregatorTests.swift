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

    // MARK: - DEL-203 Wochenziel

    func testGoalOfThreeRequiresThreeWorkoutsPerWeek() {
        // Vorwoche (01.-07.06.): 3 Workouts ✓, Woche davor: nur 2 ✗.
        let dates = [
            date(2026, 5, 26), date(2026, 5, 28),                      // KW 25.05.: 2
            date(2026, 6, 1), date(2026, 6, 3), date(2026, 6, 5),      // KW 01.06.: 3
        ]
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: dates,
            now: date(2026, 6, 8),   // Mo der Folgewoche (leer → Grace)
            calendar: calendar,
            goalPerWeek: 3
        )
        XCTAssertEqual(streak, 1, "nur die 3er-Woche erfüllt das Ziel")
    }

    func testGoalDefaultMatchesOldBehaviour() {
        // goalPerWeek default (1) == altes "mindestens 1 Workout"-Verhalten.
        let dates = [date(2026, 5, 26), date(2026, 6, 2), date(2026, 6, 9)]
        let explicit = TrainingCalendarAggregator.weekStreak(
            workoutDates: dates, now: date(2026, 6, 10),
            calendar: calendar, goalPerWeek: 1
        )
        let implicit = TrainingCalendarAggregator.weekStreak(
            workoutDates: dates, now: date(2026, 6, 10), calendar: calendar
        )
        XCTAssertEqual(explicit, 3)
        XCTAssertEqual(implicit, explicit)
    }

    func testCurrentWeekBelowGoalDoesNotBreakStreak() {
        // Ziel 2: Vorwochen je 2 ✓✓, aktuelle Woche erst 1 → Grace, Streak 2.
        let dates = [
            date(2026, 5, 26), date(2026, 5, 28),   // KW 25.05.: 2 ✓
            date(2026, 6, 2),  date(2026, 6, 4),    // KW 01.06.: 2 ✓
            date(2026, 6, 8),                        // KW 08.06.: erst 1
        ]
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: dates,
            now: date(2026, 6, 10),
            calendar: calendar,
            goalPerWeek: 2
        )
        XCTAssertEqual(streak, 2)
    }

    func testCurrentWeekMeetingGoalCountsImmediately() {
        // Ziel 2, aktuelle Woche hat schon 2 → zählt sofort mit.
        let dates = [
            date(2026, 6, 2), date(2026, 6, 4),     // KW 01.06.: 2 ✓
            date(2026, 6, 8), date(2026, 6, 9),     // KW 08.06.: 2 ✓
        ]
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: dates,
            now: date(2026, 6, 10),
            calendar: calendar,
            goalPerWeek: 2
        )
        XCTAssertEqual(streak, 2)
    }

    func testGoalZeroIsClampedToOne() {
        let streak = TrainingCalendarAggregator.weekStreak(
            workoutDates: [date(2026, 6, 9)],
            now: date(2026, 6, 10),
            calendar: calendar,
            goalPerWeek: 0
        )
        XCTAssertEqual(streak, 1, "goal < 1 wird auf 1 geklemmt, nicht endlos")
    }
}
