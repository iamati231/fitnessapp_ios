import Foundation

/// PR #57 Review: `PlanBuilderView` disabled its Adopt-Button on
/// `currentResult == nil`, which made the dedicated `missingLoadLevel` alert
/// unreachable from the UI - the button simply greyed out with no visible
/// reason. Extracted here (SwiftUI-free, directly testable) so the result
/// view can show the actual cause inline instead of hiding it behind a
/// disabled button, and distinguish "nothing to adopt" from "adoptable, but
/// one day's load level is missing" (see `PlanDraftResultAdapter.AdapterError`).
public enum PlanAdoptionReadiness {
    case ready(PlanGenerator.Result)
    case emptyPlan
    case missingLoadLevel(dayID: DraftDayID)

    public static func evaluate(
        draft: PlanDraft?,
        loadLevels: [DraftDayID: PlanLoadLevel],
        explanationKey: String?
    ) -> PlanAdoptionReadiness {
        guard let draft, !draft.days.isEmpty else { return .emptyPlan }
        do {
            guard let result = try PlanDraftResultAdapter.makeResult(
                from: draft, loadLevels: loadLevels, explanationKey: explanationKey
            ) else { return .emptyPlan }
            return .ready(result)
        } catch PlanDraftResultAdapter.AdapterError.missingLoadLevel(let dayID) {
            return .missingLoadLevel(dayID: dayID)
        } catch {
            return .emptyPlan
        }
    }

    public var result: PlanGenerator.Result? {
        if case .ready(let result) = self { return result }
        return nil
    }
}
