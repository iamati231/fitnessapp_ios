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

    // MARK: - Paket 3a: isRecurringMissedRunDays / missedRunHintFingerprint

    private func summary(
        missedCount: Int,
        scheduleKindUsed: PlanParticipationEvaluator.ScheduleKind = .fixedWeekdays([2, 4, 6])
    ) -> PlanParticipationEvaluator.Summary {
        PlanParticipationEvaluator.Summary(
            periodStart: Date(timeIntervalSince1970: 0),
            periodEnd: Date(timeIntervalSince1970: 0),
            scheduleKindUsed: scheduleKindUsed,
            plannedCount: missedCount + 1,
            completedCount: 1,
            partialCount: 0,
            startedOnlyCount: 0,
            missedCount: missedCount,
            extraOccurrenceCount: 0,
            countingRules: [],
            dataGaps: []
        )
    }

    func testNotReliablyEvaluableNeverTriggersRegardlessOfReason() {
        for reason: PlanParticipationEvaluator.UnreliableReason in [
            .activationStartUnknown, .planNotCurrentlyActive, .evaluationBeforeActivation,
            .planHasNoTrainingDays, .noOpportunityDueYet, .underlyingDataFetchFailed
        ] {
            XCTAssertFalse(CardioCoachingAdvisor.isRecurringMissedRunDays(.notReliablyEvaluable(reason)))
        }
    }

    func testBelowThresholdDoesNotTrigger() {
        XCTAssertFalse(CardioCoachingAdvisor.isRecurringMissedRunDays(.evaluated(summary(missedCount: 1))))
    }

    func testAtThresholdTriggers() {
        XCTAssertTrue(CardioCoachingAdvisor.isRecurringMissedRunDays(.evaluated(summary(missedCount: 2))))
    }

    func testAboveThresholdTriggers() {
        XCTAssertTrue(CardioCoachingAdvisor.isRecurringMissedRunDays(.evaluated(summary(missedCount: 5))))
    }

    /// Bindung an die Planfassung: ein anderer `planActivatedAt` (= nach
    /// einem Planwechsel/einer Re-Aktivierung) muss den Fingerprint ändern.
    func testFingerprintChangesWithDifferentPlanActivatedAt() {
        let a = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: Date(timeIntervalSince1970: 0), summary: summary(missedCount: 2))
        let b = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: Date(timeIntervalSince1970: 1_000_000), summary: summary(missedCount: 2))
        XCTAssertNotEqual(a, b)
    }

    /// Bindung an die Planfassung: eine geänderte Lauf-Tage-Struktur
    /// (anderes `scheduleKindUsed`) muss den Fingerprint ändern.
    func testFingerprintChangesWithDifferentScheduleKind() {
        let anchor = Date(timeIntervalSince1970: 0)
        let a = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: anchor, summary: summary(missedCount: 2, scheduleKindUsed: .fixedWeekdays([2, 4])))
        let b = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: anchor, summary: summary(missedCount: 2, scheduleKindUsed: .fixedWeekdays([2, 4, 6])))
        XCTAssertNotEqual(a, b)
    }

    /// Bindung an neue Beobachtungen: ein gestiegener `missedCount` muss den
    /// Fingerprint ändern, obwohl Planfassung/Schedule identisch bleiben.
    func testFingerprintChangesWithDifferentMissedCount() {
        let anchor = Date(timeIntervalSince1970: 0)
        let a = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: anchor, summary: summary(missedCount: 2))
        let b = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: anchor, summary: summary(missedCount: 3))
        XCTAssertNotEqual(a, b)
    }

    /// Bewusst STABIL trotz unterschiedlicher `periodStart`-Werte in der
    /// Summary (die bei einem rollierenden Fenster taeglich weiterwandern) —
    /// nur `planActivatedAt`/`scheduleKindUsed`/`missedCount` fliessen ein,
    /// siehe Typ-Doku ("sonst liefe eine Unterdrueckung taeglich ab").
    func testFingerprintIsStableAcrossRollingWindowDrift() {
        let anchor = Date(timeIntervalSince1970: 0)
        let day1 = PlanParticipationEvaluator.Summary(
            periodStart: Date(timeIntervalSince1970: 10), periodEnd: Date(timeIntervalSince1970: 10),
            scheduleKindUsed: .fixedWeekdays([2, 4, 6]), plannedCount: 3, completedCount: 1,
            partialCount: 0, startedOnlyCount: 0, missedCount: 2, extraOccurrenceCount: 0,
            countingRules: [], dataGaps: []
        )
        let day2 = PlanParticipationEvaluator.Summary(
            periodStart: Date(timeIntervalSince1970: 86_410), periodEnd: Date(timeIntervalSince1970: 86_410),
            scheduleKindUsed: .fixedWeekdays([2, 4, 6]), plannedCount: 3, completedCount: 1,
            partialCount: 0, startedOnlyCount: 0, missedCount: 2, extraOccurrenceCount: 0,
            countingRules: [], dataGaps: []
        )
        let a = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: anchor, summary: day1)
        let b = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: anchor, summary: day2)
        XCTAssertEqual(a, b)
    }

    func testFingerprintIsStableForIdenticalSummary() {
        let anchor = Date(timeIntervalSince1970: 0)
        let a = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: anchor, summary: summary(missedCount: 2))
        let b = CardioCoachingAdvisor.missedRunHintFingerprint(planActivatedAt: anchor, summary: summary(missedCount: 2))
        XCTAssertEqual(a, b)
    }
}
