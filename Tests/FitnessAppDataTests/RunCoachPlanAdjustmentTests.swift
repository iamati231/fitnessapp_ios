#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

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
}
#endif
