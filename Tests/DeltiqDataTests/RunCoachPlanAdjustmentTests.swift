#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Paket 1 (Laufcoach-Plananpassung, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// reine Modell-Tests gegen echte SwiftData-Objekte (kein `ModelContainer`
/// noetig fuer `analyze`/`isEligibleForAdjustment` selbst - sie lesen nur,
/// mutieren nichts - aber `TrainingDay`/`Exercise` sind `@Model`-Typen und
/// brauchen trotzdem einen Context, um eingefuegt/verknuepft zu werden).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class RunCoachPlanAdjustmentTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makePlan() -> TrainingPlan {
        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        return plan
    }

    /// Setzt `generationFingerprint` auf den aktuellen Inhalt - macht den
    /// Tag "wizard-erzeugt und seither unveraendert" (anfassbar).
    private func markUntouched(_ day: TrainingDay) {
        day.generationFingerprint = day.currentContentFingerprint
    }

    private func addExercise(
        to day: TrainingDay, name: String = "Squat", sets: Int = 3,
        primaryMuscle: MuscleGroup? = nil, orderIndex: Int = 0
    ) {
        let exercise = Exercise(name: name, sets: sets, orderIndex: orderIndex, primaryMuscle: primaryMuscle, day: day)
        context.insert(exercise)
        day.exercises.append(exercise)
    }

    // MARK: - isEligibleForAdjustment

    func testManuallyAddedDayWithoutFingerprintIsProtected() {
        let plan = makePlan()
        let day = TrainingDay(name: "Legs", weekday: 2, type: .legs, plan: plan)
        context.insert(day)
        XCTAssertFalse(RunCoachPlanAdjustment.isEligibleForAdjustment(day))
    }

    func testEditedDayWithMismatchedFingerprintIsProtected() {
        let plan = makePlan()
        let day = TrainingDay(name: "Legs", weekday: 2, type: .legs, plan: plan)
        context.insert(day)
        markUntouched(day)
        addExercise(to: day, name: "Lunge")
        // Fingerprint wurde VOR der Uebung gesetzt - weicht jetzt ab, exakt
        // das vom User-Edit erwartete Verhalten.
        XCTAssertFalse(RunCoachPlanAdjustment.isEligibleForAdjustment(day))
    }

    func testUntouchedWizardDayIsEligible() {
        let plan = makePlan()
        let day = TrainingDay(name: "Legs", weekday: 2, type: .legs, plan: plan)
        context.insert(day)
        addExercise(to: day, name: "Squat")
        markUntouched(day)
        XCTAssertTrue(RunCoachPlanAdjustment.isEligibleForAdjustment(day))
    }

    func testUntouchedDayWithSessionHistoryIsProtected() {
        let plan = makePlan()
        let day = TrainingDay(name: "Legs", weekday: 2, type: .legs, plan: plan)
        context.insert(day)
        addExercise(to: day, name: "Squat")
        markUntouched(day)
        let session = WorkoutSession(startTime: Date(), day: day)
        context.insert(session)
        day.sessions.append(session)
        XCTAssertFalse(RunCoachPlanAdjustment.isEligibleForAdjustment(day))
    }

    // MARK: - analyze: cardio availability

    func testAnalyzeWithoutActivePlanReturnsNoActivePlan() {
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: nil).cardioAvailability, .noActivePlan)
    }

    func testAnalyzeWithOnlyProtectedCardioDaysReturnsNoEligibleCardioDay() {
        let plan = makePlan()
        let cardioDay = TrainingDay(name: "Run", weekday: 2, type: .cardio, plan: plan)
        context.insert(cardioDay)
        // Kein `markUntouched` - manuell hinzugefuegter Cardio-Tag, geschuetzt.
        plan.days.append(cardioDay)
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: plan).cardioAvailability, .noEligibleCardioDay)
    }

    /// Korrektur (Paket 1, Teil 3): `PlanGenerator.generate` (der Ziel-
    /// gefuehrte "Plan bauen"-Pfad) stempelt JEDEN Tag hartcodiert mit
    /// `type: .fullBody`, auch reine Cardio-Tage - `.cardio` als Typ setzen
    /// nur die kuratierten Templates. Die Erkennung muss daher auch ueber
    /// `Exercise.isCardio` funktionieren, nicht nur ueber `TrainingDay.type`.
    func testAnalyzeDetectsCardioDayViaExerciseFlagEvenWithFullBodyType() {
        let plan = makePlan()
        let day = TrainingDay(name: "Easy Run", weekday: 2, type: .fullBody, plan: plan)
        context.insert(day)
        let run = Exercise(name: "Easy Run", isCardio: true, day: day)
        context.insert(run)
        day.exercises.append(run)
        markUntouched(day)
        plan.days.append(day)
        guard case .ready(let ids) = RunCoachPlanAdjustment.analyze(plan: plan).cardioAvailability else {
            return XCTFail("expected .ready")
        }
        XCTAssertEqual(ids, [day.persistentModelID])
    }

    func testAnalyzeWithEligibleCardioDayReturnsReadyWithItsID() {
        let plan = makePlan()
        let cardioDay = TrainingDay(name: "Run", weekday: 2, type: .cardio, plan: plan)
        context.insert(cardioDay)
        markUntouched(cardioDay)
        plan.days.append(cardioDay)
        guard case .ready(let ids) = RunCoachPlanAdjustment.analyze(plan: plan).cardioAvailability else {
            return XCTFail("expected .ready")
        }
        XCTAssertEqual(ids, [cardioDay.persistentModelID])
    }

    // MARK: - analyze: leg work (fuenf Faelle)

    func testLegWorkWithNoEligibleStrengthDaysIsConflict() {
        let plan = makePlan()
        let cardioDay = TrainingDay(name: "Run", weekday: 2, type: .cardio, plan: plan)
        context.insert(cardioDay)
        markUntouched(cardioDay)
        plan.days.append(cardioDay)
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: plan).legWork, .conflict)
    }

    func testLegWorkWithMaintenanceLevelSetsIsUnchanged() {
        let plan = makePlan()
        let day = TrainingDay(name: "Legs", weekday: 3, type: .legs, plan: plan)
        context.insert(day)
        addExercise(to: day, name: "Squat", sets: 4, primaryMuscle: .quads)
        markUntouched(day)
        plan.days.append(day)
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: plan).legWork, .unchanged)
    }

    func testLegWorkWithNoLegSetsAtAllSuggestsSmallAddition() {
        let plan = makePlan()
        let day = TrainingDay(name: "Push", weekday: 3, type: .push, plan: plan)
        context.insert(day)
        addExercise(to: day, name: "Bench Press", sets: 4, primaryMuscle: .chest)
        markUntouched(day)
        plan.days.append(day)
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: plan).legWork, .addSmallAddition)
    }

    func testLegWorkWithNoLegSetsButAlreadyFullDaySuggestsReplaceForTime() {
        let plan = makePlan()
        let day = TrainingDay(name: "Push", weekday: 3, type: .push, plan: plan)
        context.insert(day)
        for index in 0..<6 {
            addExercise(to: day, name: "Exercise \(index)", sets: 3, primaryMuscle: .chest, orderIndex: index)
        }
        markUntouched(day)
        plan.days.append(day)
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: plan).legWork, .replaceForTime)
    }

    func testLegWorkWithOverreachingSetsSuggestsRedistribute() {
        let plan = makePlan()
        let day = TrainingDay(name: "Legs", weekday: 3, type: .legs, plan: plan)
        context.insert(day)
        addExercise(to: day, name: "Squat", sets: 10, primaryMuscle: .quads)
        addExercise(to: day, name: "Lunge", sets: 10, primaryMuscle: .quads, orderIndex: 1)
        markUntouched(day)
        plan.days.append(day)
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: plan).legWork, .redistribute)
    }

    /// Ein manuell editierter Kraft-Tag (Fingerprint weicht ab) zaehlt
    /// NICHT in die Bein-Set-Zaehlung - er ist geschuetzt, seine Uebungen
    /// bleiben unangetastet und unbewertet.
    func testManuallyEditedStrengthDayIsExcludedFromLegWorkAssessment() {
        let plan = makePlan()
        let day = TrainingDay(name: "Legs", weekday: 3, type: .legs, plan: plan)
        context.insert(day)
        markUntouched(day)
        addExercise(to: day, name: "Squat", sets: 10, primaryMuscle: .quads)
        plan.days.append(day)
        // Fingerprint wurde VOR der Uebung gesetzt - Tag ist geschuetzt, also
        // KEINE anfassbaren Kraft-Tage -> conflict, nicht "unchanged" trotz
        // der 10 Saetze.
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: plan).legWork, .conflict)
    }

    // MARK: - convertibleStrengthDays / eligibleDaysForGoalChange
    //
    // `convertibleStrengthDays` erkennt anfassbare Krafttage, die ein
    // Zielwechsel laut Ziel-Tabelle ueberfluessig macht (z.B. Halbmarathon
    // mit 2 Krafttagen -> Marathon mit 0). Nachbesserung ("Krafttraining bei
    // Laufzieländerung erhalten"): dieses Ergebnis fliesst NICHT automatisch
    // in `cardioAvailability`/`.ready` ein - es ist rein informativ, fuer
    // eine SEPARATE, nur nach expliziter Nutzerbestaetigung nutzbare Option
    // (`CoachAdjustmentCardModel.accept`s `convertStrengthDaysIfNeeded`).

    private func makeStrengthDay(weekday: Int, in plan: TrainingPlan) -> TrainingDay {
        let day = TrainingDay(name: "Kraft", weekday: weekday, type: .legs, plan: plan)
        context.insert(day)
        addExercise(to: day, name: "Squat", sets: 3, primaryMuscle: .quads)
        markUntouched(day)
        plan.days.append(day)
        return day
    }

    /// Reproduziert den gemeldeten Fehler isoliert: Halbmarathon-Struktur (2
    /// anfassbare Krafttage, Marathon braucht 0) ohne jeden freien Tag -
    /// `convertibleStrengthDays(targetGoal: .marathon)` muss beide liefern.
    func testConvertibleStrengthDaysReturnsSurplusWhenTargetGoalNeedsFewer() {
        let plan = makePlan()
        let strength1 = makeStrengthDay(weekday: 4, in: plan)
        let strength2 = makeStrengthDay(weekday: 6, in: plan)
        let result = RunCoachPlanAdjustment.convertibleStrengthDays(in: plan, targetGoal: .marathon)
        XCTAssertEqual(Set(result.map(\.persistentModelID)), Set([strength1, strength2].map(\.persistentModelID)))
    }

    /// Wechsel zwischen zwei Zielen mit identischem Krafttage-Bedarf
    /// (Halbmarathon/10K: je 2) darf KEINEN Krafttag als ueberzaehlig
    /// melden - er wird weiterhin gebraucht.
    func testConvertibleStrengthDaysReturnsEmptyWhenTargetGoalStillNeedsAllOfThem() {
        let plan = makePlan()
        _ = makeStrengthDay(weekday: 4, in: plan)
        _ = makeStrengthDay(weekday: 6, in: plan)
        XCTAssertEqual(RunCoachPlanAdjustment.convertibleStrengthDays(in: plan, targetGoal: .tenK), [])
    }

    /// Ein manuell editierter Krafttag (Fingerprint weicht ab) darf NIE als
    /// konvertierbar gelten, auch wenn das neue Ziel gar keine Krafttage mehr
    /// braucht - dieselbe Schutzregel wie ueberall sonst in dieser Datei.
    func testConvertibleStrengthDaysExcludesManuallyEditedStrengthDays() {
        let plan = makePlan()
        let day = TrainingDay(name: "Legs", weekday: 4, type: .legs, plan: plan)
        context.insert(day)
        markUntouched(day)
        addExercise(to: day, name: "Squat", sets: 3, primaryMuscle: .quads)
        plan.days.append(day)
        XCTAssertEqual(RunCoachPlanAdjustment.convertibleStrengthDays(in: plan, targetGoal: .marathon), [])
    }

    /// `analyze(plan:targetGoal:)` ohne `targetGoal` (bestehende Aufrufer)
    /// bleibt unveraendert: ausschliesslich bestehende Cardio-Tage zaehlen,
    /// auch wenn ueberzaehlige Krafttage vorhanden waeren.
    func testAnalyzeWithoutTargetGoalIgnoresConvertibleStrengthDays() {
        let plan = makePlan()
        _ = makeStrengthDay(weekday: 4, in: plan)
        _ = makeStrengthDay(weekday: 6, in: plan)
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: plan).cardioAvailability, .noEligibleCardioDay)
        XCTAssertEqual(RunCoachPlanAdjustment.analyze(plan: plan).convertibleStrengthDays, [])
    }

    /// Nachbesserung ("Krafttraining bei Laufzieländerung erhalten"):
    /// Halbmarathon-Struktur (3 anfassbare Lauftage + 2 anfassbare
    /// Krafttage, ALLE 7 Wochentage belegt, keine Ruhetage) -> mit
    /// `targetGoal: .marathon` darf `cardioAvailability` NUR die 3
    /// bestehenden Lauftage enthalten, NIE die Krafttage - diese duerfen
    /// ausschliesslich ueber `convertibleStrengthDays` sichtbar werden, als
    /// separate, nur nach Bestaetigung nutzbare Information.
    func testAnalyzeNeverMixesConvertibleStrengthDaysIntoCardioAvailability() {
        let plan = makePlan()
        var runDays: [TrainingDay] = []
        for weekday in [1, 3, 5] {
            let day = TrainingDay(name: "Run", weekday: weekday, type: .fullBody, plan: plan)
            context.insert(day)
            let run = Exercise(name: "Easy Run", isCardio: true, day: day)
            context.insert(run)
            day.exercises.append(run)
            markUntouched(day)
            plan.days.append(day)
            runDays.append(day)
        }
        let strength1 = makeStrengthDay(weekday: 2, in: plan)
        let strength2 = makeStrengthDay(weekday: 7, in: plan)
        // Wochentag 4, 6 bleiben Ruhetage, aber NICHT isAutoFilledPlaceholder
        // - alle 7 Wochentage sind belegt, es gibt also weder einfuegbare
        // Ruhetage noch freie Wochentage.
        let rest1 = TrainingDay(name: "Ruhetag", weekday: 4, type: .rest, plan: plan)
        let rest2 = TrainingDay(name: "Ruhetag", weekday: 6, type: .rest, plan: plan)
        context.insert(rest1)
        context.insert(rest2)
        plan.days.append(rest1)
        plan.days.append(rest2)

        let analysis = RunCoachPlanAdjustment.analyze(plan: plan, targetGoal: .marathon)
        XCTAssertEqual(analysis.insertableRestDays, [], "Testaufbau: keine einfuegbaren Ruhetage vorhanden")
        XCTAssertEqual(analysis.freeWeekdaysForNewDays, [], "Testaufbau: alle 7 Wochentage sind belegt")
        guard case .ready(let ids) = analysis.cardioAvailability else {
            return XCTFail("expected .ready fuer die 3 bestehenden Lauftage")
        }
        XCTAssertEqual(Set(ids), Set(runDays.map(\.persistentModelID)), "cardioAvailability darf NIE Krafttage enthalten")
        XCTAssertEqual(Set(analysis.convertibleStrengthDays), Set([strength1, strength2].map(\.persistentModelID)), "die Krafttage bleiben als separate, informative Groesse sichtbar")
    }
}
#endif
