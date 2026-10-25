#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

/// Task 7 (Laufcoaching-Plan-Integration) had given `CardioFeasibilityCardModel.accept()` an
/// `activePlan` parameter that silently chose between adjusting an existing plan in place (via
/// `CoachAdjustmentCardModel`/`RunCoachPlanAdjustment`) and creating a new one. Task 8 (Laufcoaching
/// Dual-Path, ledger ruling, see `CardioFeasibilityCardModel.accept`'s own doc comment) found that
/// choice was unreachable at every real call site - `CoachAdjustmentCardModel` always wins first
/// once an active plan exists (Leitplanke 6) - and removed both the `activePlan` parameter and the
/// branch it fed. `accept()` now only ever creates a new plan; the tests that used to cover the
/// removed in-place branch were retired along with it (see `CardioFeasibilityChoiceTests.swift` for
/// the source-introspection coverage proving the removal).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CardioFeasibilityCardModelTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    override func tearDownWithError() throws {
        container = nil
        // Nachbesserung (gleiches Muster wie `PlanGeneratorInstantiatorTests`): statischer
        // Test-DI-Seam auf dem Typ, nicht Instanz-State - muss nach jedem Test zurueckgesetzt
        // werden, sonst "leakt" ein hier gesetzter Mock in alle nachfolgenden Tests.
        PlanGeneratorInstantiator.saveOverrideForTesting = nil
    }

    /// 10K-Ziel, 20 Wochen verfuegbar / 20 km Wochenbasis - klar erreichbar
    /// (`verdict.feasible == true`), identisches Muster wie
    /// `CoachAdjustmentCardModelTests.makeProfileAndPlan`. `feasible == true` ist hier bewusst
    /// gewaehlt: `CardioFeasibilityCardModel.proposedGoal` entspricht dann exakt
    /// `profile.cardioGoal`, also demselben Ziel, das `CoachAdjustmentCardModel.make` ohnehin
    /// unabhaengig direkt aus `profile.cardioGoal` liest - beide Modelle meinen dieselbe
    /// Ziel/Renndatum/Wochenvolumen-Kombination.
    private func makeProfile() -> UserBodyProfile {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)
        return profile
    }

    func testAcceptStillCreatesANewPlanWhenNoActivePlanExists() throws {
        let profile = makeProfile()
        guard let model = CardioFeasibilityCardModel.make(for: profile) else {
            return XCTFail("expected model")
        }

        let plansBefore = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        let operation = PlanCreationOperation()
        let outcome = model.accept(profile: profile, in: context, using: operation)

        guard case .success(let newPlan) = outcome else {
            return XCTFail("expected .success, got \(String(describing: outcome))")
        }
        XCTAssertEqual(newPlan.generationSource, .cardioCoach)

        let plansAfter = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        XCTAssertEqual(plansAfter, plansBefore + 1, "accept() must still create a new plan - its one remaining job")
    }
}
#endif
