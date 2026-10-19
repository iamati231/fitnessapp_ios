import XCTest
@testable import FitnessAppCore

/// P8 Stufe 3: `BlockReviewRecord` ist das Einzige, was den zum Abschluss
/// tatsächlich GEZEIGTEN Befund dauerhaft (als JSON, siehe
/// `FourWeekReviewDueStatus` in FitnessAppData) einfriert. Dieser Test
/// deckt den reinen Codable-Vertrag ab — insbesondere, dass Swifts
/// automatische Codable-Synthese für Enums mit Payload (`Outcome`,
/// `Concern`, `DataGap`, inkl. verschachtelter
/// `ComebackAdvisor.Prescription`/`PlanParticipationEvaluator.UnreliableReason`)
/// tatsächlich verlustfrei roundtrippt, BEVOR das in FitnessAppData (nur auf
/// Apple-CI typprüfbar) produktiv verwendet wird.
final class BlockReviewRecordTests: XCTestCase {

    private func roundtrip(_ record: BlockReviewRecord) throws -> BlockReviewRecord {
        let data = try JSONEncoder().encode(record)
        return try JSONDecoder().decode(BlockReviewRecord.self, from: data)
    }

    func testRoundtripsAMigratedLegacyEntryWithoutAnyShownOutcome() throws {
        let record = BlockReviewRecord(
            blockStart: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_702_000_000),
            decision: .keptAsIs,
            shownOutcome: nil,
            shownDataGaps: nil
        )
        let decoded = try roundtrip(record)
        XCTAssertEqual(decoded, record)
    }

    func testRoundtripsKeepAsIsWithEmptyDataGaps() throws {
        let record = BlockReviewRecord(
            blockStart: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_702_000_000),
            decision: .keptAsIs,
            shownOutcome: .keepAsIs,
            shownDataGaps: []
        )
        XCTAssertEqual(try roundtrip(record), record)
    }

    /// Jede `Concern`-Fallunterscheidung mit Payload — der kritischste Teil
    /// der automatischen Codable-Synthese für Enums mit assoziierten Werten.
    func testRoundtripsEveryConcernCaseIncludingPayloads() throws {
        let concerns: [FourWeekReviewOrchestrator.Concern] = [
            .deloadRecommended,
            .comebackSuggested(ComebackAdvisor.Prescription(
                compoundFactor: 0.8, isolationFactor: 0.9, needsRetest: true
            )),
            .participationBelowPlan(missedCount: 3, plannedCount: 8),
            .complaintsReported,
            .goalNoLongerCurrent
        ]
        let record = BlockReviewRecord(
            blockStart: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_702_000_000),
            decision: .actionTaken,
            shownOutcome: .concernsFound(concerns),
            shownDataGaps: [
                .noCheckInYet,
                .participationHistoryPartiallyUnattributed,
                .participationNotReliablyEvaluable(.planHasNoTrainingDays),
                .participationNotReliablyEvaluable(.activationStartUnknown),
                .participationNotReliablyEvaluable(.planNotCurrentlyActive),
                .participationNotReliablyEvaluable(.evaluationBeforeActivation),
                .participationNotReliablyEvaluable(.noOpportunityDueYet)
            ]
        )
        let decoded = try roundtrip(record)
        XCTAssertEqual(decoded, record)
    }

    func testRoundtripsANilBlockStart() throws {
        let record = BlockReviewRecord(
            blockStart: nil,
            completedAt: Date(timeIntervalSince1970: 1_702_000_000),
            decision: nil,
            shownOutcome: nil,
            shownDataGaps: nil
        )
        XCTAssertEqual(try roundtrip(record), record)
    }

    /// Eine chronologische Liste (wie sie tatsächlich als
    /// `TrainingPlan.blockReviewHistoryJSON` gespeichert wird) roundtrippt
    /// ebenso verlustfrei.
    func testRoundtripsAnArrayOfRecords() throws {
        let records = [
            BlockReviewRecord(
                blockStart: Date(timeIntervalSince1970: 1_700_000_000),
                completedAt: Date(timeIntervalSince1970: 1_702_000_000),
                decision: .keptAsIs,
                shownOutcome: .keepAsIs,
                shownDataGaps: []
            ),
            BlockReviewRecord(
                blockStart: Date(timeIntervalSince1970: 1_702_086_400),
                completedAt: Date(timeIntervalSince1970: 1_705_000_000),
                decision: .actionTaken,
                shownOutcome: .concernsFound([.deloadRecommended]),
                shownDataGaps: [.noCheckInYet]
            )
        ]
        let data = try JSONEncoder().encode(records)
        let decoded = try JSONDecoder().decode([BlockReviewRecord].self, from: data)
        XCTAssertEqual(decoded, records)
    }
}
