#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Phase B (Laufcoaching Dual-Path, Task 6): die eigentliche Einfuege-
/// Mechanik - WELCHE eignungsfaehigen Rest-Tage (Task 5:
/// `RunCoachPlanAdjustment.isEligibleRestDayForInsertion`) ausgewaehlt werden
/// (`selectRestDaysForInsertion`) und wie sie tatsaechlich zu Cardio-Tagen
/// umgewandelt werden (`PlanGeneratorInstantiator.insertCoachCardioDays`,
/// reuses `apply(_:to:...)`/`DayMutationSnapshot`/`revert(_:in:)` mit dem neu
/// ergaenzten `targetType`-Parameter).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CoachCardioInsertionTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    override func tearDownWithError() throws {
        container = nil
        // Statischer Test-DI-Seam auf dem Typ, nicht Instanz-State - muss nach
        // jedem Test zurueckgesetzt werden, sonst "leakt" ein hier gesetzter
        // Mock in alle nachfolgenden Tests (gleiches Muster wie
        // `CoachAdjustmentCardModelTests`).
        PlanGeneratorInstantiator.saveOverrideForTesting = nil
    }

    private struct TestSaveError: Error {}

    private func makePlan() -> TrainingPlan {
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        return plan
    }

    @discardableResult
    private func insert(_ day: TrainingDay, into plan: TrainingPlan) -> TrainingDay {
        context.insert(day)
        plan.days.append(day)
        return day
    }

    private func cardioDaySpec(name: String = "Lauf", sequenceIndex: Int = 1) -> DaySpec {
        DaySpec(
            name: name,
            type: .cardio,
            sequenceIndex: sequenceIndex,
            exercises: [
                ExerciseSpec(name: "Easy Run", sets: 1, repsMin: 1, repsMax: 1, isCardio: true, targetDistanceKm: 5.0)
            ]
        )
    }

    // MARK: - selectRestDaysForInsertion

    func test_selectRestDaysForInsertion_isDeterministic() {
        let plan = makePlan()
        let strength = insert(TrainingDay(name: "Legs", weekday: 3, type: .legs, plan: plan), into: plan)
        let rest1 = insert(
            TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let rest2 = insert(
            TrainingDay(name: "Ruhetag", weekday: 5, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let rest3 = insert(
            TrainingDay(name: "Ruhetag", weekday: 7, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let eligible = [rest1, rest2, rest3]
        let otherDays = [strength]

        let first = RunCoachPlanAdjustment.selectRestDaysForInsertion(eligible: eligible, count: 2, otherDays: otherDays)
        let second = RunCoachPlanAdjustment.selectRestDaysForInsertion(eligible: eligible, count: 2, otherDays: otherDays)

        XCTAssertEqual(first.map(\.persistentModelID), second.map(\.persistentModelID))
    }

    func test_selectRestDaysForInsertion_avoidsAdjacentHardStrengthDay_whenAlternativeExists() {
        let plan = makePlan()
        let strength = insert(TrainingDay(name: "Legs", weekday: 3, type: .legs, plan: plan), into: plan)
        // Adjacent to the strength day (weekday 3): weekday 4.
        let adjacent = insert(
            TrainingDay(name: "Ruhetag", weekday: 4, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let nonAdjacent1 = insert(
            TrainingDay(name: "Ruhetag", weekday: 6, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let nonAdjacent2 = insert(
            TrainingDay(name: "Ruhetag", weekday: 7, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let eligible = [adjacent, nonAdjacent1, nonAdjacent2]

        let selected = RunCoachPlanAdjustment.selectRestDaysForInsertion(eligible: eligible, count: 2, otherDays: [strength])

        XCTAssertEqual(
            Set(selected.map(\.persistentModelID)),
            Set([nonAdjacent1.persistentModelID, nonAdjacent2.persistentModelID]),
            "muss die beiden NICHT-benachbarten Tage bevorzugen, solange genug Alternativen da sind"
        )
    }

    // MARK: - insertCoachCardioDays: happy path

    func test_insertCoachCardioDays_convertsRestDayToCardioContent() throws {
        let plan = makePlan()
        let restDay = insert(
            TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let spec = cardioDaySpec()

        let count = try PlanGeneratorInstantiator.insertCoachCardioDays(
            plan: plan, restDays: [restDay], newCardioDays: [spec], in: context
        )

        XCTAssertEqual(count, 1)
        XCTAssertEqual(restDay.type, .cardio, "ein eingefuegter Tag muss explizit von .rest weg wechseln")
        XCTAssertEqual(restDay.activeExercises.map(\.name), spec.exercises.map(\.name))
        XCTAssertNotNil(restDay.generationFingerprint)
        XCTAssertEqual(restDay.generationFingerprint, restDay.currentContentFingerprint)
    }

    func test_insertCoachCardioDays_neverTouchesNonSelectedDays() throws {
        let plan = makePlan()
        let selectedRestDay = insert(
            TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let untouchedRestDay = insert(
            TrainingDay(name: "Ruhetag", weekday: 4, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let spec = cardioDaySpec()

        _ = try PlanGeneratorInstantiator.insertCoachCardioDays(
            plan: plan, restDays: [selectedRestDay], newCardioDays: [spec], in: context
        )

        XCTAssertEqual(selectedRestDay.type, .cardio)
        XCTAssertEqual(untouchedRestDay.type, .rest, "ein Tag, der gar nicht in `restDays` uebergeben wurde, darf nie angefasst werden")
        XCTAssertTrue(untouchedRestDay.activeExercises.isEmpty)
        XCTAssertNil(untouchedRestDay.generationFingerprint)
    }

    // MARK: - insertCoachCardioDays: re-validation contract (throws before any mutation)

    func test_insertCoachCardioDays_throwsAndWritesNothing_whenADayBelongsToADifferentPlan() {
        let plan = makePlan()
        let otherPlan = makePlan()
        // Stale reference: `restDay` genuinely belongs to `otherPlan`, but is
        // passed alongside `plan` here - exactly the "earlier preview of a
        // different plan" scenario the re-validation contract guards against.
        let restDay = insert(
            TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: otherPlan, isAutoFilledPlaceholder: true),
            into: otherPlan
        )
        let spec = cardioDaySpec()

        XCTAssertThrowsError(
            try PlanGeneratorInstantiator.insertCoachCardioDays(plan: plan, restDays: [restDay], newCardioDays: [spec], in: context)
        ) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.CardioInsertionError, .restDayBelongsToAnotherPlan)
        }

        XCTAssertEqual(restDay.type, .rest, "VOR jeder Mutation geworfen - keine Teil-Aenderung")
        XCTAssertTrue(restDay.activeExercises.isEmpty)
        XCTAssertNil(restDay.generationFingerprint)
    }

    func test_insertCoachCardioDays_throwsAndWritesNothing_whenRestDaysCountIsInsufficient() {
        let plan = makePlan()
        let restDay = insert(
            TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let spec1 = cardioDaySpec(name: "Lauf 1", sequenceIndex: 1)
        let spec2 = cardioDaySpec(name: "Lauf 2", sequenceIndex: 2)

        XCTAssertThrowsError(
            try PlanGeneratorInstantiator.insertCoachCardioDays(
                plan: plan, restDays: [restDay], newCardioDays: [spec1, spec2], in: context
            )
        ) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.CardioInsertionError, .insufficientRestDays)
        }

        XCTAssertEqual(restDay.type, .rest)
        XCTAssertNil(restDay.generationFingerprint)
    }

    func test_insertCoachCardioDays_throwsAndWritesNothing_whenAPassedRestDayIsNoLongerEligible() {
        let plan = makePlan()
        let day1 = insert(
            TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let day2 = insert(
            TrainingDay(name: "Ruhetag", weekday: 4, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        // `day2` gets a logged session AFTER the caller computed `restDays`
        // (e.g. the user started a spontaneous workout between the preview
        // and tapping "accept") - it is no longer eligible NOW, regardless of
        // what the caller passed in.
        let session = WorkoutSession(startTime: Date(), day: day2)
        context.insert(session)
        day2.sessions.append(session)

        let spec1 = cardioDaySpec(name: "Lauf 1", sequenceIndex: 1)
        let spec2 = cardioDaySpec(name: "Lauf 2", sequenceIndex: 2)

        XCTAssertThrowsError(
            try PlanGeneratorInstantiator.insertCoachCardioDays(
                plan: plan, restDays: [day1, day2], newCardioDays: [spec1, spec2], in: context
            )
        ) { error in
            XCTAssertEqual(error as? PlanGeneratorInstantiator.CardioInsertionError, .restDayNoLongerEligible)
        }

        XCTAssertEqual(day1.type, .rest, "day1 war noch gueltig, darf trotzdem nicht angefasst worden sein")
        XCTAssertNil(day1.generationFingerprint)
        XCTAssertEqual(day2.type, .rest)
    }

    // MARK: - revert on save failure

    /// Fuenfte Review-Runde, Praezisierung 4: `applyCoachCardioAdjustment`
    /// (und damit auch `insertCoachCardioDays`, die denselben `apply`/`save`/
    /// `revert`-Ablauf wiederverwendet) hat genau EINEN `save(context)`-Aufruf
    /// ganz am Ende, NACHDEM `apply()` bereits fuer ALLE Ziel-Tage in-memory
    /// gelaufen ist - kein "Tag 1 persistiert, Tag 2 gescheitert"-Fall
    /// moeglich. Der Spy im `saveOverrideForTesting`-Closure beweist das:
    /// zum Zeitpunkt des (simulierten) Scheiterns sind BEREITS beide Tage auf
    /// `.cardio` gesetzt.
    func test_insertCoachCardioDays_revertOnFailure_restoresDayTypeToRest() throws {
        let plan = makePlan()
        let day1 = insert(
            TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let day2 = insert(
            TrainingDay(name: "Ruhetag", weekday: 4, type: .rest, plan: plan, isAutoFilledPlaceholder: true), into: plan
        )
        let spec1 = cardioDaySpec(name: "Lauf 1", sequenceIndex: 1)
        let spec2 = cardioDaySpec(name: "Lauf 2", sequenceIndex: 2)

        var cardioCountDuringSave = -1
        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in
            cardioCountDuringSave = [day1, day2].filter { $0.type == .cardio }.count
            throw TestSaveError()
        }

        XCTAssertThrowsError(
            try PlanGeneratorInstantiator.insertCoachCardioDays(
                plan: plan, restDays: [day1, day2], newCardioDays: [spec1, spec2], in: context
            )
        )

        XCTAssertEqual(cardioCountDuringSave, 2, "apply() muss fuer BEIDE Tage gelaufen sein, bevor der Save scheitert")

        // Jedes Feld, das `DayMutationSnapshot` traegt, fuer JEDEN betroffenen Tag.
        for day in [day1, day2] {
            XCTAssertEqual(day.type, .rest, "oldType muss zurueckgeschrieben werden")
            XCTAssertEqual(day.name, "Ruhetag")
            XCTAssertNil(day.customName)
            XCTAssertNil(day.localizationKey)
            XCTAssertNil(day.timeFormat)
            XCTAssertNil(day.timeCapMinutes)
            XCTAssertTrue(day.activeExercises.isEmpty, "eingefuegte Uebungen muessen wieder geloescht sein")
            XCTAssertNil(day.generationFingerprint)
        }
    }

    /// Condition 4 (User-Entscheidung: "getestet fuer sowohl den bestehenden
    /// Ersetzungs- als auch den neuen Einfuege-Pfad"): `applyCoachCardioAdjustment`
    /// uebergibt `targetType` nie (bleibt `nil`) - `oldType` ist dadurch fuer
    /// jeden ihrer Snapshots `nil`, `revert` darf `day.type` in diesem Fall
    /// also gar nicht anfassen (echtes No-op, kein versteckter Reset auf
    /// irgendeinen Default).
    func test_applyCoachCardioAdjustment_replacePath_revertOnFailure_leavesTypeUnchanged() throws {
        let plan = makePlan()
        let curatedCardioDay = insert(TrainingDay(name: "Lauf", weekday: 2, type: .cardio, plan: plan), into: plan)
        curatedCardioDay.generationFingerprint = curatedCardioDay.currentContentFingerprint
        let wizardFullBodyDay = insert(TrainingDay(name: "Ganzkoerper", weekday: 4, type: .fullBody, plan: plan), into: plan)
        wizardFullBodyDay.generationFingerprint = wizardFullBodyDay.currentContentFingerprint

        let spec1 = cardioDaySpec(name: "Neuer Lauf 1", sequenceIndex: 1)
        let spec2 = cardioDaySpec(name: "Neuer Lauf 2", sequenceIndex: 2)

        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        XCTAssertThrowsError(
            try PlanGeneratorInstantiator.applyCoachCardioAdjustment(
                eligibleDays: [curatedCardioDay, wizardFullBodyDay], newCardioDays: [spec1, spec2], in: context
            )
        )

        XCTAssertEqual(curatedCardioDay.type, .cardio, "nil oldType muss ein echtes No-op sein, kein Reset")
        XCTAssertEqual(wizardFullBodyDay.type, .fullBody, "nil oldType muss ein echtes No-op sein, kein Reset")
    }
}
#endif
