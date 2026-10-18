import XCTest
@testable import FitnessAppCore

/// P7.1 — Review-Orchestrator. Deckt die vom Gesamtmandat verbindlich
/// benannten Eigenschaften ab: "Plan passt – beibehalten" ist ein gültiges
/// Ergebnis, unzureichende Daten werden offen benannt statt verschwiegen,
/// und widersprüchliche Advisor-Signale (Deload + Comeback gleichzeitig)
/// werden definiert aufgelöst (F08) statt beide auszugeben.
final class FourWeekReviewOrchestratorTests: XCTestCase {

    private func evaluatedSummary(
        plannedCount: Int,
        completedCount: Int,
        missedCount: Int,
        dataGaps: [PlanParticipationEvaluator.DataGap] = []
    ) -> PlanParticipationEvaluator.Result {
        .evaluated(PlanParticipationEvaluator.Summary(
            periodStart: Date(timeIntervalSince1970: 0),
            periodEnd: Date(timeIntervalSince1970: 1),
            scheduleKindUsed: .flexibleWeeklyCadence(sessionsPerWeek: 3),
            plannedCount: plannedCount,
            completedCount: completedCount,
            partialCount: 0,
            startedOnlyCount: 0,
            missedCount: missedCount,
            extraOccurrenceCount: 0,
            countingRules: [],
            dataGaps: dataGaps
        ))
    }

    private func fullCheckIn(
        hadComplaints: Bool? = nil,
        goalStillCurrent: Bool? = nil
    ) -> FourWeekReviewOrchestrator.CheckInFeedback {
        .init(
            frequencyFeedback: .asPlanned,
            durationFeedback: .justRight,
            hadComplaints: hadComplaints,
            goalStillCurrent: goalStillCurrent
        )
    }

    // MARK: - "Plan passt – beibehalten" ist ein gültiges Ergebnis

