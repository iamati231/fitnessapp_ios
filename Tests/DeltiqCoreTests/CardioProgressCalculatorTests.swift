import Testing
import Foundation
@testable import DeltiqCore

struct CardioProgressCalculatorTests {

    typealias CPC = CardioProgressCalculator

    let now: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 11; c.day = 16
        return Calendar.current.date(from: c)!
    }()

    func makeRun(daysAgo: Int, distKm: Double?, durSeconds: Int? = nil) -> TrainingActivity {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        return TrainingActivity(
            date: date,
            runningDistanceKm: distKm,
            runningDurationSeconds: durSeconds,
            isRunning: true,
            isCrossTrainingOnly: false,
            hasAmbiguousCardio: false,
            hasStrengthActivity: false,
            strengthSetCount: 0,
            strengthVolumeKg: 0
        )
    }

    func makeCycling(daysAgo: Int) -> TrainingActivity {
        TrainingActivity(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!,
            runningDistanceKm: nil, runningDurationSeconds: nil,
            isRunning: false, isCrossTrainingOnly: true, hasAmbiguousCardio: false,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
    }

    func makeAmbiguous(daysAgo: Int) -> TrainingActivity {
        TrainingActivity(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!,
            runningDistanceKm: nil, runningDurationSeconds: nil,
            isRunning: false, isCrossTrainingOnly: false, hasAmbiguousCardio: true,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
    }

    // MARK: - Basic running stats

    @Test func singleRun5kmIn30Min() {
        let activities = [makeRun(daysAgo: 1, distKm: 5.0, durSeconds: 1800)]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        #expect(stats.sessionCount == 1)
        #expect(abs(stats.totalDistanceKm - 5.0) < 0.001)
        #expect(stats.longestRunKm == 5.0)
        // 30 min / 5 km = 6:00 min/km
        let expectedPace = 30.0 / 5.0
        #expect(abs(stats.bestPaceMinPerKm! - expectedPace) < 0.001)
        #expect(stats.otherCardioSessionCount == 0)
    }

    @Test func multipleRunsDistanceSummedCorrectly() {
        let activities = [
            makeRun(daysAgo: 1, distKm: 5.0, durSeconds: 1800),
            makeRun(daysAgo: 3, distKm: 10.0, durSeconds: 3600),
        ]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        #expect(stats.sessionCount == 2)
        #expect(abs(stats.totalDistanceKm - 15.0) < 0.001)
        #expect(stats.longestRunKm == 10.0)
    }

    @Test func bestPaceIsLowestMinPerKm() {
        // Run 1: 5 km in 30 min → 6:00/km
        // Run 2: 10 km in 50 min → 5:00/km (faster)
        let activities = [
            makeRun(daysAgo: 1, distKm: 5.0, durSeconds: 1800),
            makeRun(daysAgo: 3, distKm: 10.0, durSeconds: 3000),
        ]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        let expectedBest = 50.0 / 10.0  // 5.0 min/km
        #expect(abs(stats.bestPaceMinPerKm! - expectedBest) < 0.001)
    }

    // MARK: - Cardio separation

    @Test func cyclingOnlyGivesZeroRunningStats() {
        let activities = [makeCycling(daysAgo: 1), makeCycling(daysAgo: 5)]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        #expect(stats.sessionCount == 0)         // no running
        #expect(stats.totalDistanceKm == 0)
        #expect(stats.longestRunKm == nil)
        #expect(stats.bestPaceMinPerKm == nil)
        #expect(stats.otherCardioSessionCount == 2)
    }

    @Test func ambiguousCardioCountedInOtherNotRunning() {
        let activities = [makeAmbiguous(daysAgo: 1)]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        #expect(stats.sessionCount == 0)
        #expect(stats.otherCardioSessionCount == 1)
    }

    @Test func mixedRunningAndCyclingSessionCountsCorrectly() {
        let activities = [
            makeRun(daysAgo: 1, distKm: 5.0, durSeconds: 1800),
            makeCycling(daysAgo: 2),
            makeAmbiguous(daysAgo: 3),
        ]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        #expect(stats.sessionCount == 1)
        #expect(stats.otherCardioSessionCount == 2)
        #expect(abs(stats.totalDistanceKm - 5.0) < 0.001)
    }

    // MARK: - Missing/invalid data

    @Test func missingDistanceExcludedFromSum() {
        let activities = [
            makeRun(daysAgo: 1, distKm: nil, durSeconds: 1800),
            makeRun(daysAgo: 2, distKm: 5.0, durSeconds: 1800),
        ]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        #expect(stats.sessionCount == 2)        // both are running sessions
        #expect(abs(stats.totalDistanceKm - 5.0) < 0.001)
    }

    @Test func missingDurationExcludedFromPace() {
        let activities = [makeRun(daysAgo: 1, distKm: 5.0, durSeconds: nil)]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        #expect(stats.bestPaceMinPerKm == nil)
    }

    @Test func zeroDistanceExcludedFromPaceAndLongest() {
        let activities = [makeRun(daysAgo: 1, distKm: 0.0, durSeconds: 1800)]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        #expect(stats.longestRunKm == nil)
        #expect(stats.bestPaceMinPerKm == nil)
        #expect(stats.sessionCount == 1)       // it's still a run
    }

    // MARK: - Period filtering

    @Test func fourWeeksFilterExcludesOlderSessions() {
        let activities = [
            makeRun(daysAgo: 10, distKm: 5.0, durSeconds: 1800),  // within 4 weeks
            makeRun(daysAgo: 50, distKm: 10.0, durSeconds: 3600), // outside 4 weeks
        ]
        let stats = CPC.overviewStats(activities: activities, period: .fourWeeks, now: now)
        #expect(stats.sessionCount == 1)
        #expect(abs(stats.totalDistanceKm - 5.0) < 0.001)
    }

    @Test func futureSessionExcluded() {
        let future = TrainingActivity(
            date: Calendar.current.date(byAdding: .day, value: 1, to: now)!,
            runningDistanceKm: 10.0, runningDurationSeconds: 3600,
            isRunning: true, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
        let stats = CPC.overviewStats(activities: [future], period: .allTime, now: now)
        #expect(stats.sessionCount == 0)
    }

    @Test func periodBoundaryDateIncluded() {
        // A session exactly at the cutoff boundary should be included.
        let fourWeeksAgo = CPC.Period.fourWeeks.cutoff(now: now)!
        let atBoundary = TrainingActivity(
            date: fourWeeksAgo,
            runningDistanceKm: 5.0, runningDurationSeconds: 1800,
            isRunning: true, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
        let stats = CPC.overviewStats(activities: [atBoundary], period: .fourWeeks, now: now)
        #expect(stats.sessionCount == 1)
    }

    // MARK: - allTime window (P0)

    @Test func allTimeIncludesSessionsOlderThan3Years() {
        // This is the P0 regression: a run from 2022 (>3 years ago) must appear.
        var c = DateComponents(); c.year = 2022; c.month = 6; c.day = 1
        let oldDate = Calendar.current.date(from: c)!
        let old = TrainingActivity(
            date: oldDate,
            runningDistanceKm: 10.0, runningDurationSeconds: 3600,
            isRunning: true, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
        let recent = makeRun(daysAgo: 10, distKm: 5.0, durSeconds: 1800)
        let stats = CPC.overviewStats(activities: [old, recent], period: .allTime, now: now)
        #expect(stats.sessionCount == 2)
        #expect(abs(stats.totalDistanceKm - 15.0) < 0.001)
    }

    @Test func allTimeWeeklyPointsAnchorToEarliestRun() {
        var c = DateComponents(); c.year = 2022; c.month = 6; c.day = 1
        let oldDate = Calendar.current.date(from: c)!
        let old = TrainingActivity(
            date: oldDate,
            runningDistanceKm: 10.0, runningDurationSeconds: 3600,
            isRunning: true, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
        let recent = makeRun(daysAgo: 10, distKm: 5.0, durSeconds: 1800)
        let points = CPC.weeklyPoints(activities: [old, recent], period: .allTime, now: now)
        // Window should start near oldDate, so total running distance across all buckets == 15 km.
        let totalInBuckets = points.map(\.runningDistanceKm).reduce(0, +)
        #expect(abs(totalInBuckets - 15.0) < 0.001)
    }

    @Test func allTimeNoRunsReturnsEmptyPoints() {
        let points = CPC.weeklyPoints(activities: [], period: .allTime, now: now)
        // No running activities → windowStart == now → one-week window with no data.
        #expect(points.allSatisfy { $0.runningDistanceKm == 0 })
    }

    // MARK: - Pace unit conversion (P0, view-layer)
    // The calculator always stores min/km. Views must convert with 1.609344.
    // We verify the raw value here and trust view tests for formatting.

    @Test func paceStoredInMinPerKm() {
        // 5 km in 30 min → 6.0 min/km exactly
        let activities = [makeRun(daysAgo: 1, distKm: 5.0, durSeconds: 1800)]
        let stats = CPC.overviewStats(activities: activities, period: .allTime, now: now)
        #expect(abs(stats.bestPaceMinPerKm! - 6.0) < 0.001)
        // Consumer-side: 6.0 * 1.609344 ≈ 9.656 min/mi → 9:39
        let minPerMile = stats.bestPaceMinPerKm! * 1.609344
        let mins = Int(minPerMile)
        let secs = Int((minPerMile - Double(mins)) * 60)
        #expect(mins == 9)
        #expect(secs == 39)
    }

    // MARK: - weeklyPoints buckets

    @Test func weeklyPointsDistanceMatchesStats() {
        let activities = [
            makeRun(daysAgo: 1, distKm: 5.0, durSeconds: 1800),
            makeRun(daysAgo: 3, distKm: 10.0, durSeconds: 3600),
        ]
        let points = CPC.weeklyPoints(activities: activities, period: .twelveWeeks, now: now)
        let totalInBuckets = points.map(\.runningDistanceKm).reduce(0, +)
        let stats = CPC.overviewStats(activities: activities, period: .twelveWeeks, now: now)
        #expect(abs(totalInBuckets - stats.totalDistanceKm) < 0.001)
    }

    @Test func cyclingOnlyProducesNoPaceInBuckets() {
        let activities = [makeCycling(daysAgo: 1)]
        let points = CPC.weeklyPoints(activities: activities, period: .fourWeeks, now: now)
        #expect(points.allSatisfy { $0.averagePaceMinutesPerKm == nil })
    }

    @Test func distanceWeightedPaceAcrossMultipleRunsSameWeek() {
        // Run A: 5 km in 30 min (6:00/km), Run B: 5 km in 25 min (5:00/km)
        // Distance-weighted pace = (30+25) / (5+5) = 5.5 min/km
        // Nov 14 (Sat) and Nov 13 (Fri): mid-week in any locale (never a week boundary).
        let activities = [
            makeRun(daysAgo: 2, distKm: 5.0, durSeconds: 1800),
            makeRun(daysAgo: 3, distKm: 5.0, durSeconds: 1500),
        ]
        let points = CPC.weeklyPoints(activities: activities, period: .fourWeeks, now: now)
        let pacePoints = points.compactMap(\.averagePaceMinutesPerKm)
        // Both runs must land in exactly one week bucket.
        #expect(pacePoints.count == 1)
        #expect(abs(pacePoints[0] - 5.5) < 0.01)
    }
}
