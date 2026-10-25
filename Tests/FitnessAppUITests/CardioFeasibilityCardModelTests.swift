#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
import FitnessAppData
import FitnessAppCore

/// Task 7 (Laufcoaching-Plan-Integration): `CardioFeasibilityCardModel.accept()` erzeugte vorher
/// IMMER einen neuen, separaten `TrainingPlan` (`generationSource == .cardioCoach`) - wiederholte
/// Cardio-Zielaenderungen bei bereits bestehendem, aktivem Plan produzierten so bei jedem Tap
/// einen weiteren Plan. Diese Tests decken die neue, zusaetzliche `activePlan`-Weiche ab: existiert
/// ein aktiver Plan MIT anfassbarem Cardio-Tag, wird GENAU DIESER ueber den bereits in Paket 1
/// gebauten/getesteten `CoachAdjustmentCardModel`/`RunCoachPlanAdjustment`-Pfad angepasst, statt
/// einen zweiten Plan anzulegen - der bisherige "neuen Plan erstellen"-Pfad bleibt in jedem anderen
/// Fall (kein `activePlan`, kein anfassbarer Cardio-Tag) unveraendert der Fallback.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CardioFeasibilityCardModelTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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

    /// Ein aktiver Plan mit genau einem anfassbaren Cardio-Tag (Fingerprint passend gesetzt, keine
    /// Sessions) - identisches Muster wie `CoachAdjustmentCardModelTests.makeProfileAndPlan`.
    @discardableResult
    private func makeEligiblePlan() -> TrainingPlan {
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        let cardioDay = TrainingDay(name: "Run", weekday: 2, type: .fullBody, plan: plan)
        context.insert(cardioDay)
        let run = Exercise(name: "Easy Run", isCardio: true, day: cardioDay)
        context.insert(run)
        cardioDay.exercises.append(run)
        cardioDay.generationFingerprint = cardioDay.currentContentFingerprint
        plan.days.append(cardioDay)
        try? context.save()
        return plan
    }

    /// Ein aktiver Plan OHNE jeden anfassbaren Cardio-Tag - nur ein Kraft-Tag, keine
    /// Cardio-Uebung - `RunCoachPlanAdjustment.analyze(plan:).cardioAvailability` liefert dafuer
    /// `.noEligibleCardioDay`.
    @discardableResult
    private func makePlanWithNoEligibleCardioDay() -> TrainingPlan {
        let plan = TrainingPlan(name: "Plan ohne Lauf-Tag", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        let strengthDay = TrainingDay(name: "Oberkoerper", weekday: 2, type: .fullBody, plan: plan)
        context.insert(strengthDay)
        let lift = Exercise(name: "Bankdruecken", isCardio: false, day: strengthDay)
        context.insert(lift)
        strengthDay.exercises.append(lift)
        strengthDay.generationFingerprint = strengthDay.currentContentFingerprint
        plan.days.append(strengthDay)
        try? context.save()
        return plan
    }

    func testAcceptAdjustsTheExistingPlanInPlaceWhenAnEligibleCardioDayExists() throws {
        let profile = makeProfile()
        let plan = makeEligiblePlan()
        guard let model = CardioFeasibilityCardModel.make(for: profile) else {
            return XCTFail("expected model")
        }

        let plansBefore = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        let dayIDBefore = plan.days[0].persistentModelID
        let oldExerciseID = plan.days[0].activeExercises[0].persistentModelID

        let operation = PlanCreationOperation()
        let outcome = model.accept(profile: profile, in: context, using: operation, activePlan: plan)

        guard case .success(let returnedPlan) = outcome else {
            return XCTFail("expected .success, got \(String(describing: outcome))")
        }
        XCTAssertEqual(returnedPlan.persistentModelID, plan.persistentModelID, "muss DENSELBEN Plan liefern, keinen neuen")

        let plansAfter = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        XCTAssertEqual(plansAfter, plansBefore, "kein zusaetzlicher Plan darf entstehen")

        XCTAssertEqual(plan.days.count, 1, "kein zusaetzlicher Tag")
        XCTAssertEqual(plan.days[0].persistentModelID, dayIDBefore, "derselbe Tag wird angepasst, nicht ersetzt")
        XCTAssertFalse(
            plan.days[0].activeExercises.map(\.persistentModelID).contains(oldExerciseID),
            "die alte Uebung muss ersetzt (archiviert) worden sein - Taginhalt hat sich geaendert"
        )

        let expectedFingerprint = CardioFeasibilityCalculator.suppressionFingerprint(
            goal: profile.cardioGoal, raceDate: profile.cardioRaceDate!, weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm!
        )
        XCTAssertEqual(profile.cardioPlanAdjustmentFingerprint, expectedFingerprint)
    }

    func testAcceptStillCreatesANewPlanWhenNoActivePlanExists() throws {
        let profile = makeProfile()
        guard let model = CardioFeasibilityCardModel.make(for: profile) else {
            return XCTFail("expected model")
        }

        let plansBefore = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        let operation = PlanCreationOperation()
        let outcome = model.accept(profile: profile, in: context, using: operation, activePlan: nil)

        guard case .success(let newPlan) = outcome else {
            return XCTFail("expected .success, got \(String(describing: outcome))")
        }
        XCTAssertEqual(newPlan.generationSource, .cardioCoach)

        let plansAfter = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        XCTAssertEqual(plansAfter, plansBefore + 1, "ohne aktiven Plan muss weiterhin ein neuer Plan entstehen")
    }

    func testAcceptStillCreatesANewPlanWhenTheActivePlanHasNoEligibleCardioDay() throws {
        let profile = makeProfile()
        let plan = makePlanWithNoEligibleCardioDay()
        guard let model = CardioFeasibilityCardModel.make(for: profile) else {
            return XCTFail("expected model")
        }

        let plansBefore = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        let dayCountBefore = plan.days.count

        let operation = PlanCreationOperation()
        let outcome = model.accept(profile: profile, in: context, using: operation, activePlan: plan)

        guard case .success(let newPlan) = outcome else {
            return XCTFail("expected .success, got \(String(describing: outcome))")
        }
        XCTAssertNotEqual(newPlan.persistentModelID, plan.persistentModelID, "muss einen NEUEN, separaten Plan liefern")
        XCTAssertEqual(newPlan.generationSource, .cardioCoach)

        let plansAfter = try context.fetch(FetchDescriptor<TrainingPlan>()).count
        XCTAssertEqual(plansAfter, plansBefore + 1, "ohne anfassbaren Cardio-Tag muss weiterhin ein neuer Plan entstehen")
        XCTAssertEqual(plan.days.count, dayCountBefore, "der bestehende, nicht anpassbare Plan darf nicht veraendert werden")
    }
}
#endif
