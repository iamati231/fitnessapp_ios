import XCTest
@testable import DeltiqCore

final class MuscleGroupProgressCalculatorTests: XCTestCase {

    // MARK: - Helpers

    typealias Calc = MuscleGroupProgressCalculator
    typealias Set = MuscleGroupProgressCalculator.MuscleLoggedSet

    private func date(_ y: Int, _ m: Int, _ d: Int, tz: String = "UTC") -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: tz)!
        return cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func strengthSet(
        on day: Date,
        muscle: MuscleGroup? = .chest,
        name: String = "Bench Press"
    ) -> Set {
        .init(date: day, exerciseName: name, muscleGroup: muscle, isCardio: false)
    }

    private func cardioSet(on day: Date) -> Set {
        .init(date: day, exerciseName: "Running", muscleGroup: nil, isCardio: true)
    }

    // MARK: - 1. Cardio sets excluded

    func test_cardioSetsAreExcluded() {
        let now = date(2024, 6, 10)
        let sets = [
            strengthSet(on: date(2024, 6, 5), muscle: .chest),
            cardioSet(on: date(2024, 6, 6)),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        XCTAssertEqual(stats.totalWorkingSets, 1)
    }

    // MARK: - 2. Period boundary — 4W includes only the last 4 weeks

    func test_fourWeekBoundary() {
        let now = date(2024, 6, 10)
        let inWindow = date(2024, 5, 20)
        let outWindow = date(2024, 5, 10)   // > 4 weeks before now
        let sets = [
            strengthSet(on: inWindow, muscle: .back),
            strengthSet(on: outWindow, muscle: .back),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .fourWeeks, now: now)
        XCTAssertEqual(stats.totalWorkingSets, 1)
    }

    // MARK: - 3. Period boundary — 12W

    func test_twelveWeekBoundary() {
        let now = date(2024, 6, 10)
        let inWindow = date(2024, 4, 1)      // ~10 weeks ago
        let outWindow = date(2024, 2, 1)     // ~18 weeks ago
        let sets = [
            strengthSet(on: inWindow, muscle: .shoulders),
            strengthSet(on: outWindow, muscle: .shoulders),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .twelveWeeks, now: now)
        XCTAssertEqual(stats.totalWorkingSets, 1)
    }

    // MARK: - 4. Period boundary — 1Y

    func test_oneYearBoundary() {
        let now = date(2024, 6, 10)
        let inWindow = date(2023, 7, 1)     // ~11 months ago
        let outWindow = date(2023, 5, 1)    // ~13 months ago
        let sets = [
            strengthSet(on: inWindow, muscle: .quads),
            strengthSet(on: outWindow, muscle: .quads),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .oneYear, now: now)
        XCTAssertEqual(stats.totalWorkingSets, 1)
    }

    // MARK: - 5. allTime shows everything including old data (> 3 years)

    func test_allTimeShowsOldLogs() {
        let now = date(2024, 6, 10)
        let veryOld = date(2020, 1, 15)
        let sets = [
            strengthSet(on: veryOld, muscle: .glutes),
            strengthSet(on: date(2024, 6, 5), muscle: .glutes),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        XCTAssertEqual(stats.totalWorkingSets, 2)
    }

    // MARK: - 6. Future-dated sets excluded from all periods

    func test_futureSetsExcluded() {
        let now = date(2024, 6, 10)
        let future = date(2024, 6, 20)
        let sets = [
            strengthSet(on: future, muscle: .chest),
            strengthSet(on: date(2024, 6, 5), muscle: .chest),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        XCTAssertEqual(stats.totalWorkingSets, 1)
    }

    // MARK: - 7. Two sets in same workout counted as 2 sets

    func test_twoSetsInSameWorkout() {
        let now = date(2024, 6, 10)
        let day = date(2024, 6, 5)
        let sets = [
            strengthSet(on: day, muscle: .biceps),
            strengthSet(on: day, muscle: .biceps),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        XCTAssertEqual(stats.totalWorkingSets, 2)
    }

    // MARK: - 8. Multiple workouts per week sum correctly

    func test_multipleWorkoutsPerWeek() {
        let now = date(2024, 6, 10)
        let mon = date(2024, 6, 3)
        let wed = date(2024, 6, 5)
        let fri = date(2024, 6, 7)
        let sets = [
            strengthSet(on: mon, muscle: .triceps),
            strengthSet(on: wed, muscle: .triceps),
            strengthSet(on: fri, muscle: .triceps),
        ]
        let points = Calc.weeklyPoints(sets: sets, period: .allTime, now: now)
        let totalInWeek = points.reduce(0) { $0 + ($1.setsByMuscle[.triceps] ?? 0) }
        XCTAssertEqual(totalInWeek, 3)
    }

    // MARK: - 9. Unknown/nil muscle → not counted but no crash

    func test_nilMuscleGroupDoesNotCrash() {
        let now = date(2024, 6, 10)
        let sets = [
            Set(date: date(2024, 6, 5), exerciseName: "Unknown Exercise", muscleGroup: nil, isCardio: false),
            strengthSet(on: date(2024, 6, 5), muscle: .back),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        // nil muscle not counted
        XCTAssertEqual(stats.totalWorkingSets, 1)
    }

    // MARK: - 10. mostTrainedMuscle reflects highest-volume group

    func test_mostTrainedMuscle() {
        let now = date(2024, 6, 10)
        let sets = [
            strengthSet(on: date(2024, 6, 1), muscle: .back),
            strengthSet(on: date(2024, 6, 2), muscle: .back),
            strengthSet(on: date(2024, 6, 3), muscle: .back),
            strengthSet(on: date(2024, 6, 1), muscle: .chest),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        XCTAssertEqual(stats.mostTrainedMuscle, .back)
        XCTAssertEqual(stats.mostTrainedMuscleSets, 3)
    }

    // MARK: - 11. weeklyPoints is gap-free (zero-weeks included)

    func test_weeklyPointsGapFree() {
        // Single set 3 weeks before now — should produce 4 points including 3 zero-weeks
        let now = date(2024, 6, 10)
        let threeWeeksAgo = date(2024, 5, 20)
        let sets = [strengthSet(on: threeWeeksAgo, muscle: .hamstrings)]
        let points = Calc.weeklyPoints(sets: sets, period: .fourWeeks, now: now)
        // 4W window → at least 3 weeks worth of data
        XCTAssertGreaterThanOrEqual(points.count, 3)
        // Most weeks should be zero
        let zeroWeeks = points.filter { $0.totalSets == 0 }
        XCTAssertGreaterThanOrEqual(zeroWeeks.count, 2)
    }

    // MARK: - 12. muscleRanking sorted descending

    func test_muscleRankingSortedDescending() {
        let now = date(2024, 6, 10)
        let sets = [
            strengthSet(on: date(2024, 6, 1), muscle: .calves),
            strengthSet(on: date(2024, 6, 2), muscle: .core),
            strengthSet(on: date(2024, 6, 3), muscle: .core),
        ]
        let ranking = Calc.muscleRanking(sets: sets, period: .allTime, now: now)
        // core (2) should come before calves (1)
        let coreIdx = ranking.firstIndex(where: { $0.muscle == .core })!
        let calvesIdx = ranking.firstIndex(where: { $0.muscle == .calves })!
        XCTAssertLessThan(coreIdx, calvesIdx)
    }

    // MARK: - 13. weeklyPointsForMuscle isolates one group

    func test_weeklyPointsForMuscleSingleGroup() {
        let now = date(2024, 6, 10)
        let sets = [
            strengthSet(on: date(2024, 6, 3), muscle: .chest),
            strengthSet(on: date(2024, 6, 3), muscle: .back),
            strengthSet(on: date(2024, 6, 3), muscle: .chest),
        ]
        let chestPoints = Calc.weeklyPointsForMuscle(.chest, sets: sets, period: .allTime, now: now)
        let chestTotal = chestPoints.reduce(0) { $0 + $1.sets }
        XCTAssertEqual(chestTotal, 2)

        let backPoints = Calc.weeklyPointsForMuscle(.back, sets: sets, period: .allTime, now: now)
        let backTotal = backPoints.reduce(0) { $0 + $1.sets }
        XCTAssertEqual(backTotal, 1)
    }

    // MARK: - 14. Year-boundary — Kalenderwoche crosses Dec/Jan

    func test_yearBoundaryWeek() {
        // Monday 2023-12-25 and Thursday 2024-01-04 are in adjacent or same ISO week.
        let now = date(2024, 1, 20)
        let dec = date(2023, 12, 27)   // last week of 2023
        let jan = date(2024, 1, 4)     // first week of 2024
        let sets = [
            strengthSet(on: dec, muscle: .shoulders),
            strengthSet(on: jan, muscle: .shoulders),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        XCTAssertEqual(stats.totalWorkingSets, 2)

        let points = Calc.weeklyPoints(sets: sets, period: .allTime, now: now)
        let total = points.reduce(0) { $0 + ($1.setsByMuscle[.shoulders] ?? 0) }
        XCTAssertEqual(total, 2)
    }

    // MARK: - 15. Empty input → no crash, all zeros

    func test_emptyInputNoSets() {
        let stats = Calc.overviewStats(sets: [], period: .allTime, now: date(2024, 6, 10))
        XCTAssertEqual(stats.totalWorkingSets, 0)
        XCTAssertNil(stats.mostTrainedMuscle)
        XCTAssertNil(stats.busiestWeekStart)
    }

    // MARK: - 16. Idempotency — calling twice gives same result

    func test_idempotent() {
        let now = date(2024, 6, 10)
        let sets = [
            strengthSet(on: date(2024, 6, 1), muscle: .quads),
            strengthSet(on: date(2024, 6, 3), muscle: .glutes),
        ]
        let r1 = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        let r2 = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        XCTAssertEqual(r1, r2)
    }

    // MARK: - 17. Mixed strength + cardio in one session

    func test_mixedSessionOnlyCountsStrength() {
        let now = date(2024, 6, 10)
        let day = date(2024, 6, 5)
        let sets = [
            strengthSet(on: day, muscle: .hamstrings),
            cardioSet(on: day),
            cardioSet(on: day),
        ]
        let stats = Calc.overviewStats(sets: sets, period: .allTime, now: now)
        XCTAssertEqual(stats.totalWorkingSets, 1)
    }

    // MARK: - 18. allTime weeklyPoints anchors at earliest log (> 3 years)

    func test_allTimeAnchorEarliestLog() {
        let now = date(2024, 6, 10)
        let veryOld = date(2020, 3, 2)
        let recent = date(2024, 6, 3)
        let sets = [
            strengthSet(on: veryOld, muscle: .back),
            strengthSet(on: recent, muscle: .back),
        ]
        let points = Calc.weeklyPoints(sets: sets, period: .allTime, now: now)
        // Window should span from 2020 to 2024 → many more than a few weeks
        XCTAssertGreaterThan(points.count, 50)
        let total = points.reduce(0) { $0 + ($1.setsByMuscle[.back] ?? 0) }
        XCTAssertEqual(total, 2)
    }
}
