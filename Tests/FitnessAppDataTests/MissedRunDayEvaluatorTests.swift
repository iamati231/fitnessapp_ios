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
}
#endif
