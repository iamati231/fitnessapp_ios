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
        // Ziel 60min, Toleranz 80% -> 48min noetig. Keiner der beiden Laeufe
        // reicht.
        XCTAssertTrue(CardioCoachingAdvisor.isLongRunOverdue(
            planLongRunTargetMinutes: 60,
            recentRunDurationsMinutes: [20, 30]
        ))
    }

    func testQualifyingRunSatisfiesRequirement() {
        XCTAssertFalse(CardioCoachingAdvisor.isLongRunOverdue(
            planLongRunTargetMinutes: 60,
            recentRunDurationsMinutes: [20, 65]
        ))
    }

    func testExactMinimumMinutesSatisfiesRequirement() {
        // Ein Lauf ueber die volle Ziel-Dauer erfuellt die Anforderung
        // erst recht - die eigentliche Grenze liegt bei der 80%-Toleranz,
        // siehe testToleranceThresholdSatisfiesRequirement.
        XCTAssertFalse(CardioCoachingAdvisor.isLongRunOverdue(
            planLongRunTargetMinutes: 60,
            recentRunDurationsMinutes: [60]
        ))
    }

    func testToleranceThresholdSatisfiesRequirement() {
        // Audit-Fund: hybrid_beginner setzt den langen Lauf bei 50min an -
        // ein geloggter 40min-Lauf (= 50 * 0.8, exakt an der Toleranz-
        // Grenze) muss bereits reichen, sonst waere die 80%-Toleranz aus
        // dem Coach-Text ("egal wie langsam") nur ein Lippenbekenntnis.
        XCTAssertFalse(CardioCoachingAdvisor.isLongRunOverdue(
            planLongRunTargetMinutes: 50,
            recentRunDurationsMinutes: [40]
        ))
    }

    func testJustBelowToleranceThresholdIsOverdue() {
        XCTAssertTrue(CardioCoachingAdvisor.isLongRunOverdue(
            planLongRunTargetMinutes: 50,
            recentRunDurationsMinutes: [39]
        ))
    }

    func testPlanWithoutLongRunNeverOverdue() {
        // Reiner Krafttrainings-Plan (oder Laufplan ohne distinct lange
        // Einheit, z.B. nur gleich lange Easy Runs) - die Frage ist
        // gegenstandslos, unabhaengig davon, was geloggt wurde.
        XCTAssertFalse(CardioCoachingAdvisor.isLongRunOverdue(
            planLongRunTargetMinutes: nil,
            recentRunDurationsMinutes: []
        ))
    }

    func testEmptyRecentRunsWithLongRunPlanIsOverdue() {
        XCTAssertTrue(CardioCoachingAdvisor.isLongRunOverdue(
            planLongRunTargetMinutes: 60,
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
