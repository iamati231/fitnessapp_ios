#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppUI
@testable import FitnessAppData
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

    override func tearDownWithError() throws {
        container = nil
        // Gleiches Muster wie `CardioFeasibilityCardModelTests`: statischer
        // Test-DI-Seam auf dem Typ, nicht Instanz-State - muss nach jedem
        // Test zurueckgesetzt werden, sonst "leakt" ein hier gesetzter Mock
        // in alle nachfolgenden Tests.
        PlanGeneratorInstantiator.saveOverrideForTesting = nil
    }

    private struct TestSaveError: Error {}

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

    // MARK: - Task 7 (Decision 3 Teil 2): accept() wendet das vorgeschlagene, nicht das stale Ziel an

    /// Mirror von `CardioFeasibilityCardModelTests.
    /// testAcceptAppliesTheSuggestedGoalNotTheStaleInfeasibleGoalWhenAdjustingInPlace`
    /// fuer den In-Place-Merge-Pfad: Marathon in 7 Wochen bei 15 km/Woche
    /// Basis ist nicht erreichbar, 5K ist das einzige kleinere erreichbare
    /// Ziel (`testProposedGoalEqualsSuggestedGoalWhenInfeasible` oben prueft
    /// bereits `model.proposedGoal` selbst) - `accept()` muss diesen
    /// Vorschlag tatsaechlich auf den Plan anwenden UND `profile.cardioGoal`
    /// damit mitziehen, nicht am stale `.marathon` haengen bleiben.
    func testAcceptAppliesTheSuggestedGoalNotTheStaleInfeasibleGoalWhenAdjustingInPlace() throws {
        let (profile, plan) = makeProfileAndPlan()
        profile.cardioGoal = .marathon
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 7)
        profile.weeklyBaseVolumeKm = 15
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        XCTAssertEqual(model.verdict?.feasible, false, "Testaufbau: Marathon in 7 Wochen bei 15 km Basis muss NICHT erreichbar sein")
        guard let proposedGoal = model.proposedGoal else {
            return XCTFail("Testaufbau: es sollte ein kleineres, erreichbares Ziel vorgeschlagen werden")
        }
        XCTAssertNotEqual(proposedGoal, profile.cardioGoal, "Testaufbau: der Vorschlag muss vom urspruenglichen Ziel abweichen")

        let count = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertGreaterThan(count, 0)

        // (b) profile.cardioGoal muss auf das vorgeschlagene Ziel mitgezogen worden sein - NICHT
        // das alte, nicht erreichbare Ziel.
        XCTAssertEqual(profile.cardioGoal, proposedGoal)

        // (a) der angepasste Cardio-Tag muss den Spezifikationen fuer `proposedGoal` entsprechen.
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
    }

    /// Mirror von `CardioFeasibilityCardModelTests.
    /// testAcceptRestoresTheOriginalCardioGoalWhenTheInPlaceAdjustmentFails`
    /// fuer den In-Place-Merge-Pfad: erzwingt ueber denselben
    /// `PlanGeneratorInstantiator.saveOverrideForTesting`-DI-Seam einen Fehlschlag
    /// im echten `save()` innerhalb `applyCoachCardioAdjustment` - `profile.cardioGoal`
    /// darf danach nicht auf das Vorschlags-Ziel haengen bleiben, obwohl nichts
    /// uebernommen wurde.
    func testAcceptRestoresTheOriginalCardioGoalWhenTheInPlaceAdjustmentFails() throws {
        let (profile, plan) = makeProfileAndPlan()
        profile.cardioGoal = .marathon
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 7)
        profile.weeklyBaseVolumeKm = 15
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        guard let proposedGoal = model.proposedGoal else {
            return XCTFail("Testaufbau: es sollte ein kleineres, erreichbares Ziel vorgeschlagen werden")
        }
        XCTAssertNotEqual(proposedGoal, profile.cardioGoal, "Testaufbau: der Vorschlag muss vom urspruenglichen Ziel abweichen")

        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        XCTAssertThrowsError(try model.accept(plan: plan, profile: profile, in: context))

        XCTAssertEqual(
            profile.cardioGoal, .marathon,
            "ein gescheiterter Versuch darf profile.cardioGoal nicht auf das Vorschlags-Ziel haengen lassen"
        )
        XCTAssertNil(profile.cardioPlanAdjustmentFingerprint, "nichts wurde uebernommen - kein Fingerprint darf gesetzt sein")
    }

    // MARK: - Fix I-1 (Final-Review, Round 2): fingerprint folgt proposedGoal, nicht dem stale Ziel

    /// Reproduziert exakt den Reappearing-Card-Bug: eine FRISCHE `make()`-
    /// Auswertung nach erfolgreichem `accept()` im infeasiblen Szenario
    /// (identisches Marathon/7-Wochen/15km-Fixture wie oben) muss
    /// `isAlreadyApplied == true` liefern. Vor dem Fix berechnete `make()`
    /// den Fingerprint aus dem inzwischen aktualisierten `profile.cardioGoal`
    /// (jetzt `.fiveK`), der nicht mehr zum gespeicherten, aus dem ALTEN
    /// `.marathon`-Ziel berechneten Fingerprint passte - die Karte erschien
    /// faelschlich wieder als ausstehend, und ein zweiter `accept()`-Aufruf
    /// haette dieselbe Anpassung doppelt angewendet.
    func testFreshlyMadeModelAfterAcceptReportsAlreadyAppliedWhenGoalWasDowngraded() throws {
        let (profile, plan) = makeProfileAndPlan()
        profile.cardioGoal = .marathon
        profile.cardioRaceDate = Date().addingTimeInterval(60 * 60 * 24 * 7 * 7)
        profile.weeklyBaseVolumeKm = 15
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        XCTAssertEqual(model.verdict?.feasible, false, "Testaufbau: Marathon in 7 Wochen bei 15 km Basis muss NICHT erreichbar sein")

        let count = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertGreaterThan(count, 0)

        guard let freshModel = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        XCTAssertTrue(
            freshModel.isAlreadyApplied,
            "eine frische make()-Auswertung nach erfolgreichem accept() muss die Anpassung als bereits uebernommen erkennen, obwohl sich profile.cardioGoal zwischenzeitlich auf das vorgeschlagene Ziel geaendert hat"
        )

        let secondCount = try freshModel.accept(plan: plan, profile: profile, in: context)
        XCTAssertEqual(secondCount, 0, "ein zweiter accept()-Aufruf nach bereits erfolgter Uebernahme muss ein No-Op sein, keine doppelte Anwendung")
    }

    // MARK: - Task 7: CoachAdjustmentPreviewView nutzt model.proposedGoal fuer die Tagesgenerierung

    /// Source-introspection (kein SwiftUI-Render-Harness in diesem Repo),
    /// gleiches Muster wie `CardioFeasibilityDayRowPaceTests`: stellt sicher,
    /// dass die Vorschau dasselbe Ziel anzeigt, das `accept()` tatsaechlich
    /// anwendet (`model.proposedGoal`), statt des rohen, moeglicherweise
    /// nicht erreichbaren `profile.cardioGoal`.
    func testCoachAdjustmentPreviewViewUsesModelProposedGoalForDayGeneration() throws {
        let source = try contents(of: "Cardio/CoachAdjustmentPreviewView.swift")
        guard let funcRange = source.range(of: "private func newCardioDays(for model: CoachAdjustmentCardModel) -> [DaySpec] {") else {
            XCTFail("newCardioDays(for:) function not found"); return
        }
        let block = try XCTUnwrap(Self.matchingBraceBlock(in: source, afterOpenBrace: funcRange.upperBound))
        XCTAssertTrue(
            block.contains("model.proposedGoal ?? profile.cardioGoal"),
            "must use the model's proposed goal, falling back to the raw profile goal only when there is no suggestion"
        )

        XCTAssertTrue(
            source.contains("newCardioDays(for: model)"),
            "the call site inside beforeAfterSection must pass the model through, not read the stale standalone property"
        )
    }

    // MARK: - Task 10 (Protection regression suite): insertion-path specific coverage
    //
    // `testAcceptTwiceOnSameModelInstanceIsIdempotent` and
    // `testAcceptRestoresTheOriginalCardioGoalWhenTheInPlaceAdjustmentFails`
    // above both use `makeProfileAndPlan()`, whose plan already has one
    // eligible cardio day - they only ever exercise the REPLACE branch
    // (`applyCoachCardioAdjustment`) inside `accept()`. Neither proves the
    // same two guarantees hold on the INSERTION branch
    // (`insertCoachCardioDays`, Task 6/7). These two tests close that gap,
    // reusing the identical `saveOverrideForTesting` DI seam
    // `CoachCardioInsertionTests.swift` already established for the
    // insertion mechanics themselves.

    /// Zero-cardio-day plan with exactly as many `isAutoFilledPlaceholder`
    /// rest days as `.fiveK` needs run-days for (`CardioFeasibilityCalculator.
    /// planGeneratorInput`: `.fiveK` -> `runDays: 2`, `strengthDays: 2` -
    /// `cardioOnlyDaySpecs` filters the strength days out, so exactly 2
    /// cardio-only specs come back) - `accept()` must therefore take the
    /// `eligibleDays.isEmpty` -> `insertCoachCardioDays` branch, not the
    /// replace branch. No race date/weekly volume set (same reasoning as
    /// `testProposedGoalFallsBackToCurrentGoalAndModelStaysNonNilWithoutRaceDateOrVolume`
    /// above): keeps `verdict == nil`/`proposedGoal == profile.cardioGoal`,
    /// so the only moving part under test is the insertion branch itself.
    private func makeProfileAndZeroCardioPlanWithTwoInsertableRestDays() -> (UserBodyProfile, TrainingPlan, [TrainingDay]) {
        let profile = UserBodyProfile(
            birthDate: Date(timeIntervalSince1970: 0), heightCm: 180, profile: .male,
            cardioCoachingEnabled: true, cardioGoal: .fiveK
        )
        context.insert(profile)

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)

        let restDay1 = TrainingDay(name: "Ruhetag", weekday: 2, type: .rest, plan: plan, isAutoFilledPlaceholder: true)
        let restDay2 = TrainingDay(name: "Ruhetag", weekday: 4, type: .rest, plan: plan, isAutoFilledPlaceholder: true)
        context.insert(restDay1)
        context.insert(restDay2)
        plan.days.append(restDay1)
        plan.days.append(restDay2)

        try? context.save()
        return (profile, plan, [restDay1, restDay2])
    }

    /// Review-Punkt 7 / historisches Round-2-Bugmuster, jetzt fuer den
    /// Einfuege-Pfad: ein Doppeltap ruft `accept()` zweimal auf DERSELBEN
    /// Modell-Instanz auf. Der Schutz in `accept()` (`guard profile.
    /// cardioPlanAdjustmentFingerprint != fingerprint else { return 0 }`,
    /// siehe dortige Doku "Bugfix (Leitplanke 3, ...)") liest `profile` LIVE
    /// und sitzt VOR der Verzweigung in Ersetzungs-/Einfuege-Pfad - dieser
    /// Test beweist, dass das tatsaechlich auch fuer den Einfuege-Pfad gilt,
    /// nicht nur behauptet wird.
    func testAcceptTwiceOnSameModelInstanceIsIdempotentForTheInsertionPath() throws {
        let (profile, plan, restDays) = makeProfileAndZeroCardioPlanWithTwoInsertableRestDays()
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }

        let firstCount = try model.accept(plan: plan, profile: profile, in: context)
        XCTAssertEqual(firstCount, 2, "both insertable rest days must have been converted")
        XCTAssertTrue(restDays.allSatisfy { $0.type == .cardio }, "both selected rest days must now be cardio days")
        let dayIDsAfterFirst = Set(plan.days.map(\.persistentModelID))
        let exerciseCountsAfterFirst = restDays.map(\.activeExercises.count)
        XCTAssertEqual(profile.cardioPlanAdjustmentFingerprint, model.fingerprint)

        let secondCount = try model.accept(plan: plan, profile: profile, in: context)

        XCTAssertEqual(secondCount, 0, "zweiter Aufruf (Doppeltap) muss auch auf dem Einfuege-Pfad ein No-Op sein")
        XCTAssertEqual(plan.days.count, 2, "kein zusaetzlicher Tag darf eingefuegt worden sein")
        XCTAssertEqual(Set(plan.days.map(\.persistentModelID)), dayIDsAfterFirst)
        XCTAssertEqual(restDays.map(\.activeExercises.count), exerciseCountsAfterFirst, "keine zusaetzlichen Uebungen")
    }

    /// Integrations-Version von `CoachCardioInsertionTests.
    /// test_insertCoachCardioDays_revertOnFailure_restoresDayTypeToRest`,
    /// hier durch `CoachAdjustmentCardModel.accept` statt direkt durch
    /// `PlanGeneratorInstantiator.insertCoachCardioDays` getrieben - beweist,
    /// dass der komplette Aufrufpfad (inklusive `accept()`s eigener
    /// Nachbereitung) bei einem gescheiterten Save weder einen Tag halb
    /// umgewandelt laesst noch `cardioPlanAdjustmentFingerprint`/
    /// `cardioGoal` faelschlich setzt.
    func testInsertionAcceptSaveFailureLeavesNoPartialDaysAndNoFingerprint() throws {
        let (profile, plan, restDays) = makeProfileAndZeroCardioPlanWithTwoInsertableRestDays()
        guard let model = CoachAdjustmentCardModel.make(for: profile, activePlan: plan) else {
            return XCTFail("expected model")
        }
        let originalGoal = profile.cardioGoal

        PlanGeneratorInstantiator.saveOverrideForTesting = { _ in throw TestSaveError() }

        XCTAssertThrowsError(try model.accept(plan: plan, profile: profile, in: context))

        for day in restDays {
            XCTAssertEqual(day.type, .rest, "oldType muss zurueckgeschrieben werden")
            XCTAssertEqual(day.name, "Ruhetag")
            XCTAssertNil(day.customName)
            XCTAssertTrue(day.activeExercises.isEmpty, "eingefuegte Uebungen muessen wieder geloescht sein")
            XCTAssertNil(day.generationFingerprint)
            XCTAssertTrue(day.isAutoFilledPlaceholder, "der Herkunfts-Stempel bleibt unveraendert stehen")
        }
        XCTAssertNil(profile.cardioPlanAdjustmentFingerprint, "nichts wurde uebernommen - kein Fingerprint darf gesetzt sein")
        XCTAssertEqual(profile.cardioGoal, originalGoal, "ein gescheiterter Versuch darf profile.cardioGoal nicht anfassen")
    }
}
#endif
