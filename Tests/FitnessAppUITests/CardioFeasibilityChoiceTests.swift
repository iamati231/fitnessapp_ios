#if canImport(SwiftUI)
import XCTest

/// Task 8 (Laufcoaching Dual-Path, equipment-vielfalt-laufcoaching-dual-path,
/// 2026-10-25): ledger ruling.
///
/// Brief's Step 1 asked whether `CardioFeasibilityCardModel.accept`'s
/// `activePlan`-branch (silent choice between in-place adjustment via
/// `CoachAdjustmentCardModel` and `createPlan`) is still reachable once an
/// active plan exists, given `CoachAdjustmentCardModel`'s own doc comment
/// claim ("die neue Karte hat Vorrang, sobald ein aktiver Plan existiert").
/// A full call-site trace (grep every real invocation of
/// `CardioFeasibilityCardModel.accept`, not just its definition) found FOUR
/// call sites and none of them can reach that branch with a non-nil,
/// `.ready` `activePlan`:
///
/// - `ProfileEditorView.feasibilitySection` / `PlansListView.
///   cardioFeasibilitySection`: both render only in the `else` branch of an
///   `if let coachAdjustmentModel { .. } else if let feasibilityModel { .. }`
///   (`DashboardCardioCardPriorityTests`/`PlansListCoachAdjustmentPriorityTests`
///   already guard this precedence). `CoachAdjustmentCardModel.make` is `nil`
///   only when `activePlan == nil` or `!cardioCoachingEnabled` -
///   `CardioFeasibilityCardModel.make` already requires
///   `cardioCoachingEnabled == true` on its own, so whenever the fallback
///   section is shown, `activePlan` (the SAME `@Query`-backed value then
///   passed into `accept(activePlan:)`) must itself be `nil`.
/// - `DashboardView.cardioFeasibilityDashboardCard`: does not call `accept`
///   at all (its button only navigates to the Plan tab).
/// - `CoachAdjustmentPreviewView.createNewPlanButton`: calls
///   `CardioFeasibilityCardModel.accept` WITHOUT an `activePlan` argument
///   (defaulted to `nil`) - deliberately, per that file's own doc comment,
///   so the explicit "als neuen Plan erstellen" tap is never silently
///   redirected into the in-place path offered right above it.
///
/// Outcome A (dead code): the branch was unreachable in every real call
/// path even before this ticket. Deleted here, narrowing `accept` to its one
/// remaining real job - no active plan yet, straight to `createPlan`, no
/// choice needed - instead of building a second explicit-choice UI for a
/// case nothing can ever reach.
///
/// Source-introspection (kein SwiftUI-Render-Harness in diesem Repo -
/// `FitnessAppUI` kann auf diesem Windows-Host nicht gebaut/ausgefuehrt
/// werden), gleiches Muster wie `CoachAdjustmentInsertionUITests`/
/// `DashboardCardioCardPriorityTests`.
final class CardioFeasibilityChoiceTests: XCTestCase {

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

    private func acceptSignatureAndBody() throws -> (signature: String, body: String) {
        let source = try contents(of: "Cardio/CardioFeasibilityCardModel.swift")
        guard let signatureStart = source.range(of: "public func accept(") else {
            XCTFail("accept(...) not found")
            return ("", "")
        }
        guard let openBraceRange = source.range(of: "{", range: signatureStart.upperBound..<source.endIndex) else {
            XCTFail("accept(...) has no opening brace")
            return ("", "")
        }
        let signature = String(source[signatureStart.lowerBound..<openBraceRange.lowerBound])
        guard let body = Self.matchingBraceBlock(in: source, afterOpenBrace: openBraceRange.upperBound) else {
            XCTFail("could not isolate accept(...)'s body")
            return (signature, "")
        }
        return (signature, body)
    }

    // MARK: - The dead branch is gone from CardioFeasibilityCardModel.accept

