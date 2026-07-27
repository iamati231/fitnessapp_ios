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

    // MARK: - DEL-236 Nur Krafttraining zaehlt

    /// Der Kern der Beschwerde: Laufen darf keinen Deload ausloesen.
    func testCardioLogsContributeNoStrengthLoad() {
        let load = DeloadAdvisor.strengthCNSLoad(logs: [
            (isCardio: true, cnsScore: 250),   // langer Lauf, hoechster Bucket
            (isCardio: true, cnsScore: 180),
        ])
        XCTAssertEqual(load, 0, "eine reine Cardio-Session darf 0 Kraft-Last ergeben")
    }

    func testMixedSessionCountsOnlyTheStrengthPart() {
        let load = DeloadAdvisor.strengthCNSLoad(logs: [
            (isCardio: false, cnsScore: 40),
            (isCardio: false, cnsScore: 35),
            (isCardio: true,  cnsScore: 200),  // Lauf am Ende
        ])
        XCTAssertEqual(load, 75, accuracy: 0.0001)
    }

    /// TimeBased (Plank, Wall Sit) ist Widerstandsarbeit und zaehlt mit —
    /// ausgeschlossen wird ausschliesslich Cardio.
    func testTimeBasedWorkStillCounts() {
        let load = DeloadAdvisor.strengthCNSLoad(logs: [(isCardio: false, cnsScore: 30)])
        XCTAssertEqual(load, 30, accuracy: 0.0001)
    }

    func testEmptySessionHasNoStrengthLoad() {
        XCTAssertEqual(DeloadAdvisor.strengthCNSLoad(logs: []), 0)
    }

    /// Ein zerstoerender Halbmarathon ist hart, sagt aber nichts ueber die
    /// Ermuedung beim Bankdruecken.
    func testHardCardioOnlySessionIsNotAHardStrengthSession() {
        XCTAssertFalse(DeloadAdvisor.isHardStrengthSession(feeling: 5, containsStrengthWork: false))
        XCTAssertFalse(DeloadAdvisor.isHardStrengthSession(feeling: 4, containsStrengthWork: false))
    }

    func testHardSessionWithStrengthWorkCounts() {
        XCTAssertTrue(DeloadAdvisor.isHardStrengthSession(feeling: 4, containsStrengthWork: true))
        XCTAssertTrue(DeloadAdvisor.isHardStrengthSession(feeling: 5, containsStrengthWork: true))
    }

    func testEasyStrengthSessionIsNotHard() {
        XCTAssertFalse(DeloadAdvisor.isHardStrengthSession(feeling: 3, containsStrengthWork: true))
        XCTAssertFalse(DeloadAdvisor.isHardStrengthSession(feeling: nil, containsStrengthWork: true))
    }

    /// End-to-End des gemeldeten Falls: drei Wochen steigendes Laufpensum,
    /// zwei harte Laeufe, Krafttraining unveraendert -> KEIN Deload.
    func testRisingRunningVolumeAloneNeverRecommendsDeload() {
        // Kraft-Last der drei Wochen bleibt flach, weil Cardio herausfaellt.
        let weeks = [
            [(isCardio: false, cnsScore: 100.0), (isCardio: true, cnsScore: 150.0)],
            [(isCardio: false, cnsScore: 100.0), (isCardio: true, cnsScore: 250.0)],
            [(isCardio: false, cnsScore: 100.0), (isCardio: true, cnsScore: 400.0)],
        ].map { DeloadAdvisor.strengthCNSLoad(logs: $0) }
        XCTAssertEqual(weeks, [100, 100, 100])
        // Die harten Sessions waren Laeufe, zaehlen also nicht.
        let hard = [false, false].filter {
            DeloadAdvisor.isHardStrengthSession(feeling: 5, containsStrengthWork: $0)
        }.count
        XCTAssertFalse(DeloadAdvisor.shouldRecommendDeload(weeklyLoads: weeks, hardSessionCount: hard))
    }

    /// Gegenprobe: echtes Kraft-Overreaching wird weiterhin erkannt.
    func testRisingStrengthLoadStillRecommends() {
        let weeks = [
            [(isCardio: false, cnsScore: 100.0)],
            [(isCardio: false, cnsScore: 125.0)],
            [(isCardio: false, cnsScore: 150.0)],
        ].map { DeloadAdvisor.strengthCNSLoad(logs: $0) }
        let hard = [true, true].filter {
            DeloadAdvisor.isHardStrengthSession(feeling: 4, containsStrengthWork: $0)
        }.count
        XCTAssertTrue(DeloadAdvisor.shouldRecommendDeload(weeklyLoads: weeks, hardSessionCount: hard))
    }
}
