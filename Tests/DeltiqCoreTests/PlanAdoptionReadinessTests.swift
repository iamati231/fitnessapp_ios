import XCTest
@testable import DeltiqCore

final class PlanAdoptionReadinessTests: XCTestCase {

    private func input(_ kind: TrainingTypeKind, days: Int) -> PlanGeneratorInput {
        PlanGeneratorInput(
            selections: [PlanGeneratorTypeSelection(kind: kind, daysPerWeek: days, sessionDurationMinutes: 45, experience: .intermediate)],
            equipmentPreferences: [],
            usesFixedWeekdays: false,
            fixedWeekdays: []
        )
    }

    private func loadLevels(for draft: PlanDraft, matching generated: PlanGenerator.Result) -> [DraftDayID: PlanLoadLevel] {
        let sortedGenerated = generated.days.sorted { $0.spec.sequenceIndex < $1.spec.sequenceIndex }
        return Dictionary(uniqueKeysWithValues: zip(draft.days, sortedGenerated).map { ($0.id, $1.loadLevel) })
    }

    func testEvaluateReturnsReadyForFullyCoveredDraft() {
        let original = PlanGenerator.generate(from: input(.barbell, days: 3))
        let draft = PlanDraft(generated: original.days.map(\.spec))
        let levels = loadLevels(for: draft, matching: original)

        let readiness = PlanAdoptionReadiness.evaluate(draft: draft, loadLevels: levels, explanationKey: "some.key")

        guard case .ready(let result) = readiness else {
            return XCTFail("expected .ready, got \(readiness)")
        }
        XCTAssertEqual(result.days.count, 3)
        XCTAssertEqual(readiness.result?.days.count, 3)
    }

    func testEvaluateReturnsEmptyPlanForNilDraft() {
        let readiness = PlanAdoptionReadiness.evaluate(draft: nil, loadLevels: [:], explanationKey: nil)
        guard case .emptyPlan = readiness else {
            return XCTFail("expected .emptyPlan, got \(readiness)")
        }
        XCTAssertNil(readiness.result)
    }

    func testEvaluateReturnsEmptyPlanForDraftWithoutDays() {
        let draft = PlanDraft(days: [])
        let readiness = PlanAdoptionReadiness.evaluate(draft: draft, loadLevels: [:], explanationKey: nil)
        guard case .emptyPlan = readiness else {
            return XCTFail("expected .emptyPlan, got \(readiness)")
        }
    }

    /// The exact case the PR #57 review flagged: a non-empty draft whose
    /// `loadLevelByDayID` lost coverage for one day must surface that day's
    /// id distinctly, not collapse into the same "nothing to adopt" bucket
    /// as a genuinely empty draft.
    func testEvaluateReturnsMissingLoadLevelWithOffendingDayIDForIncompleteDraft() {
        let original = PlanGenerator.generate(from: input(.barbell, days: 2))
        let draft = PlanDraft(generated: original.days.map(\.spec))
        let incompleteLevels = [draft.days[0].id: PlanLoadLevel.medium]

        let readiness = PlanAdoptionReadiness.evaluate(draft: draft, loadLevels: incompleteLevels, explanationKey: nil)

        guard case .missingLoadLevel(let dayID) = readiness else {
            return XCTFail("expected .missingLoadLevel, got \(readiness)")
        }
        XCTAssertEqual(dayID, draft.days[1].id)
        XCTAssertNil(readiness.result)
    }
}
