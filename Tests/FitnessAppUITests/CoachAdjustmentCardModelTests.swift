#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
import FitnessAppData
import FitnessAppCore

/// Paket 1 (Laufcoach-Plananpassung, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// deckt die drei vom Nutzer explizit verlangten Leitplanken ab:
/// Leitplanke 2 (Coach-Praeferenz vs. Plan-Uebernahme getrennt),
/// Leitplanke 3 (Wiederholungssicherheit auf dem Merge-Pfad).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CoachAdjustmentCardModelTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Profil mit erreichbarem Laufziel (10K, 20 Wochen verfuegbar, 20 km/
    /// Woche Basis - `CardioFeasibilityCalculator.weeksNeeded` braucht dafuer
    /// 7 Wochen, also klar feasible) + aktivem Plan mit genau einem
    /// anfassbaren Cardio-Tag (Wizard-typisch: `type: .fullBody`, aber
    /// `Exercise.isCardio == true`, Fingerprint passend gesetzt).
    private func makeProfileAndPlan() -> (UserBodyProfile, TrainingPlan) {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .tenK
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 20)
        profile.weeklyBaseVolumeKm = 20
        context.insert(profile)

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
        return (profile, plan)
    }

    // MARK: - Leitplanke 2: Coach-Präferenz vs. Planübernahme getrennt

    func testAcceptNeverChangesCardioCoachingEnabled() throws {
        let (profile, plan) = makeProfileAndPlan()
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        XCTAssertTrue(profile.cardioCoachingEnabled)
        _ = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertTrue(profile.cardioCoachingEnabled, "accept() darf die Coach-Präferenz nicht anfassen")
    }

    /// "Beibehalten" ist im Modell bewusst KEIN eigener Methodenaufruf -
    /// es bedeutet schlicht: `accept()` wird nicht aufgerufen. Dieser Test
    /// beweist, dass dabei weder die Coach-Präferenz noch der Plan
    /// irgendwie verändert werden.
    func testKeepingAsIsLeavesCoachingPreferenceAndPlanUntouched() {
        let (profile, plan) = makeProfileAndPlan()
        guard CoachAdjustmentCardModel.make(for: profile, activePlan: plan) != nil else {
            return XCTFail("expected model")
        }
        XCTAssertTrue(profile.cardioCoachingEnabled)
        XCTAssertNil(profile.cardioPlanAdjustmentFingerprint)
        XCTAssertEqual(plan.days.count, 1)
        XCTAssertEqual(plan.days[0].activeExercises.count, 1)
    }

    // MARK: - Leitplanke 3: Wiederholungssicherheit auf dem Merge-Pfad

    /// Simuliert einen Doppeltap: zwei `accept`-Aufrufe auf DERSELBEN
    /// Modell-Instanz. Der zweite muss ein vollständiges No-Op sein - kein
    /// zusätzlicher Tag, keine zusätzlichen Übungen.
    func testAcceptTwiceOnSameModelInstanceIsIdempotent() throws {
        let (profile, plan) = makeProfileAndPlan()
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }

        let firstCount = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertGreaterThan(firstCount, 0)
        let dayIDAfterFirst = plan.days[0].persistentModelID
        let exerciseCountAfterFirst = plan.days[0].activeExercises.count
        XCTAssertEqual(profile.cardioPlanAdjustmentFingerprint, model.fingerprint)

        let secondCount = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertEqual(secondCount, 0, "zweiter Aufruf (Doppeltap) muss ein No-Op sein")
        XCTAssertEqual(plan.days.count, 1, "kein zusätzlicher Tag")
        XCTAssertEqual(plan.days[0].persistentModelID, dayIDAfterFirst)
        XCTAssertEqual(plan.days[0].activeExercises.count, exerciseCountAfterFirst, "keine zusätzlichen Übungen")
    }

    /// Ein frisch über `make(for:activePlan:)` berechnetes, NEUES
    /// Modell für dieselbe Kombination (z. B. weil die Karte nach dem
    /// ersten Übernehmen erneut gerendert wird) erkennt die bereits
    /// erfolgte Übernahme ebenfalls - `isAlreadyApplied` liest
    /// `profile.cardioPlanAdjustmentFingerprint` live, kein veralteter
    /// Snapshot.
    func testFreshlyMadeModelAfterAcceptReportsAlreadyApplied() throws {
        let (profile, plan) = makeProfileAndPlan()
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        _ = try model.accept(plan: plan, profile: profile, in: context)

        guard let secondModel = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        XCTAssertTrue(secondModel.isAlreadyApplied)
        let count = try secondModel.accept(plan: plan, profile: profile, in: context)
        XCTAssertEqual(count, 0)
    }

    // MARK: - proposedGoal (Task 6, Decision 3 Teil 1: Machbarkeits-Check einfalten)

    /// (a) Feasibler Verdikt (10K, 20 Wochen verfuegbar, 20 km/Woche Basis,
    /// siehe `makeProfileAndPlan`) -> `proposedGoal` bleibt das vom Nutzer
    /// gepflegte `profile.cardioGoal`, kein Downgrade noetig.
    func testProposedGoalEqualsCurrentGoalWhenFeasible() {
        let (profile, plan) = makeProfileAndPlan()
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        XCTAssertEqual(model.proposedGoal, profile.cardioGoal)
    }

    /// (b) Infeasibler Verdikt mit kleinerem erreichbarem Ziel (Marathon in 7
    /// Wochen bei 15 km/Woche Basis -> 5K bleibt als einziges erreichbares
    /// Ziel, identisch zum Testaufbau in `CardioFeasibilityCardModelTests`)
    /// -> `proposedGoal` MUSS das vorgeschlagene kleinere Ziel sein, NICHT
    /// das weiterhin unveraenderte `profile.cardioGoal`.
    func testProposedGoalEqualsSuggestedGoalWhenInfeasible() {
        let (profile, plan) = makeProfileAndPlan()
        profile.cardioGoal = .marathon
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 7)
        profile.weeklyBaseVolumeKm = 15
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        XCTAssertEqual(model.verdict?.feasible, false, "Testaufbau: Marathon in 7 Wochen bei 15 km Basis muss NICHT erreichbar sein")
        XCTAssertEqual(model.proposedGoal, .fiveK, "proposedGoal muss das vorgeschlagene kleinere Ziel sein, nicht das unveraenderte profile.cardioGoal")
    }

    /// (c) Kein Renn-Datum/Wochenvolumen gepflegt -> kein Machbarkeits-Check
    /// moeglich, `CoachAdjustmentCardModel.make` darf deswegen NICHT `nil`
    /// liefern (ein aktiver Plan mit anfassbarem Cardio-Tag reicht fuer die
    /// reine "aktuelles Ziel uebernehmen"-Anpassung) - `proposedGoal` faellt
    /// in diesem Fall auf das unveraenderte `profile.cardioGoal` zurueck.
    func testProposedGoalFallsBackToCurrentGoalAndModelStaysNonNilWithoutRaceDateOrVolume() {
        let (profile, plan) = makeProfileAndPlan()
        profile.cardioRaceDate = nil
        profile.weeklyBaseVolumeKm = nil
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("make() must still return non-nil without race date/weekly volume (no feasibility opinion possible, not a reason to suppress the plain adjustment)")
        }
        XCTAssertNil(model.verdict, "ohne Renn-Datum/Wochenvolumen kann kein Verdikt berechnet werden")
        XCTAssertEqual(model.proposedGoal, profile.cardioGoal)
    }

    // MARK: - cardioRunProfile (Task 9 Nachbesserung, Review-Fund)

    /// Ohne diesen Parameter blieb `targetPaceMinutesPerKm` auf jedem ueber
    /// diesen Merge-Pfad erzeugten Lauf-Tag immer `nil`, weil
    /// `cardioOnlyDaySpecs` `CardioFeasibilityCalculator.planGeneratorInput`
    /// ohne Baseline aufrief.
    func testCardioOnlyDaySpecsThreadsCardioRunProfileIntoRunExercises() {
        let profile = CardioRunProfile(goal: .tenK, current5kReferenceSeconds: 1500, weeklyBaseVolumeKm: 20)
        let specs = CoachAdjustmentCardModel.cardioOnlyDaySpecs(for: .tenK, cardioRunProfile: profile)
        let easyOrTempoExercises = specs.flatMap(\.exercises).filter { $0.isCardio && $0.targetDurationMinutes != nil }
        XCTAssertFalse(easyOrTempoExercises.isEmpty, "expected at least one duration-based (easy/tempo) run exercise")
        XCTAssertTrue(easyOrTempoExercises.allSatisfy { $0.targetPaceMinutesPerKm != nil }, "every easy/tempo run exercise must carry the baseline pace")
    }

    /// Review Focus 1 (dieser Plan): omitting the new defaulted trailing
    /// parameter must reproduce the previous (always-nil-pace) output
    /// exactly - no accidental behavior change for existing callers.
    func testOmittingCardioRunProfileReproducesThePreviousOutputExactly() {
        for goal in CardioGoal.allCases {
            let withExplicitNil = CoachAdjustmentCardModel.cardioOnlyDaySpecs(for: goal, cardioRunProfile: nil)
            let withOmittedParameter = CoachAdjustmentCardModel.cardioOnlyDaySpecs(for: goal)
            XCTAssertEqual(withExplicitNil, withOmittedParameter)
            XCTAssertTrue(withOmittedParameter.flatMap(\.exercises).allSatisfy { $0.targetPaceMinutesPerKm == nil })
        }
    }
}
#endif
