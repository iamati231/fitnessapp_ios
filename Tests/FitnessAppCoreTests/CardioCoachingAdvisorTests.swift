import XCTest
@testable import FitnessAppCore

final class CardioCoachingAdvisorTests: XCTestCase {

    // MARK: - isVolumeSpike

    func testClearSpikeTriggers() {
        XCTAssertTrue(CardioCoachingAdvisor.isVolumeSpike(currentWeekKm: 130, previousWeekKm: 100))
    }

    func testExactRampBoundaryDoesNotTrigger() {
        // Blueprint-Wortlaut ist "> 120%", nicht ">=" - exakt 120% zaehlt
        // noch nicht als Spike.
        XCTAssertFalse(CardioCoachingAdvisor.isVolumeSpike(currentWeekKm: 120, previousWeekKm: 100))
    }

    func testJustOverBoundaryTriggers() {
        XCTAssertTrue(CardioCoachingAdvisor.isVolumeSpike(currentWeekKm: 120.01, previousWeekKm: 100))
    }

    func testBelowRampDoesNotTrigger() {
        XCTAssertFalse(CardioCoachingAdvisor.isVolumeSpike(currentWeekKm: 110, previousWeekKm: 100))
    }

    func testZeroPreviousWeekNeverTriggers() {
        // Keine Vorwoche geloggt -> keine Basis fuer eine Ratio-Aussage.
        XCTAssertFalse(CardioCoachingAdvisor.isVolumeSpike(currentWeekKm: 50, previousWeekKm: 0))
    }

    // MARK: - isLongRunOverdue

    func testNoQualifyingRunWithPlanRequiringOneIsOverdue() {
        XCTAssertTrue(CardioCoachingAdvisor.isLongRunOverdue(
            planIncludesLongRun: true,
            recentRunDurationsMinutes: [20, 30]
        ))
    }

    func testQualifyingRunSatisfiesRequirement() {
        XCTAssertFalse(CardioCoachingAdvisor.isLongRunOverdue(
            planIncludesLongRun: true,
            recentRunDurationsMinutes: [20, 65]
        ))
    }

    func testExactMinimumMinutesSatisfiesRequirement() {
        // >= 60 zaehlt bereits, nicht erst > 60.
        XCTAssertFalse(CardioCoachingAdvisor.isLongRunOverdue(
            planIncludesLongRun: true,
            recentRunDurationsMinutes: [60]
        ))
    }

    func testPlanWithoutLongRunNeverOverdue() {
        // Reiner Krafttrainings-Plan (oder Laufplan ohne lange Einheit) -
        // die Frage ist gegenstandslos, unabhaengig davon, was geloggt wurde.
        XCTAssertFalse(CardioCoachingAdvisor.isLongRunOverdue(
            planIncludesLongRun: false,
            recentRunDurationsMinutes: []
        ))
    }

    func testEmptyRecentRunsWithLongRunPlanIsOverdue() {
        XCTAssertTrue(CardioCoachingAdvisor.isLongRunOverdue(
            planIncludesLongRun: true,
            recentRunDurationsMinutes: []
        ))
    }

    // MARK: - isJunkMiles

    func testMuchFasterThanTargetIsJunkMiles() {
        XCTAssertTrue(CardioCoachingAdvisor.isJunkMiles(actualPaceMinPerKm: 5.0, targetPaceMinPerKm: 6.0))
    }

    func testExactThresholdBoundaryDoesNotTrigger() {
        let target = 6.0
        let boundary = target - CardioCoachingAdvisor.junkMilesThresholdMinutesPerKm
        XCTAssertFalse(CardioCoachingAdvisor.isJunkMiles(actualPaceMinPerKm: boundary, targetPaceMinPerKm: target))
    }

    func testSlightlyFasterWithinToleranceDoesNotTrigger() {
        XCTAssertFalse(CardioCoachingAdvisor.isJunkMiles(actualPaceMinPerKm: 5.9, targetPaceMinPerKm: 6.0))
    }

    func testSlowerThanTargetNeverTriggers() {
        XCTAssertFalse(CardioCoachingAdvisor.isJunkMiles(actualPaceMinPerKm: 6.5, targetPaceMinPerKm: 6.0))
    }
}