    func testAllGoodYieldsKeepAsIsWithNoDataGaps() {
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 12, completedCount: 12, missedCount: 0),
            latestCheckIn: fullCheckIn(hadComplaints: false, goalStillCurrent: true),
            deloadRecommended: false,
            comebackSignal: nil
        ))
        XCTAssertEqual(review.outcome, .keepAsIs)
        XCTAssertTrue(review.dataGaps.isEmpty)
    }

    // MARK: - Unzureichende Daten werden offen benannt, nie verschwiegen

    func testUnevaluableParticipationIsSurfacedAsDataGapNotHiddenBehindKeepAsIs() {
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: .notReliablyEvaluable(.activationStartUnknown),
            latestCheckIn: fullCheckIn(hadComplaints: false, goalStillCurrent: true),
            deloadRecommended: false,
            comebackSignal: nil
        ))
        // Kein eigener "Befund", aber die Datenlücke muss sichtbar bleiben —
        // ein .keepAsIs-Ergebnis darf nicht als "geprüft und gut" missverstanden werden.
        XCTAssertEqual(review.outcome, .keepAsIs)
        XCTAssertEqual(review.dataGaps, [.participationNotReliablyEvaluable(.activationStartUnknown)])
    }

    func testMissingCheckInIsSurfacedAsDataGapAndNeverTreatedAsNoComplaints() {
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 12, completedCount: 12, missedCount: 0),
            latestCheckIn: nil,
            deloadRecommended: false,
            comebackSignal: nil
        ))
        XCTAssertEqual(review.outcome, .keepAsIs)
        XCTAssertEqual(review.dataGaps, [.noCheckInYet])
    }

    /// Spiegelt `PlanParticipationEvaluator.Summary.dataGaps` auf eine
    /// Orchestrator-`DataGap` — anders als die übrigen `Summary`-Datenlücken
    /// (z.B. `singleActivationAnchorOnly`), die bewusst intern bleiben, muss
    /// dieser Fund sichtbar werden: er betrifft nicht die Methode, sondern
    /// konkret fehlende/ausgeschlossene Sessions DIESER Auswertung.
    func testUnattributableHistoryGapIsLiftedToOrchestratorLevel() {
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(
                plannedCount: 12, completedCount: 12, missedCount: 0,
                dataGaps: [.unattributableHistoryExcludedDueToMultipleActivePlans]
            ),
            latestCheckIn: fullCheckIn(hadComplaints: false, goalStillCurrent: true),
            deloadRecommended: false,
            comebackSignal: nil
        ))
        XCTAssertEqual(review.outcome, .keepAsIs, "ausgeschlossene Historie allein ist kein Befund")
        XCTAssertEqual(review.dataGaps, [.participationHistoryPartiallyUnattributed])
    }

    // MARK: - Teilnahme-Lücke nur ab spürbarem Anteil, nicht bei jedem Ausrutscher

    func testSingleMissedSessionBelowThresholdIsNotAConcern() {
        // 1 von 8 verpasst = 12.5%, klar unter der 30%-Schwelle.
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 8, completedCount: 7, missedCount: 1),
            latestCheckIn: fullCheckIn(hadComplaints: false, goalStillCurrent: true),
            deloadRecommended: false,
            comebackSignal: nil
        ))
        XCTAssertEqual(review.outcome, .keepAsIs)
    }

    func testSignificantlyMissedParticipationIsAConcern() {
        // 4 von 8 verpasst = 50%, deutlich ueber der Schwelle.
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 8, completedCount: 4, missedCount: 4),
            latestCheckIn: fullCheckIn(hadComplaints: false, goalStillCurrent: true),
            deloadRecommended: false,
            comebackSignal: nil
        ))
        guard case .concernsFound(let concerns) = review.outcome else {
            return XCTFail("expected concernsFound, got \(review.outcome)")
        }
        XCTAssertEqual(concerns, [.participationBelowPlan(missedCount: 4, plannedCount: 8)])
    }

    // MARK: - Feedback-Befunde

    func testComplaintsReportedIsAConcern() {
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 12, completedCount: 12, missedCount: 0),
            latestCheckIn: fullCheckIn(hadComplaints: true, goalStillCurrent: true),
            deloadRecommended: false,
            comebackSignal: nil
        ))
        guard case .concernsFound(let concerns) = review.outcome else {
            return XCTFail("expected concernsFound, got \(review.outcome)")
        }
        XCTAssertEqual(concerns, [.complaintsReported])
    }

    func testGoalNoLongerCurrentIsAConcern() {
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 12, completedCount: 12, missedCount: 0),
            latestCheckIn: fullCheckIn(hadComplaints: false, goalStillCurrent: false),
            deloadRecommended: false,
            comebackSignal: nil
        ))
        guard case .concernsFound(let concerns) = review.outcome else {
            return XCTFail("expected concernsFound, got \(review.outcome)")
        }
        XCTAssertEqual(concerns, [.goalNoLongerCurrent])
    }

    func testSkippedComplaintsAndGoalQuestionsRaiseNoConcern() {
        // nil = "übersprungen" - darf NIE wie ein Negativbefund behandelt werden.
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 12, completedCount: 12, missedCount: 0),
            latestCheckIn: fullCheckIn(hadComplaints: nil, goalStillCurrent: nil),
            deloadRecommended: false,
            comebackSignal: nil
        ))
        XCTAssertEqual(review.outcome, .keepAsIs)
    }

    // MARK: - Deload/Comeback-Signale

    func testDeloadRecommendedAloneIsAConcern() {
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 12, completedCount: 12, missedCount: 0),
            latestCheckIn: fullCheckIn(hadComplaints: false, goalStillCurrent: true),
            deloadRecommended: true,
            comebackSignal: nil
        ))
        guard case .concernsFound(let concerns) = review.outcome else {
            return XCTFail("expected concernsFound, got \(review.outcome)")
        }
        XCTAssertEqual(concerns, [.deloadRecommended])
    }

    func testComebackSuggestedAloneIsAConcern() {
        let prescription = ComebackAdvisor.prescription(forGapDays: 21)
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 12, completedCount: 12, missedCount: 0),
            latestCheckIn: fullCheckIn(hadComplaints: false, goalStillCurrent: true),
            deloadRecommended: false,
            comebackSignal: .init(gapDays: 21, prescription: prescription)
        ))
        guard case .concernsFound(let concerns) = review.outcome else {
            return XCTFail("expected concernsFound, got \(review.outcome)")
        }
        XCTAssertEqual(concerns, [.comebackSuggested(prescription)])
    }

    /// F08: beide Signale gleichzeitig (bei korrekten Eingaben eigentlich
    /// ausgeschlossen) duerfen NIE beide ausgegeben werden — das waere ein
    /// widerspruechlicher Doppel-Vorschlag. Comeback gewinnt (siehe
    /// Begruendung im Orchestrator).
    func testConflictingDeloadAndComebackSignalsResolveToComebackOnly() {
        let prescription = ComebackAdvisor.prescription(forGapDays: 30)
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: evaluatedSummary(plannedCount: 12, completedCount: 12, missedCount: 0),
            latestCheckIn: fullCheckIn(hadComplaints: false, goalStillCurrent: true),
            deloadRecommended: true,
            comebackSignal: .init(gapDays: 30, prescription: prescription)
        ))
        guard case .concernsFound(let concerns) = review.outcome else {
            return XCTFail("expected concernsFound, got \(review.outcome)")
        }
        XCTAssertEqual(concerns, [.comebackSuggested(prescription)])
    }

    // MARK: - participation wird unveraendert durchgereicht

    func testParticipationResultIsPassedThroughUnchanged() {
        let summary = evaluatedSummary(plannedCount: 12, completedCount: 12, missedCount: 0)
        let review = FourWeekReviewOrchestrator.review(.init(
            participation: summary,
            latestCheckIn: nil,
            deloadRecommended: false,
            comebackSignal: nil
        ))
        XCTAssertEqual(review.participation, summary)
    }
}
