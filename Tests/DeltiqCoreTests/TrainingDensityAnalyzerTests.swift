import XCTest
@testable import DeltiqCore

/// AI-Running-Coach Phase 2C: 28 deterministische Tests fuer
/// `TrainingDensityAnalyzer`. Kein SwiftData, kein Date(), kein Calendar.current —
/// alle zeitlichen Bezugspunkte werden injiziert.
final class TrainingDensityAnalyzerTests: XCTestCase {

    // MARK: - Testhelfer

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Mo
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Montag 2026-11-02 00:00 UTC als festes "jetzt".
    private var now: Date {
        DateComponents(calendar: cal, year: 2026, month: 11, day: 2).date!
    }

    private func date(_ dayOffset: Int) -> Date {
        cal.date(byAdding: .day, value: dayOffset, to: now)!
    }

    private func runActivity(_ dayOffset: Int, withDuration: Bool = false) -> TrainingActivity {
        TrainingActivity(
            date: date(dayOffset),
            runningDistanceKm: 5,
            runningDurationSeconds: withDuration ? 1800 : nil,
            isRunning: true,
            isCrossTrainingOnly: false,
            hasAmbiguousCardio: false,
            hasStrengthActivity: false,
            strengthSetCount: 0,
            strengthVolumeKg: 0
        )
    }

    private func strengthActivity(_ dayOffset: Int) -> TrainingActivity {
        TrainingActivity(
            date: date(dayOffset),
            runningDistanceKm: nil,
            runningDurationSeconds: nil,
            isRunning: false,
            isCrossTrainingOnly: false,
            hasAmbiguousCardio: false,
            hasStrengthActivity: true,
            strengthSetCount: 20,
            strengthVolumeKg: 1000
        )
    }

    private func restDay(_ dayOffset: Int) -> TrainingActivity? { nil }

    private func emptyTrend() -> TrainingLoadTrend {
        TrainingLoadTrendAnalyzer.analyze(weeks: [], now: now, calendar: cal)
    }

    private func input(
        activities: [TrainingActivity],
        deloadIsActive: Bool = false,
        trend: TrainingLoadTrend? = nil
    ) -> TrainingDensityAnalyzer.Input {
        TrainingDensityAnalyzer.Input(
            activities: activities,
            trend: trend ?? emptyTrend(),
            deloadIsActive: deloadIsActive,
            now: now,
            calendar: cal
        )
    }

    // MARK: - 1. Insufficient data

