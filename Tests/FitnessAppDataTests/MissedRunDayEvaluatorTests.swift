#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Paket 3a (Laufversäumnis-Hinweis, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// deckt die Projektions-Logik selbst ab — ob `isRunningDay` tatsächlich nur
/// Laufen (nicht Radfahren, nicht unklare Altbestands-Tage) als Gelegenheit
/// zählt. Die 10 geforderten Verhaltens-Fälle leben in
/// `Tests/FitnessAppUITests/MissedRunDaysCardModelTests.swift` (brauchen
/// `CoachAdjustmentCardModel`, daher dort statt hier).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class MissedRunDayEvaluatorTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Ein Plan mit ZWEI Cardio-Tagen — einer klar Laufen, einer klar
    /// Radfahren — darf den Rad-Tag nicht mitzählen (Paket-3a-Scope: "kein
    /// Radfahren in diesem ersten Schritt"). Ein dritter Cardio-Tag OHNE
    /// gesetztes `enduranceSportKind` (Altbestand) zählt ebenfalls NICHT —
    /// niemals aus Name/Typ geraten.
    func testOnlyClearlyIdentifiedRunningDaysAreCounted() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Hybrid-Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)

        let runDay = TrainingDay(name: "Run", weekday: 2, type: .cardio, plan: plan)
        context.insert(runDay)
        let run = Exercise(name: "Easy Run", isCardio: true, day: runDay)
        run.enduranceSportKind = .running
        context.insert(run)
        runDay.exercises.append(run)
        plan.days.append(runDay)

        let bikeDay = TrainingDay(name: "Bike", weekday: 4, type: .cardio, plan: plan)
        context.insert(bikeDay)
        let bike = Exercise(name: "Easy Ride", isCardio: true, day: bikeDay)
        bike.enduranceSportKind = .cycling
        context.insert(bike)
        bikeDay.exercises.append(bike)
        plan.days.append(bikeDay)

        let legacyDay = TrainingDay(name: "Radfahren", weekday: 6, type: .cardio, plan: plan)
        context.insert(legacyDay)
        let legacyExercise = Exercise(name: "Radfahren", isCardio: true, day: legacyDay)
        context.insert(legacyExercise) // enduranceSportKind bleibt nil (Altbestand)
        legacyDay.exercises.append(legacyExercise)
        plan.days.append(legacyDay)

        try context.save()

        XCTAssertTrue(MissedRunDayEvaluator.isRunningDay(runDay))
        XCTAssertFalse(MissedRunDayEvaluator.isRunningDay(bikeDay))
        XCTAssertFalse(MissedRunDayEvaluator.isRunningDay(legacyDay))

        // Keine Session jemals geloggt -> genau EIN Lauf-Tag ist die einzige
        // zählende Gelegenheit, nicht drei.
        let result = MissedRunDayEvaluator.evaluate(plan: plan, in: context, now: d(2024, 2, 1), calendar: utc)
        guard case .evaluated(let summary) = result else {
            return XCTFail("haette auswertbar sein muessen: \(result)")
        }
        XCTAssertEqual(summary.missedCount, 2, "1 Lauf-Tag/Woche über das 14-Tage-Fenster -> 2 fällige Gelegenheiten")
    }

    /// Ein Plan ganz ohne identifizierbaren Lauf-Tag liefert
    /// `.planHasNoTrainingDays` — niemals geraten, niemals 0-von-0 als
    /// "alles erfüllt" fehlinterpretiert.
    func testPlanWithNoIdentifiableRunningDayIsNotReliablyEvaluable() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Nur Kraft", weeks: 8, isActive: true, targetEnvironment: .gym)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        let strengthDay = TrainingDay(name: "Push", weekday: 2, type: .fullBody, plan: plan)
        context.insert(strengthDay)
        let squat = Exercise(name: "Squat", isCardio: false, day: strengthDay)
        context.insert(squat)
        strengthDay.exercises.append(squat)
        plan.days.append(strengthDay)
        try context.save()

        let result = MissedRunDayEvaluator.evaluate(plan: plan, in: context, now: d(2024, 2, 1), calendar: utc)
        XCTAssertEqual(result, .notReliablyEvaluable(.planHasNoTrainingDays))
    }

    // MARK: - Paket-3a-Restpunkt 1: totalConcludedRunOpportunities

    /// Monoton steigend (NICHT gedeckelt wie das rollierende Fenster von
    /// `evaluate`): reiner Kalenderwert, haengt NICHT davon ab, ob Sessions
    /// existieren — identische Zahlen wie das manuelle
    /// `floor(elapsedDays/7)`-Kalkuel aus `MissedRunDaysCardModelTests`-Doku.
    func testTotalConcludedRunOpportunitiesGrowsMonotonicallyAndIsNotWindowClamped() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        let runDay = TrainingDay(name: "Run", weekday: 2, type: .cardio, plan: plan)
        context.insert(runDay)
        let run = Exercise(name: "Easy Run", isCardio: true, day: runDay)
        run.enduranceSportKind = .running
        context.insert(run)
        runDay.exercises.append(run)
        plan.days.append(runDay)
        try context.save()

        // Jan 1 .. Mar 1 (2024 ist ein Schaltjahr) = 61 Tage -> floor(61/7) = 8.
        let day61 = MissedRunDayEvaluator.totalConcludedRunOpportunities(plan: plan, now: d(2024, 3, 1), calendar: utc)
        XCTAssertEqual(day61, 8)
        // Einen Tag spaeter (62 Tage, floor(62/7) = 8): KEINE neue Gelegenheit
        // ist verstrichen - bewusst unveraendert, nicht einfach "je Tag +1".
        let day62 = MissedRunDayEvaluator.totalConcludedRunOpportunities(plan: plan, now: d(2024, 3, 2), calendar: utc)
        XCTAssertEqual(day62, 8)
        // Eine Woche nach dem ersten Messpunkt (68 Tage, floor(68/7) = 9):
        // genau eine neue Gelegenheit ist seither verstrichen - waehrend ein
        // GLEICHZEITIG gerechnetes, rollierendes `evaluate`-Fenster bei
        // vollstaendiger Saettigung unveraendert bliebe (siehe
        // `MissedRunDaysCardModelTests.
        // testReappearsAfterDismissWhenNewOpportunityConcludedDespiteCappedMissedCount`).
        let day68 = MissedRunDayEvaluator.totalConcludedRunOpportunities(plan: plan, now: d(2024, 3, 8), calendar: utc)
        XCTAssertEqual(day68, 9)
    }

    func testTotalConcludedRunOpportunitiesIsNilWithoutActivationAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Plan", weeks: 8, isActive: true, targetEnvironment: .gym)
        context.insert(plan)
        let runDay = TrainingDay(name: "Run", weekday: 2, type: .cardio, plan: plan)
        context.insert(runDay)
        let run = Exercise(name: "Easy Run", isCardio: true, day: runDay)
        run.enduranceSportKind = .running
        context.insert(run)
        runDay.exercises.append(run)
        plan.days.append(runDay)
        try context.save()

        XCTAssertNil(MissedRunDayEvaluator.totalConcludedRunOpportunities(plan: plan, now: d(2024, 2, 1), calendar: utc))
    }
}
#endif
