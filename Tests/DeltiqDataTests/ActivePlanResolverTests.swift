#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Task 9: Integrationstests fuer `ActivePlanResolver` gegen echte
/// `TrainingPlan`-SwiftData-Instanzen (in-memory `ModelContainer`, gleiches
/// Muster wie `ExperienceTrackBackfillTests`). Besonderer Fokus auf
/// Determinismus: dieselben Plaene in mehreren Array-Reihenfolgen muessen
/// IMMER dasselbe Ergebnis liefern — genau das, was `activePlans.first`
/// nicht garantierte.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ActivePlanResolverTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    private var context: ModelContext { container.mainContext }

    @discardableResult
    private func makePlan(
        name: String,
        generationSource: GenerationSource = .manual,
        activatedAt: Date? = nil
    ) -> TrainingPlan {
        let plan = TrainingPlan(
            name: name,
            isActive: true,
            generationSource: generationSource,
            activatedAt: activatedAt
        )
        // `TrainingPlan.init`'s `activatedAt ?? (isActive ? Date() : nil)`
        // cannot distinguish "explicit nil" from "parameter omitted" - for
        // an active plan it silently stamps `Date()` either way (a separate,
        // pre-existing data-model quirk out of this plan's scope). Force
        // the exact intended value here so these fixtures actually produce
        // the states their names claim, regardless of that quirk.
        plan.activatedAt = activatedAt
        context.insert(plan)
        return plan
    }

    // MARK: - Tests

    func test_cardioRelevantPlan_withOnePlan_returnsIt() throws {
        let plan = makePlan(name: "Solo", generationSource: .manual)
        try context.save()

        XCTAssertEqual(
            ActivePlanResolver.cardioRelevantPlan(among: [plan])?.persistentModelID,
            plan.persistentModelID
        )
    }

    func test_cardioRelevantPlan_withOneCardioCoachPlanAmongOthers_returnsIt() throws {
        let manualPlan = makePlan(name: "Manual", generationSource: .manual)
        let cardioPlan = makePlan(name: "Cardio", generationSource: .cardioCoach)
        try context.save()

        XCTAssertEqual(
            ActivePlanResolver.cardioRelevantPlan(among: [manualPlan, cardioPlan])?.persistentModelID,
            cardioPlan.persistentModelID
        )
        // Reihenfolge darf keine Rolle spielen.
        XCTAssertEqual(
            ActivePlanResolver.cardioRelevantPlan(among: [cardioPlan, manualPlan])?.persistentModelID,
            cardioPlan.persistentModelID
        )
    }

    func test_cardioRelevantPlan_withMultipleNonCardioPlansAndNoCardioCoachPlan_returnsNil() throws {
        let planA = makePlan(name: "A", generationSource: .manual)
        let planB = makePlan(name: "B", generationSource: .planBuilder)
        try context.save()

        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: [planA, planB]))
        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: [planB, planA]))
    }

    func test_cardioRelevantPlan_withTwoCardioCoachPlans_returnsMostRecentlyActivated() throws {
        let older = makePlan(
            name: "Older",
            generationSource: .cardioCoach,
            activatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = makePlan(
            name: "Newer",
            generationSource: .cardioCoach,
            activatedAt: Date(timeIntervalSince1970: 2_000)
        )
        try context.save()

        // Determinismus: dieselben zwei Plaene in mehreren Reihenfolgen,
        // immer dasselbe Ergebnis (der spaeter aktivierte).
        XCTAssertEqual(
            ActivePlanResolver.cardioRelevantPlan(among: [older, newer])?.persistentModelID,
            newer.persistentModelID
        )
        XCTAssertEqual(
            ActivePlanResolver.cardioRelevantPlan(among: [newer, older])?.persistentModelID,
            newer.persistentModelID
        )
    }

    func test_cardioRelevantPlan_withTwoCardioCoachPlans_identicalActivatedAt_returnsNil() throws {
        let sharedDate = Date(timeIntervalSince1970: 5_000)
        let planA = makePlan(name: "A", generationSource: .cardioCoach, activatedAt: sharedDate)
        let planB = makePlan(name: "B", generationSource: .cardioCoach, activatedAt: sharedDate)
        try context.save()

        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: [planA, planB]))
        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: [planB, planA]))
    }

    func test_cardioRelevantPlan_withTwoCardioCoachPlans_bothNilActivatedAt_returnsNil() throws {
        let planA = makePlan(name: "A", generationSource: .cardioCoach, activatedAt: nil)
        let planB = makePlan(name: "B", generationSource: .cardioCoach, activatedAt: nil)
        try context.save()

        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: [planA, planB]))
        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: [planB, planA]))
    }

    /// Gemischter Fall, bisher ungetestet: ein Cardio-Coach-Kandidat hat
    /// `activatedAt == nil` ("unbekannt", siehe `TrainingPlan.activatedAt`-
    /// Doku - NIEMALS "nie aktiviert"), der andere ein echtes Datum. `nil`
    /// ist kein Wettbewerber um "spaetestes Datum" (es fliesst erst gar
    /// nicht in `compactMap(\.activatedAt).max()` ein) - der datierte
    /// Kandidat gewinnt daher unbestritten, statt dass der fehlende Wert
    /// einen Gleichstand/ein `nil`-Ergebnis erzwingt.
    func test_cardioRelevantPlan_withTwoCardioCoachPlans_oneNilOneDatedActivatedAt_returnsTheDatedOne() throws {
        let undated = makePlan(name: "Undated", generationSource: .cardioCoach, activatedAt: nil)
        let dated = makePlan(
            name: "Dated",
            generationSource: .cardioCoach,
            activatedAt: Date(timeIntervalSince1970: 3_000)
        )
        try context.save()

        XCTAssertEqual(
            ActivePlanResolver.cardioRelevantPlan(among: [undated, dated])?.persistentModelID,
            dated.persistentModelID
        )
        XCTAssertEqual(
            ActivePlanResolver.cardioRelevantPlan(among: [dated, undated])?.persistentModelID,
            dated.persistentModelID
        )
    }

    // MARK: - Additional edge case: three cardio-coach candidates, tie for latest

    func test_cardioRelevantPlan_withThreeCardioCoachPlans_tiedLatest_returnsNil() throws {
        let sharedLatest = Date(timeIntervalSince1970: 9_000)
        let earliest = makePlan(
            name: "Earliest",
            generationSource: .cardioCoach,
            activatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let tiedA = makePlan(name: "TiedA", generationSource: .cardioCoach, activatedAt: sharedLatest)
        let tiedB = makePlan(name: "TiedB", generationSource: .cardioCoach, activatedAt: sharedLatest)
        try context.save()

        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: [earliest, tiedA, tiedB]))
        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: [tiedB, earliest, tiedA]))
        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: [tiedA, tiedB, earliest]))
    }

    func test_cardioRelevantPlan_withNoActivePlans_returnsNil() {
        XCTAssertNil(ActivePlanResolver.cardioRelevantPlan(among: []))
    }

    // MARK: - planRequiringAdjustment
    //
    // Nachbesserung ("Tatsächlichen Zielwechsel über CardioGoalEditorView
    // absichern"): deckt genau die vom Ticket geforderten fuenf Faelle ab -
    // echte Verhaltenstests ueber die tatsaechliche Entscheidung, nicht nur
    // den nachgelagerten `cardioRelevantPlan`-Aufruf (den decken die Tests
    // oben bereits ab).

    /// 1. Coach bereits aktiv + Ziel unveraendert -> keine unnoetige erneute
    /// Anpassung.
    func test_planRequiringAdjustment_coachAlreadyEnabled_goalUnchanged_returnsNil() throws {
        let plan = makePlan(name: "Active", generationSource: .cardioCoach)
        try context.save()

        XCTAssertNil(ActivePlanResolver.planRequiringAdjustment(
            coachWasEnabled: true, coachWillBeEnabled: true,
            oldGoal: .halfMarathon, newGoal: .halfMarathon, among: [plan]
        ))
    }

    /// 2. Coach bereits aktiv + Ziel geaendert -> erneute Anpassung wird
    /// ausgeloest.
    func test_planRequiringAdjustment_coachAlreadyEnabled_goalChanged_returnsThePlan() throws {
        let plan = makePlan(name: "Active", generationSource: .cardioCoach)
        try context.save()

        XCTAssertEqual(
            ActivePlanResolver.planRequiringAdjustment(
                coachWasEnabled: true, coachWillBeEnabled: true,
                oldGoal: .halfMarathon, newGoal: .marathon, among: [plan]
            )?.persistentModelID,
            plan.persistentModelID
        )
    }

    /// 3. Coach wird erstmals aktiviert -> bisheriges Verhalten bleibt
    /// erhalten, unabhaengig davon ob sich das Ziel dabei "aendert" (beim
    /// ersten Einschalten ist das Ziel-Feld oft unveraendert vom Default).
    func test_planRequiringAdjustment_coachJustActivated_sameGoal_stillReturnsThePlan() throws {
        let plan = makePlan(name: "Active", generationSource: .manual)
        try context.save()

        XCTAssertEqual(
            ActivePlanResolver.planRequiringAdjustment(
                coachWasEnabled: false, coachWillBeEnabled: true,
                oldGoal: .generalFitness, newGoal: .generalFitness, among: [plan]
            )?.persistentModelID,
            plan.persistentModelID
        )
    }

    /// 4. Bereits einmal angepasster Plan + erneute Zieländerung -> erneute
    /// Anpassung wird ausgeloest. Die Funktion haengt bewusst NICHT von
    /// `UserBodyProfile.cardioPlanAdjustmentFingerprint` ab (das bleibt
    /// `CoachAdjustmentCardModel.make`s `isAlreadyApplied` vorbehalten) - ein
    /// bereits durch Coaching angepasster Plan (hier durch
    /// `generationSource == .cardioCoach` reprasentiert) wird bei einem
    /// weiteren Zielwechsel genauso zuverlaessig zurueckgegeben wie ein
    /// frischer.
    func test_planRequiringAdjustment_alreadyAdjustedPlan_repeatedGoalChange_returnsThePlanAgain() throws {
        let alreadyAdjustedPlan = makePlan(name: "AlreadyAdjusted", generationSource: .cardioCoach)
        try context.save()

        XCTAssertEqual(
            ActivePlanResolver.planRequiringAdjustment(
                coachWasEnabled: true, coachWillBeEnabled: true,
                oldGoal: .marathon, newGoal: .halfMarathon, among: [alreadyAdjustedPlan]
            )?.persistentModelID,
            alreadyAdjustedPlan.persistentModelID,
            "ein bereits angepasster Plan muss bei einer weiteren Zieländerung erneut zurueckgegeben werden"
        )
    }

    /// 5. Kein aktiver Plan -> keine Anpassung eines nicht existierenden
    /// Plans.
    func test_planRequiringAdjustment_noActivePlan_returnsNil() {
        XCTAssertNil(ActivePlanResolver.planRequiringAdjustment(
            coachWasEnabled: true, coachWillBeEnabled: true,
            oldGoal: .halfMarathon, newGoal: .marathon, among: []
        ))
    }

    /// Ergaenzend: Coach bleibt AUS (weder vorher noch nachher aktiv) - ein
    /// im UI gar nicht editierbares Zielfeld darf trotzdem nie ausloesen,
    /// selbst wenn sich der rohe Wert technisch unterscheidet.
    func test_planRequiringAdjustment_coachStaysDisabled_returnsNilEvenIfGoalDiffers() throws {
        let plan = makePlan(name: "Active", generationSource: .cardioCoach)
        try context.save()

        XCTAssertNil(ActivePlanResolver.planRequiringAdjustment(
            coachWasEnabled: false, coachWillBeEnabled: false,
            oldGoal: .halfMarathon, newGoal: .marathon, among: [plan]
        ))
    }
}
#endif
