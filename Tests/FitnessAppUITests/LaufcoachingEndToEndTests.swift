#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
import FitnessAppCore

/// Task 9 (laufcoaching-remediation-round-2, end-to-end regression pass):
/// the literal sequence the user named - coach activation -> goal selection
/// -> plan generation -> opening the adjustment preview -> accepting ->
/// inspecting the adopted day's content - composed from the already-existing,
/// Task-2/3/6/7/8-extended model-level calls that back each step (no SwiftUI
/// render harness in this repo, see `CoachAdjustmentCardModelTests.
/// testCoachAdjustmentPreviewViewUsesModelProposedGoalForDayGeneration` for
/// the same source-introspection substitute used for the View layer itself).
///
/// Scenario (reused verbatim from `CardioFeasibilityCardModelTests.
/// testAcceptAppliesTheSuggestedGoalNotTheStaleInfeasibleGoalWhenAdjustingInPlace`
/// / `CoachAdjustmentCardModelTests.testAcceptAppliesTheSuggestedGoalNotTheStaleInfeasibleGoalWhenAdjustingInPlace`):
/// Marathon in 7 weeks at 15 km/week base is NOT feasible - 5K is the only
/// reachable smaller goal - so the proposed-goal survival through the whole
/// chain is actually exercised, not just "a plan got created".
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class LaufcoachingEndToEndTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testCoachActivationGoalSelectionGenerationPreviewAcceptAndAdoptedDayContentEndToEnd() throws {
        // MARK: 1. Coach activation + goal selection (mirrors onboarding/profile UI actions)
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male
        )
        context.insert(profile)
        profile.setEnduranceModality(.running, runCoachEnabled: true)
        XCTAssertTrue(profile.cardioCoachingEnabled, "Testaufbau: Laufcoach muss ueber setEnduranceModality aktiviert sein")

        profile.cardioGoal = .marathon
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 7)
        profile.weeklyBaseVolumeKm = 15
        profile.current5kReferenceSeconds = 1500 // 25:00 5K baseline - exercises pace too (Task 8)

        // MARK: 2. Generate plan selections (goal-driven structure, Tasks 2/3)
        // Exactly one eligible cardio day in the ORIGINAL plan - matches the "one anfassbarer
        // Cardio-Tag" shape `CoachAdjustmentCardModelTests.makeProfileAndPlan` and
        // `CardioFeasibilityCardModelTests.makeEligiblePlan` both use. `.fiveK` (the proposed goal
        // below) needs 2 running days/week though - Finding 1 (Lauf-Coaching-Audit) means `accept()`
        // now replaces this one eligible day AND inserts the remainder into one of the real,
        // auto-filled rest days `PlanGeneratorInstantiator.build`'s full week produces (instead of
        // the old, now-fixed bug that silently replaced only `newCardioDays[0]` and dropped the
        // rest) - see MARK: 6 below for the resulting two-day assertion.
        let selections = GoalDrivenPlanSelectionBuilder.makeSelections(
            goal: .endurance, enduranceModality: .running,
            totalDaysPerWeek: 1, sessionDurationMinutes: 45, experience: .intermediate,
            equipmentPreferences: [],
            cardioRunProfile: CardioRunProfile(
                goal: profile.cardioGoal,
                current5kReferenceSeconds: profile.current5kReferenceSeconds,
                weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm
            )
        )
        XCTAssertFalse(selections.isEmpty, "Testaufbau: Ausdauer-Ziel mit 1 Tag/Woche muss mindestens eine Selection ergeben")

        // MARK: 3. Build + persist the actual plan (real SwiftData object graph)
        let input = PlanGeneratorInput(selections: selections, equipmentPreferences: [], usesFixedWeekdays: false)
        let plan = try XCTUnwrap(PlanGeneratorInstantiator.build(
            from: input, in: context, environment: .gym, equipmentProfile: UserEquipmentProfile()
        ))
        XCTAssertTrue(plan.isActive, "Testaufbau: frisch gebauter Plan muss aktiv sein, sonst liefert CoachAdjustmentCardModel.make nil")

        let originalWorkoutDays = plan.days.filter { $0.type != .rest }
        XCTAssertEqual(originalWorkoutDays.count, 1, "Testaufbau: genau ein Trainingstag fuer eine deterministische Zuordnung in Schritt 5/6")
        let originalDay = try XCTUnwrap(originalWorkoutDays.first)
        XCTAssertFalse(originalDay.activeExercises.isEmpty)
        XCTAssertTrue(originalDay.activeExercises.allSatisfy(\.isCardio), "Testaufbau: der generierte Lauf-Tag muss ausschliesslich Cardio-Uebungen enthalten")

        // MARK: 4. Open the adjustment preview (model-level equivalent of CoachAdjustmentPreviewView opening)
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected a non-nil CoachAdjustmentCardModel - coach is enabled and an active plan exists")
        }
        XCTAssertEqual(model.verdict?.feasible, false, "Testaufbau: Marathon in 7 Wochen bei 15 km Basis muss NICHT erreichbar sein")
        guard let proposedGoal = model.proposedGoal else {
            return XCTFail("Testaufbau: es sollte ein kleineres, erreichbares Ziel vorgeschlagen werden")
        }
        XCTAssertEqual(proposedGoal, .fiveK, "Testaufbau: bei diesen Werten ist 5K das einzig erreichbare kleinere Ziel")
        XCTAssertNotEqual(proposedGoal, profile.cardioGoal, "Testaufbau: der Vorschlag muss vom urspruenglichen Ziel abweichen")

        // Same source-level check `CoachAdjustmentCardModelTests.
        // testCoachAdjustmentPreviewViewUsesModelProposedGoalForDayGeneration` proves for the real
        // View: the "after" preview the user would see is built from exactly this `proposedGoal`.
        let previewAfterDays = CoachAdjustmentCardModel.cardioOnlyDaySpecs(
            for: proposedGoal,
            cardioRunProfile: CardioRunProfile(
                goal: proposedGoal,
                current5kReferenceSeconds: profile.current5kReferenceSeconds,
                weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm
            )
        )
        XCTAssertFalse(previewAfterDays.isEmpty, "Testaufbau: es sollte Cardio-Tagesinhalte fuer das vorgeschlagene Ziel geben")

        // MARK: 5. Accept (model-level equivalent of tapping "apply to current plan")
        let appliedCount = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertGreaterThan(appliedCount, 0, "accept() muss den anfassbaren Cardio-Tag tatsaechlich anpassen")
        XCTAssertEqual(profile.cardioGoal, proposedGoal, "profile.cardioGoal muss auf das vorgeschlagene Ziel mitgezogen worden sein")

        // MARK: 6. Inspect the adopted day's content
        // SwiftData objects are live-updating within the same context - `plan`/`originalDay` already
        // reflect the post-accept state, no re-fetch needed.
        //
        // Finding 1 (Lauf-Coaching-Audit): `.fiveK` needs 2 running days/week (MARK: 2 above) but
        // the plan only had 1 eligible cardio day - accept() correctly REPLACES that one day AND
        // INSERTS the remainder into one of the real auto-filled rest days, so TWO workout days
        // result now, not one. (The old, now-fixed bug silently dropped the second day instead.)
        let adoptedWorkoutDays = plan.days.filter { $0.type != .rest }
        XCTAssertEqual(adoptedWorkoutDays.count, 2, "accept() muss den eligible Tag ersetzen UND den Rest in einen freien Ruhetag einfuegen")
        let adoptedOriginalDay = try XCTUnwrap(adoptedWorkoutDays.first { $0.persistentModelID == originalDay.persistentModelID })
        let insertedDays = adoptedWorkoutDays.filter { $0.persistentModelID != originalDay.persistentModelID }
        XCTAssertEqual(insertedDays.count, 1, "genau ein vormaliger Ruhetag muss in einen Cardio-Tag umgewandelt worden sein")
        let insertedDay = try XCTUnwrap(insertedDays.first)

        // (a) Task 7: the ORIGINAL (replaced) day's exercise names/structure match the proposed
        // goal's first generated day - the replace branch applies previewAfterDays[0] to the single
        // eligible day.
        XCTAssertEqual(
            adoptedOriginalDay.activeExercises.map(\.name), previewAfterDays[0].exercises.map(\.name),
            "der ersetzte Tag muss den Inhalt fuer das VORGESCHLAGENE Ziel (5K) tragen, nicht fuer das stale Marathon-Ziel"
        )

        // (a2) Finding 1 (Lauf-Coaching-Audit): der eingefuegte (vormalige Ruhe-)Tag muss den
        // ZWEITEN generierten Tag des vorgeschlagenen Ziels tragen - der Rest, den der alte Bug
        // stillschweigend verworfen hat.
        XCTAssertEqual(insertedDay.type, .cardio, "ein eingefuegter Tag muss explizit von .rest weg wechseln")
        XCTAssertEqual(
            insertedDay.activeExercises.map(\.name), previewAfterDays[1].exercises.map(\.name),
            "der eingefuegte Tag muss den Inhalt fuer den ZWEITEN generierten Lauftag des vorgeschlagenen Ziels tragen"
        )

        // (b) Task 8: the DATA that `SetRow.targetPaceHint` reads (content.nameSnapshot's
        // classification via `CardioExerciseZone.forExerciseName` + a duration-based target +
        // `current5kReferenceSeconds`) must actually allow computing a pace on at least one day -
        // the closest this data-layer test can get to exercising the UI logic directly.
        let paceableExercises = plan.days.flatMap(\.activeExercises).filter { exercise in
            let zone = CardioExerciseZone.forExerciseName(exercise.name)
            return (zone == .easy || zone == .tempo) && exercise.targetDurationMinutes != nil
        }
        XCTAssertFalse(paceableExercises.isEmpty, "Testaufbau: es sollte mindestens eine dauerbasierte Easy/Tempo-Lauf-Uebung geben")
        let referenceSeconds = try XCTUnwrap(profile.current5kReferenceSeconds)
        for exercise in paceableExercises {
            let zone = CardioExerciseZone.forExerciseName(exercise.name)
            let paceMinutesPerKm = zone == .easy
                ? PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: referenceSeconds)
                : PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: referenceSeconds)
            XCTAssertNotNil(
                paceMinutesPerKm,
                "exakt dieselbe Rechnung wie SetRow.targetPaceHint muss aus den persistierten Plandaten eine Pace liefern koennen"
            )
        }

        // MARK: 7. Fix I-1 (Final-Review, Round 2): the card must not reappear as pending after accept()
        // A fresh make() call (the equivalent of the card re-rendering, e.g. the user navigating back
        // to the dashboard) must recognize the adjustment as already applied - before the fix, `make()`
        // recomputed the fingerprint from the by-then-updated profile.cardioGoal (now .fiveK), which no
        // longer matched the fingerprint stored from the OLD (.marathon) goal.
        guard let freshModel = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected a non-nil CoachAdjustmentCardModel after accept()")
        }
        XCTAssertTrue(
            freshModel.isAlreadyApplied,
            "eine frische make()-Auswertung nach erfolgreichem accept() muss die Anpassung als bereits uebernommen erkennen"
        )
        let secondAppliedCount = try freshModel.accept(plan: plan, profile: profile, in: context)
        XCTAssertEqual(secondAppliedCount, 0, "ein zweiter accept()-Aufruf nach bereits erfolgter Uebernahme muss ein No-Op sein, keine doppelte Anwendung")
    }
}
#endif
