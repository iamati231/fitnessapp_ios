import XCTest
@testable import FitnessAppCore

final class DeloadAdvisorTests: XCTestCase {

    // MARK: Trigger case

    func testRisingLoadPlusHardSessionsRecommends() {
        XCTAssertTrue(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [100, 130, 160],
            hardSessionCount: 2
        ))
    }

    func testExactRampFactorBoundaryRecommends() {
        // w3 == w1 * 1.2 exakt → >= greift
        XCTAssertTrue(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [100, 110, 120],
            hardSessionCount: 3
        ))
    }

    // MARK: Single-signal guards — ein Signal allein reicht nie

    func testRisingLoadWithoutHardSessionsDoesNotRecommend() {
        XCTAssertFalse(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [100, 130, 160],
            hardSessionCount: 1
        ))
    }

    func testHardSessionsWithFlatLoadDoesNotRecommend() {
        XCTAssertFalse(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [150, 150, 150],
            hardSessionCount: 4
        ))
    }

    // MARK: Trend shape guards

    func testDipInMiddleBreaksTrend() {
        // w2 < w1 → kein monotoner Anstieg
        XCTAssertFalse(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [100, 90, 160],
            hardSessionCount: 3
        ))
    }

    func testRampBelowTwentyPercentDoesNotRecommend() {
        // +15% über 3 Wochen = normales Rauschen
        XCTAssertFalse(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [100, 105, 115],
            hardSessionCount: 2
        ))
    }

    // MARK: Data sufficiency

    func testFewerThanThreeWeeksNeverRecommends() {
        XCTAssertFalse(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [100, 160],
            hardSessionCount: 5
        ))
        XCTAssertFalse(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [],
            hardSessionCount: 5
        ))
    }

    func testUsesOnlyLastThreeWeeks() {
        // Ältere Wochen davor sind irrelevant — die letzten 3 steigen.
        XCTAssertTrue(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [500, 400, 100, 130, 160],
            hardSessionCount: 2
        ))
    }

    func testZeroBaseWeekDoesNotRecommend() {
        // Urlaubs-Woche mit 0 Last → Ratio undefiniert → kein Trigger
        XCTAssertFalse(DeloadAdvisor.shouldRecommendDeload(
            weeklyLoads: [0, 80, 160],
            hardSessionCount: 3
        ))
    }
}
