#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
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

    override func tearDownWithError() throws {
        container = nil
        // Nachbesserung (gleiches Muster wie `PlanGeneratorInstantiatorTests`): statischer
        // Test-DI-Seam auf dem Typ, nicht Instanz-State - muss nach jedem Test zurueckgesetzt
        // werden, sonst "leakt" ein hier gesetzter Mock in alle nachfolgenden Tests.
        PlanGeneratorInstantiator.saveOverrideForTesting = nil
    }

    private struct TestSaveError: Error {}

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

    /// Review-Fund (Critical), Wortlaut aktualisiert nach Fix I-1 (Final-Review Fix-Runde 2): die
    /// In-Place-Anpassung muss bei einem INFEASIBLE Verdikt das VORGESCHLAGENE, kleinere
    /// `proposedGoal` anwenden - nicht das urspruengliche, nicht erreichbare `profile.cardioGoal`.
    /// `CoachAdjustmentCardModel.accept` nutzt dafuer bereits `self.proposedGoal ?? profile.cardioGoal`
    /// (Task 7s Fix), und seit Fix I-1 folgt auch `make`s `fingerprint` demselben effektiven Ziel -
    /// ein veralteter Fingerprint ist daher NICHT mehr der Grund, warum `accept(profile:in:using:
    /// activePlan:)` `profile.cardioGoal` vor `make`/`accept` auf `proposedGoal` vorzieht (`profile.
    /// cardioFeasibilityDismissedFingerprint` wuerde auch OHNE das Vorziehen korrekt gesetzt - es
    /// wird direkt aus dem hier bereits bekannten `proposedGoal`/`raceDate`/`weeklyVolume` berechnet,
    /// NICHT aus `make`s Rueckgabe). Der weiterhin gueltige Grund: `make(for: activePlan:)` berechnet
    /// sein EIGENES `verdict`/`proposedGoal` aus dem dann aktuellen `profile.cardioGoal` NEU, mit den
    /// zum `accept`-Zeitpunkt (moeglicherweise seit der Vorschau geaenderten) `raceDate`/
    /// `weeklyVolume` - ohne das Vorziehen koennte diese Neuberechnung ein ANDERES kleineres Ziel
    /// liefern als das hier bereits entschiedene `proposedGoal`. Das Vorziehen macht sie stattdessen
    /// zu einer direkten Machbarkeits-Pruefung GENAU DIESES `proposedGoal`.
    ///
    /// Marathon (Zielvolumen 65 km/Woche) bei 15 km/Woche Basis und nur 7 Wochen bis zum
    /// Renn-Datum ist klar NICHT erreichbar (`weeksNeeded(for: .marathon, startWeeklyVolumeKm: 15)`
    /// == 18) - ebenso wenig Halbmarathon (14) oder 10K (10). Nur 5K (6) geht in 7 Wochen noch auf,
    /// mit grossem Sicherheitsabstand in beide Richtungen gegen Kalender-Rundungsunschaerfen bei
    /// `weeksAvailable` (+/-1-2 Wochen aendern an keiner dieser vier Vergleiche etwas) - `.fiveK`
    /// ist daher der einzig moegliche `suggestedGoal`.
    func testAcceptAppliesTheSuggestedGoalNotTheStaleInfeasibleGoalWhenAdjustingInPlace() throws {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .marathon
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 7)
        profile.weeklyBaseVolumeKm = 15
        context.insert(profile)
        let plan = makeEligiblePlan()

        guard let model = CardioFeasibilityCardModel.make(for: profile) else {
            return XCTFail("expected model")
        }
        XCTAssertFalse(model.verdict.feasible, "Testaufbau: Marathon in 7 Wochen bei 15 km Basis muss NICHT erreichbar sein")
        guard let proposedGoal = model.proposedGoal else {
            return XCTFail("Testaufbau: es sollte ein kleineres, erreichbares Ziel vorgeschlagen werden")
        }
        XCTAssertEqual(proposedGoal, .fiveK, "Testaufbau: bei diesen Werten ist 5K das einzig erreichbare kleinere Ziel")
        XCTAssertNotEqual(proposedGoal, profile.cardioGoal, "Testaufbau: der Vorschlag muss vom urspruenglichen Ziel abweichen")

        let operation = PlanCreationOperation()
        let outcome = model.accept(profile: profile, in: context, using: operation, activePlan: plan)

        guard case .success(let returnedPlan) = outcome else {
            return XCTFail("expected .success, got \(String(describing: outcome))")
        }
        XCTAssertEqual(returnedPlan.persistentModelID, plan.persistentModelID)

        // (b) profile.cardioGoal muss auf das vorgeschlagene Ziel mitgezogen worden sein - NICHT
        // das alte, nicht erreichbare Ziel.
        XCTAssertEqual(profile.cardioGoal, proposedGoal)

        // (a) der angepasste Cardio-Tag muss den Spezifikationen fuer `proposedGoal` entsprechen -
        // reuse derselben, deterministischen (kein Shuffle/Zufall im `shuffle: false`-Default-Pfad
        // von `PlanGenerator.generate`) Quelle, die `CoachAdjustmentCardModel.accept` selbst intern
        // aufruft, statt eines zweiten, unabhaengigen Soll-Wert-Rechners.
        let expectedSpecs = CoachAdjustmentCardModel.cardioOnlyDaySpecs(
            for: proposedGoal,
            cardioRunProfile: CardioRunProfile(
                goal: proposedGoal,
                current5kReferenceSeconds: profile.current5kReferenceSeconds,
                weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm
            )
        )
        XCTAssertFalse(expectedSpecs.isEmpty, "Testaufbau: es sollte Cardio-Tagesinhalte fuer das vorgeschlagene Ziel geben")
        XCTAssertEqual(
            plan.days[0].activeExercises.map(\.name), expectedSpecs[0].exercises.map(\.name),
            "der angepasste Tag muss den Inhalt fuer das VORGESCHLAGENE Ziel tragen"
        )

        // (c) der Fingerprint muss aus `proposedGoal` berechnet sein, nicht aus dem alten Ziel -
        // sonst erschiene dieselbe Karte beim naechsten Aufruf sofort wieder.
        let expectedFingerprint = CardioFeasibilityCalculator.suppressionFingerprint(
            goal: proposedGoal, raceDate: profile.cardioRaceDate!, weeklyBaseVolumeKm: profile.weeklyBaseVolumeKm!
        )
        XCTAssertEqual(profile.cardioFeasibilityDismissedFingerprint, expectedFingerprint)
    }

    /// Review-Fund (Important): schlaegt `adjustmentModel.accept(...)` fehl, rollt
    /// `PlanGeneratorInstantiator.revert` die Plan-Mutation selbst bereits vollstaendig zurueck
    /// (siehe `applyCoachCardioAdjustment`-Doku) - `profile.cardioGoal` wurde aber AUSSERHALB
    /// dieses rollback-faehigen Bereichs direkt zugewiesen und muss daher explizit symmetrisch
    /// zurueckgesetzt werden, sonst bliebe das Vorschlags-Ziel haengen, obwohl nichts uebernommen
    /// wurde. Nutzt denselben `PlanGeneratorInstantiator.saveOverrideForTesting`-DI-Seam wie
    /// `PlanGeneratorInstantiatorTests.testBuildRollsBackNewPlanAndRestoresPreviousActivePlanWhenSaveFails`,
    /// um den echten, in `applyCoachCardioAdjustment` aufgerufenen `save(context)` deterministisch
    /// scheitern zu lassen, statt den SwiftData-Store selbst zu beschaedigen.
    func testAcceptRestoresTheOriginalCardioGoalWhenTheInPlaceAdjustmentFails() throws {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .marathon
        )
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 7)
        profile.weeklyBaseVolumeKm = 15
        context.insert(profile)
        let plan = makeEligiblePlan()

        guard let model = CardioFeasibilityCardModel.make(for: profile) else {
            return XCTFail("expected model")
        }
        guard let proposedGoal = model.proposedGoal else {
            return XCTFail("Testaufbau: es sollte ein kleineres, erreichbares Ziel vorgeschlagen werden")
        }
        // Testaufbau identisch zu `testAcceptAppliesTheSuggestedGoalNotTheStaleInfeasibleGoalWhenAdjustingInPlace`
        // - entscheidend ist hier nur, dass `proposedGoal` vom urspruenglichen Ziel ABWEICHT, sonst
        // waere eine (ausbleibende) Wiederherstellung von einem Erfolg nicht unterscheidbar.
        XCTAssertNotEqual(proposedGoal, profile.cardioGoal, "Testaufbau: der Vorschlag muss vom urspruenglichen Ziel abweichen")

        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        let operation = PlanCreationOperation()
        let outcome = model.accept(profile: profile, in: context, using: operation, activePlan: plan)

        guard case .failedBeforeCommit = outcome else {
            return XCTFail("expected .failedBeforeCommit, got \(String(describing: outcome))")
        }
        XCTAssertEqual(
            profile.cardioGoal, .marathon,
            "ein gescheiterter Versuch darf profile.cardioGoal nicht auf das Vorschlags-Ziel haengen lassen"
        )
        XCTAssertNil(profile.cardioPlanAdjustmentFingerprint, "nichts wurde uebernommen - kein Fingerprint darf gesetzt sein")
        XCTAssertNil(profile.cardioFeasibilityDismissedFingerprint, "nichts wurde uebernommen - kein Fingerprint darf gesetzt sein")
    }
}
#endif