    func testEmptyActivitiesReturnsInsufficientData() {
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: []))
        XCTAssertEqual(result.outcome, .insufficientData)
        XCTAssertEqual(result.analyzedActivityCount, 0)
    }

    func testTwoActivitiesReturnsInsufficientData() {
        let acts = [runActivity(-10), runActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertEqual(result.outcome, .insufficientData)
    }

    func testActivitiesWithinSixDaysReturnsInsufficientData() {
        // 3 activities but all within 6 days → span < 7
        let acts = [runActivity(-6), runActivity(-4), runActivity(-2)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertEqual(result.outcome, .insufficientData)
    }

    func testMinimumThreeActivitiesWithSufficientSpanDoesNotReturnInsufficientData() {
        let acts = [runActivity(-20), runActivity(-10), runActivity(-2)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertNotEqual(result.outcome, .insufficientData)
    }

    // MARK: - 2. Consecutive days

    func testMaxConsecutiveDaysZeroForEmptyArray() {
        XCTAssertEqual(TrainingDensityAnalyzer.maxConsecutiveDays([], calendar: cal), 0)
    }

    func testMaxConsecutiveDaysOneForSingleDay() {
        let d = [now]
        XCTAssertEqual(TrainingDensityAnalyzer.maxConsecutiveDays(d, calendar: cal), 1)
    }

    func testMaxConsecutiveDaysThreeForThreeInARow() {
        let days = [date(-2), date(-1), now]
        XCTAssertEqual(TrainingDensityAnalyzer.maxConsecutiveDays(days, calendar: cal), 3)
    }

    func testMaxConsecutiveDaysIgnoresGap() {
        // 2 in a row, gap, 3 in a row → max = 3
        let days = [date(-6), date(-5), date(-3), date(-2), date(-1)]
        XCTAssertEqual(TrainingDensityAnalyzer.maxConsecutiveDays(days, calendar: cal), 3)
    }

    func testHighConsecutiveConcernFiredAtThreshold() {
        // 5 consecutive days → concern
        let acts = (0..<5).map { runActivity(-(4 - $0)) }  // -4, -3, -2, -1, 0
        // Add two more to meet min activity count
        let extended = acts + [runActivity(-20), runActivity(-15)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: extended))
        let hasConcern = result.concerns.contains {
            if case .highConsecutiveTrainingDays = $0 { return true }
            return false
        }
        XCTAssertTrue(hasConcern, "Expected highConsecutiveTrainingDays concern for 5 consecutive days")
    }

    func testFourConsecutiveDaysDoesNotTriggerConcern() {
        let acts = [runActivity(-3), runActivity(-2), runActivity(-1), runActivity(0)]
        let extended = acts + [runActivity(-20), runActivity(-15)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: extended))
        let hasConcern = result.concerns.contains {
            if case .highConsecutiveTrainingDays = $0 { return true }
            return false
        }
        XCTAssertFalse(hasConcern)
    }

    // MARK: - 3. Dense week

    func testSixTrainingDaysInSevenDaysFiresConcern() {
        // days -6, -5, -4, -3, -2, -1 (6 of last 7 days) + older for span
        let recent = (-6 ... -1).map { runActivity($0) }
        let extended = recent + [runActivity(-20), runActivity(-18)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: extended))
        let hasConcern = result.concerns.contains {
            if case .sixPlusTrainingDaysInWeek = $0 { return true }
            return false
        }
        XCTAssertTrue(hasConcern)
    }

    func testFiveTrainingDaysInSevenDaysDoesNotFireDenseWeekConcern() {
        let recent = (-5 ... -1).map { runActivity($0) }
        let extended = recent + [runActivity(-20), runActivity(-18)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: extended))
        let hasConcern = result.concerns.contains {
            if case .sixPlusTrainingDaysInWeek = $0 { return true }
            return false
        }
        XCTAssertFalse(hasConcern)
    }

    // MARK: - 4. Run gap

    func testMinimumGapHoursNilForFewerThanTwoActivities() {
        XCTAssertNil(TrainingDensityAnalyzer.minimumGapHours(between: []))
        XCTAssertNil(TrainingDensityAnalyzer.minimumGapHours(between: [now]))
    }

    func testMinimumGapHoursComputesCorrectly() {
        let d1 = now
        let d2 = now.addingTimeInterval(10 * 3600)  // 10h later
        let d3 = now.addingTimeInterval(50 * 3600)  // 50h later
        let gap = TrainingDensityAnalyzer.minimumGapHours(between: [d1, d2, d3])
        XCTAssertEqual(gap, 10, accuracy: 0.01)
    }

    func testCloseRunGapConcernFiredUnder18Hours() {
        // Two running sessions 12h apart
        let a1 = TrainingActivity(date: now.addingTimeInterval(-12 * 3600),
                                  runningDistanceKm: 5, runningDurationSeconds: nil,
                                  isRunning: true, isCrossTrainingOnly: false,
                                  hasAmbiguousCardio: false, hasStrengthActivity: false,
                                  strengthSetCount: 0, strengthVolumeKg: 0)
        let a2 = TrainingActivity(date: now,
                                  runningDistanceKm: 5, runningDurationSeconds: nil,
                                  isRunning: true, isCrossTrainingOnly: false,
                                  hasAmbiguousCardio: false, hasStrengthActivity: false,
                                  strengthSetCount: 0, strengthVolumeKg: 0)
        let extended = [a1, a2, runActivity(-20), runActivity(-15)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: extended))
        let hasConcern = result.concerns.contains {
            if case .closelySpacedRunningSessions = $0 { return true }
            return false
        }
        XCTAssertTrue(hasConcern)
    }

    func testRunGap20HoursDoesNotTriggerConcern() {
        let a1 = TrainingActivity(date: now.addingTimeInterval(-20 * 3600),
                                  runningDistanceKm: 5, runningDurationSeconds: nil,
                                  isRunning: true, isCrossTrainingOnly: false,
                                  hasAmbiguousCardio: false, hasStrengthActivity: false,
                                  strengthSetCount: 0, strengthVolumeKg: 0)
        let a2 = TrainingActivity(date: now,
                                  runningDistanceKm: 5, runningDurationSeconds: nil,
                                  isRunning: true, isCrossTrainingOnly: false,
                                  hasAmbiguousCardio: false, hasStrengthActivity: false,
                                  strengthSetCount: 0, strengthVolumeKg: 0)
        let extended = [a1, a2, runActivity(-20), runActivity(-15)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: extended))
        let hasConcern = result.concerns.contains {
            if case .closelySpacedRunningSessions = $0 { return true }
            return false
        }
        XCTAssertFalse(hasConcern)
    }

    // MARK: - 5. Deload concern

    func testDeloadActiveConcernPresentWhenDeloadIsActive() {
        let acts = [runActivity(-20), runActivity(-10), runActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts, deloadIsActive: true))
        XCTAssertTrue(result.concerns.contains(.deloadIndicatedByExistingSystem))
    }

    func testDeloadNotActiveConcernAbsent() {
        let acts = [runActivity(-20), runActivity(-10), runActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts, deloadIsActive: false))
        XCTAssertFalse(result.concerns.contains(.deloadIndicatedByExistingSystem))
    }

    // MARK: - 6. Outcome rules

    func testDeloadActiveLeadsToIncreasingLoadOutcome() {
        let acts = [runActivity(-20), runActivity(-10), runActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts, deloadIsActive: true))
        XCTAssertEqual(result.outcome, .increasingLoad)
    }

    func testHighConsecutiveLeadsToHighTrainingDensityOutcome() {
        let acts = (-4...0).map { runActivity($0) } + [runActivity(-20), runActivity(-15)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts, deloadIsActive: false))
        XCTAssertEqual(result.outcome, .highTrainingDensity)
    }

    func testDeloadTakesPriorityOverHighDensity() {
        // Both deload and high density: outcome must be .increasingLoad (deload has priority)
        let acts = (-4...0).map { runActivity($0) } + [runActivity(-20), runActivity(-15)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts, deloadIsActive: true))
        XCTAssertEqual(result.outcome, .increasingLoad)
    }

    func testLowDensityWithSufficientHistoryReturnsBalancedOrInsufficient() {
        // Few scattered activities over 20 days — no density concerns
        let acts = [runActivity(-20), runActivity(-12), runActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts, deloadIsActive: false))
        // With stable/insufficient trend (empty weeks), we get insufficientRecoveryEvidence
        XCTAssertTrue(
            result.outcome == .balanced || result.outcome == .insufficientRecoveryEvidence,
            "Expected balanced or insufficientRecoveryEvidence, got \(result.outcome)"
        )
    }

    func testShortHistoryUnder14DaysReturnsInsufficientRecoveryEvidence() {
        // 10 days span (>= minimumSpanDays of 7 but < sufficientHistoryDays of 14)
        let acts = [runActivity(-10), runActivity(-7), runActivity(-3)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts, deloadIsActive: false))
        XCTAssertEqual(result.outcome, .insufficientRecoveryEvidence)
    }

    // MARK: - 7. DataGaps

    func testSessionFeelingUnavailableAlwaysPresent() {
        let acts = [runActivity(-20), runActivity(-10), runActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertTrue(result.dataGaps.contains(.sessionFeelingUnavailable))
    }

    func testInsufficientHistoryDataGapPresentUnder14Days() {
        let acts = [runActivity(-10), runActivity(-7), runActivity(-3)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        let hasGap = result.dataGaps.contains {
            if case .insufficientHistory = $0 { return true }
            return false
        }
        XCTAssertTrue(hasGap)
    }

    func testNoIntensityDataGapPresentWhenNoRunningDuration() {
        let acts = [runActivity(-20), runActivity(-10), runActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertTrue(result.dataGaps.contains(.noMeasuredIntensityData))
    }

    func testNoIntensityDataGapAbsentWhenRunDurationPresent() {
        let acts = [runActivity(-20, withDuration: true), runActivity(-10), runActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertFalse(result.dataGaps.contains(.noMeasuredIntensityData))
    }

    // MARK: - 8. Rolling window counts

    func testTrainingDaysLast7CountsCorrectly() {
        // 3 runs in last 7 days, 2 older
        let acts = [runActivity(-15), runActivity(-10), runActivity(-3), runActivity(-2), runActivity(-1)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertEqual(result.trainingDaysLast7, 3)
    }

    func testTrainingDaysLast14CountsCorrectly() {
        let acts = [runActivity(-15), runActivity(-10), runActivity(-3), runActivity(-2), runActivity(-1)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertEqual(result.trainingDaysLast14, 4)  // -10, -3, -2, -1
    }

    // MARK: - 9. Strength gap

    func testStrengthGapComputedForTwoOrMoreStrengthActivities() {
        let s1 = strengthActivity(-3)
        let s2 = strengthActivity(-1)
        let acts = [runActivity(-20), s1, s2]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertNotNil(result.minimumStrengthGapHours)
        // 2 days = 48 hours
        XCTAssertEqual(result.minimumStrengthGapHours!, 48, accuracy: 1.0)
    }

    func testStrengthGapNilForZeroOrOneStrengthActivities() {
        let acts = [runActivity(-20), runActivity(-10), strengthActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertNil(result.minimumStrengthGapHours)
    }

    // MARK: - 10. Analyzed period accuracy

    func testAnalyzedPeriodDaysMatchesActivitySpan() {
        let acts = [runActivity(-30), runActivity(-15), runActivity(-5)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        // Oldest is -30 days from now; span = 30 days
        XCTAssertEqual(result.analyzedPeriodDays, 30)
    }

    func testAnalyzedActivityCountMatchesInput() {
        let acts = [runActivity(-20), runActivity(-10), runActivity(-5), strengthActivity(-3)]
        let result = TrainingDensityAnalyzer.analyze(input: input(activities: acts))
        XCTAssertEqual(result.analyzedActivityCount, 4)
    }
}