    /// `accept` no longer takes an `activePlan` parameter - there is nothing
    /// left for it to choose between, since the only real caller that could
    /// ever pass a non-nil, `.ready` plan (`ProfileEditorView`/
    /// `PlansListView`) never actually reaches this call once one exists
    /// (`CoachAdjustmentCardModel` wins first, per Leitplanke 6).
    func testAcceptNoLongerTakesAnActivePlanParameter() throws {
        let (signature, _) = try acceptSignatureAndBody()
        XCTAssertFalse(signature.contains("activePlan"), "accept(...) must no longer declare an activePlan parameter - the branch it fed is unreachable dead code")
    }

    /// The silent routing logic itself (delegating to
    /// `CoachAdjustmentCardModel`/`RunCoachPlanAdjustment` instead of
    /// creating a new plan) must be gone from the body, not just
    /// unreachable.
    func testAcceptBodyNoLongerRoutesThroughCoachAdjustmentCardModel() throws {
        let (_, body) = try acceptSignatureAndBody()
        XCTAssertFalse(body.contains("CoachAdjustmentCardModel.make"), "accept(...) must no longer delegate to CoachAdjustmentCardModel - that was the dead silent-choice branch")
        XCTAssertFalse(body.contains("RunCoachPlanAdjustment.analyze"), "accept(...) must no longer branch on RunCoachPlanAdjustment's cardioAvailability")
    }

    /// `accept`'s one remaining job: no active plan to choose, straight to
    /// `createPlan` via the existing `PlanCreationOperation` plumbing.
    func testAcceptStillDelegatesToPlanGeneratorInstantiatorCreatePlan() throws {
        let (_, body) = try acceptSignatureAndBody()
        XCTAssertTrue(body.contains("PlanGeneratorInstantiator.createPlan("), "accept(...) must still create a new plan - its one remaining real job")
    }

    // MARK: - Call sites no longer pass the now-removed activePlan argument

    /// `ProfileEditorView.feasibilitySection`'s accept call must have
    /// dropped the now-meaningless `activePlan:` argument.
    func testProfileEditorViewNoLongerPassesActivePlanToAccept() throws {
        let source = try contents(of: "Settings/ProfileEditorView.swift")
        guard let callRange = source.range(of: "model.accept(profile: profile, in: modelContext, using: acceptOperation") else {
            XCTFail("expected accept(...) call site not found in ProfileEditorView"); return
        }
        let tail = source[callRange.upperBound...].prefix(60)
        XCTAssertFalse(tail.contains("activePlan"), "ProfileEditorView must no longer pass activePlan: to accept(...) - the parameter is gone")
    }

    /// `PlansListView.cardioFeasibilitySection`'s accept call must have
    /// dropped the now-meaningless `activePlan:` argument.
    func testPlansListViewNoLongerPassesActivePlanToAccept() throws {
        let source = try contents(of: "Workout/PlansListView.swift")
        guard let callRange = source.range(of: "model.accept(profile: profile, in: modelContext, using: acceptOperation") else {
            XCTFail("expected accept(...) call site not found in PlansListView"); return
        }
        let tail = source[callRange.upperBound...].prefix(60)
        XCTAssertFalse(tail.contains("activePlan"), "PlansListView must no longer pass activePlan: to accept(...) - the parameter is gone")
    }

    // MARK: - Supporting evidence for the ledger ruling: the precedence that made the branch dead

    /// `ProfileEditorView.feasibilityModel` must remain gated on
    /// `coachAdjustmentModel == nil` - this is the architectural reason the
    /// deleted branch was unreachable; it must keep holding so the
    /// conclusion stays valid.
    func testProfileEditorViewFeasibilityModelStillGatesOnCoachAdjustmentModel() throws {
        let source = try contents(of: "Settings/ProfileEditorView.swift")
        guard let propertyRange = source.range(of: "private var feasibilityModel: CardioFeasibilityCardModel? {") else {
            XCTFail("feasibilityModel property not found"); return
        }
        let tail = source[propertyRange.upperBound...].prefix(300)
        XCTAssertTrue(tail.contains("guard coachAdjustmentModel == nil else { return nil }"), "feasibilityModel must still guard on coachAdjustmentModel == nil (Leitplanke 6)")
    }
}
#endif
