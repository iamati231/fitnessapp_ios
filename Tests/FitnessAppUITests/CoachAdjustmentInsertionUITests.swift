#if canImport(SwiftUI)
import XCTest

/// Phase B (Laufcoaching Dual-Path, Task 7): Task 5/6 added eligibility
/// detection (`RunCoachPlanAdjustment.eligibleRestDaysForInsertion`/
/// `Analysis.insertableRestDays`) and the insertion mechanics
/// (`RunCoachPlanAdjustment.selectRestDaysForInsertion`,
/// `PlanGeneratorInstantiator.insertCoachCardioDays`) but never wired either
/// into the user-facing coach-adjustment preview flow
/// (`CoachAdjustmentCardModel`/`CoachAdjustmentPreviewView`) - a plan with
/// zero cardio days showed only "nothing to do" even when it had rest days
/// that could become cardio days. Source-introspection (kein SwiftUI-
/// Render-Harness in diesem Repo - `FitnessAppUI` kann auf diesem
/// Windows-Host nicht gebaut/ausgefuehrt werden), gleiches Muster wie
/// `DashboardCardioCardPriorityTests`/`PlansListCoachAdjustmentPriorityTests`.
final class CoachAdjustmentInsertionUITests: XCTestCase {

    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/FitnessAppUI")
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func matchingBraceBlock(in source: String, afterOpenBrace start: String.Index) -> String? {
        var depth = 1
        var index = start
        while index < source.endIndex {
            let char = source[index]
            if char == "{" { depth += 1 } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    private func acceptFunctionBody() throws -> String {
        let source = try contents(of: "Cardio/CoachAdjustmentCardModel.swift")
        guard let signatureRange = source.range(of: "public func accept(") else {
            XCTFail("accept(...) not found")
            return ""
        }
        guard let openBraceRange = source.range(of: "{", range: signatureRange.upperBound..<source.endIndex) else {
            XCTFail("accept(...) has no opening brace")
            return ""
        }
        guard let body = Self.matchingBraceBlock(in: source, afterOpenBrace: openBraceRange.upperBound) else {
            XCTFail("could not isolate accept(...)'s body")
            return ""
        }
        return body
    }

    // MARK: - CoachAdjustmentCardModel.accept: insertion branch

    /// Step 1 (brief): `accept` must call `insertCoachCardioDays` when there
    /// is no replaceable cardio day but at least one insertable rest day.
    func testAcceptCallsInsertCoachCardioDaysWhenNoReplaceableCardioDayExists() throws {
        let body = try acceptFunctionBody()
        XCTAssertTrue(
            body.contains("PlanGeneratorInstantiator.insertCoachCardioDays("),
            "accept() must fall back to the Task 6 insertion path"
        )
        XCTAssertTrue(
            body.contains("if eligibleDays.isEmpty"),
            "the insertion branch must only fire when there is no replaceable cardio day (eligibleDays.isEmpty)"
        )
    }

    /// Re-validation contract (binding decision): `accept` must recompute
    /// eligible rest days FRESH at call time via
    /// `RunCoachPlanAdjustment.eligibleRestDaysForInsertion(in: plan)`, never
    /// trust the stale `analysis.insertableRestDays` snapshot captured by
    /// `make` - same freshness principle `eligibleDays`/`isAlreadyApplied`
    /// already follow in this type.
    func testAcceptRecomputesEligibleRestDaysFreshInsteadOfTrustingTheStaleAnalysisSnapshot() throws {
        let body = try acceptFunctionBody()
        XCTAssertTrue(
            body.contains("RunCoachPlanAdjustment.eligibleRestDaysForInsertion(in: plan)"),
            "must recompute eligible rest days fresh from the current plan"
        )
        XCTAssertFalse(
            body.contains("analysis.insertableRestDays"),
            "must never reuse self's analysis.insertableRestDays snapshot from make-time - it can be stale by accept-time"
        )
    }

    /// Selection must use `newCardioDays.count` - the actual number of
    /// cardio-only day specs `cardioOnlyDaySpecs`/`PlanGenerator.generate`
    /// produced for the effective goal - as the number of rest days to
    /// select, NOT `CardioFeasibilityCalculator.runTypeMix(...).count`
    /// (review fix: `runTypeMix` is an easy/quality PATTERN cycled across
    /// the real run-day count, e.g. `PlanGenerator.swift`'s
    /// `mix[dayIndex % mix.count]` - not itself a 1:1 run-day count, and
    /// diverges from the real day count for `.generalFitness`/`.tenK`/
    /// `.marathon`, which made `insertCoachCardioDays` always throw
    /// `.insufficientRestDays` for those goals).
    func testAcceptSelectsRestDaysUsingNewCardioDaysCountForTheEffectiveGoal() throws {
        let body = try acceptFunctionBody()
        XCTAssertFalse(
            body.contains("CardioFeasibilityCalculator.runTypeMix("),
            "runTypeMix is a cycled easy/quality pattern, not a run-day count - it must not be used to size the rest-day selection"
        )
        guard let selectRange = body.range(of: "RunCoachPlanAdjustment.selectRestDaysForInsertion(") else {
            XCTFail("selectRestDaysForInsertion call not found"); return
        }
        let callSite = body[selectRange.lowerBound...].prefix(200)
        XCTAssertTrue(
            callSite.contains("count: newCardioDays.count"),
            "must select exactly as many rest days as newCardioDays.count (the actual generated cardio-day count for the effective goal)"
        )
    }

    /// Binding decision: `insertCoachCardioDays`'s thrown re-validation
    /// errors must NOT be swallowed inside `accept` (no local catch around
    /// that call) - they must propagate to the caller as a distinct failure.
    func testAcceptDoesNotSwallowInsertCoachCardioDaysErrors() throws {
        let body = try acceptFunctionBody()
        guard let callRange = body.range(of: "PlanGeneratorInstantiator.insertCoachCardioDays(") else {
            XCTFail("insertCoachCardioDays call not found"); return
        }
        XCTAssertTrue(
            body[body.startIndex..<callRange.lowerBound].hasSuffix("count = try ")
                || body[body.startIndex..<callRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("try"),
            "the call must be a direct `try` (propagating), not wrapped in a local do/catch that swallows the error"
        )
    }

    // MARK: - CoachAdjustmentPreviewView: Apply button reachable for the insertion case

    /// Step 1 (brief): the `.noEligibleCardioDay` branch must show the
    /// "Apply to current plan" action whenever `insertableRestDays` is
    /// non-empty, instead of only the "create new plan" fallback.
    func testNoEligibleCardioDayBranchShowsApplyActionWhenInsertableRestDaysExist() throws {
        let source = try contents(of: "Cardio/CoachAdjustmentPreviewView.swift")
        guard let caseRange = source.range(of: "case .noEligibleCardioDay:") else {
            XCTFail(".noEligibleCardioDay case not found"); return
        }
        guard let nextCaseRange = source.range(of: "case .noActivePlan:", range: caseRange.upperBound..<source.endIndex) else {
            XCTFail(".noActivePlan case not found (end of .noEligibleCardioDay block)"); return
        }
        let block = source[caseRange.upperBound..<nextCaseRange.lowerBound]
        XCTAssertTrue(
            block.contains("model.analysis.insertableRestDays.isEmpty"),
            "the branch must check analysis.insertableRestDays to decide whether to offer insertion"
        )
        XCTAssertTrue(
            block.contains("actionButtons(model)"),
            "when rest days are insertable, the same actionButtons(_:) (which renders the Apply-to-current-plan button) must be shown"
        )
    }

    // MARK: - Before/after rendering: inserted day vs. replaced day

    /// The existing replace-path rendering (`.ready` case) must keep
    /// strikethrough old-day names - this task must not disturb it.
    func testReplacePathStillRendersStruckThroughOldDayNames() throws {
        let source = try contents(of: "Cardio/CoachAdjustmentPreviewView.swift")
        guard let readyRange = source.range(of: "case .ready(let ids):") else {
            XCTFail("case .ready not found"); return
        }
        guard let nextCaseRange = source.range(of: "case .noEligibleCardioDay:", range: readyRange.upperBound..<source.endIndex) else {
            XCTFail("case .noEligibleCardioDay not found (end of .ready block)"); return
        }
        let block = source[readyRange.upperBound..<nextCaseRange.lowerBound]
        XCTAssertTrue(block.contains(".strikethrough()"), "the replace path must keep showing the old day name struck through")
    }

    /// New insert-path rendering must show "— → <new day name>" with NO
    /// struck-through old name (there is no "old" day being replaced).
    func testInsertPathRendersArrowWithoutAnOldNameAndWithoutStrikethrough() throws {
        let source = try contents(of: "Cardio/CoachAdjustmentPreviewView.swift")
        guard let caseRange = source.range(of: "case .noEligibleCardioDay:") else {
            XCTFail(".noEligibleCardioDay case not found"); return
        }
        guard let nextCaseRange = source.range(of: "case .noActivePlan:", range: caseRange.upperBound..<source.endIndex) else {
            XCTFail(".noActivePlan case not found (end of .noEligibleCardioDay block)"); return
        }
        let block = source[caseRange.upperBound..<nextCaseRange.lowerBound]
        XCTAssertTrue(block.contains("— → \\(spec.name)"), "an inserted slot must render as \"— → <new day name>\"")
        XCTAssertFalse(block.contains(".strikethrough()"), "an inserted day has no old exercise being replaced, so it must never be struck through")
    }

    // MARK: - Distinct, user-readable failure when the plan changed since preview

    /// Binding decision: `insertCoachCardioDays`'s thrown
    /// `CardioInsertionError` must surface as a distinct, user-readable
    /// failure state, not be swallowed into the generic
    /// `error.localizedDescription` catch-all (which would show an
    /// unreadable "operation couldn't be completed" message).
    func testCardioInsertionErrorIsCaughtDistinctlyWithAReadableMessage() throws {
        let source = try contents(of: "Cardio/CoachAdjustmentPreviewView.swift")
        guard let tryRange = source.range(of: "try model.accept(plan: activePlan, profile: profile, in: modelContext)") else {
            XCTFail("model.accept(...) call not found"); return
        }
        let tail = source[tryRange.upperBound...].prefix(800)
        XCTAssertTrue(
            tail.contains("catch is PlanGeneratorInstantiator.CardioInsertionError"),
            "must have a dedicated catch clause for CardioInsertionError, distinct from the generic catch-all"
        )
        guard let dedicatedCatchRange = tail.range(of: "catch is PlanGeneratorInstantiator.CardioInsertionError") else {
            XCTFail("dedicated catch clause not found"); return
        }
        guard let genericCatchRange = tail.range(of: "} catch {", range: dedicatedCatchRange.upperBound..<tail.endIndex) else {
            XCTFail("generic catch-all not found after the dedicated clause"); return
        }
        let dedicatedBlock = tail[dedicatedCatchRange.upperBound..<genericCatchRange.lowerBound]
        XCTAssertTrue(
            dedicatedBlock.contains("errorMessage ="),
            "the dedicated catch must still set errorMessage (so the existing alert UI shows it)"
        )
        XCTAssertFalse(
            dedicatedBlock.contains("error.localizedDescription"),
            "must not fall back to the unreadable generic error description for this specific, anticipated failure"
        )
    }
}
#endif
