#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// P7.3 — deckt die Verbindung von `FourWeekReviewDueCalculator` (Core) mit
/// echten `TrainingPlan`-Objekten ab: Beobachtungs-Fallback wird genau
/// einmal, nachvollziehbar gesetzt (kein erfundenes historisches Datum),
/// Abschluss ist nur über eine ausdrückliche Aktion möglich, und mehrere
/// gleichzeitig aktive Pläne behalten JEWEILS ihren eigenen Status — keine
/// stillschweigende Auswahl nur eines Plans
/// (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md, P7.3).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class FourWeekReviewDueStatusTests: XCTestCase {

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Beobachtungs-Fallback (kein erfundenes historisches Datum)

    func testObservationAnchorIsEstablishedOnceForActivePlanWithoutActivatedAt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Altbestand", programType: "custom", isActive: true)
        // Simuliert einen Plan von vor P6.1: isActive, aber kein activatedAt.
        plan.activatedAt = nil
        context.insert(plan)
        try context.save()

        XCTAssertNil(plan.reviewObservationStartedAt)
        FourWeekReviewDueStatus.establishObservationAnchorsIfNeeded(in: context, now: d(2024, 1, 1))
        XCTAssertEqual(plan.reviewObservationStartedAt, d(2024, 1, 1))

        // Ein zweiter Aufruf zu einem SPÄTEREN Zeitpunkt darf den einmal
        // gesetzten Anker NICHT überschreiben — sonst würde der Beginn der
        // Beobachtung bei jedem Aufruf nach hinten driften.
        FourWeekReviewDueStatus.establishObservationAnchorsIfNeeded(in: context, now: d(2024, 6, 1))
        XCTAssertEqual(plan.reviewObservationStartedAt, d(2024, 1, 1))
    }

    func testObservationAnchorIsNotEstablishedWhenActivatedAtIsKnown() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Normal", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        try context.save()

        FourWeekReviewDueStatus.establishObservationAnchorsIfNeeded(in: context, now: d(2024, 6, 1))
        XCTAssertNil(plan.reviewObservationStartedAt, "ein bekannter Zeitanker darf keinen zusätzlichen Fallback bekommen")
    }

    func testObservationAnchorIsNotEstablishedForInactivePlan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Inaktiv", programType: "custom", isActive: false)
        plan.activatedAt = nil
        context.insert(plan)
        try context.save()

        FourWeekReviewDueStatus.establishObservationAnchorsIfNeeded(in: context, now: d(2024, 1, 1))
        XCTAssertNil(plan.reviewObservationStartedAt)
    }

    // MARK: - Abschluss nur über ausdrückliche Aktion

    func testStateIsDueBeforeAnyCompletionAndCompletedAfterMarkCompleted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        try context.save()

        let beforeCompletion = FourWeekReviewDueStatus.state(for: plan, in: context, now: d(2024, 2, 1), calendar: utc)
        guard case .due = beforeCompletion else {
            return XCTFail("28 Tage nach activatedAt sollte faellig sein: \(beforeCompletion)")
        }

        FourWeekReviewDueStatus.markCompleted(for: plan, decision: .keptAsIs, now: d(2024, 2, 1), in: context)

        let afterCompletion = FourWeekReviewDueStatus.state(for: plan, in: context, now: d(2024, 6, 1), calendar: utc)
        XCTAssertEqual(afterCompletion, .completed(at: d(2024, 2, 1), decision: .keptAsIs))
    }

    func testMarkCompletedPersistsActionTakenDecision() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        try context.save()

        FourWeekReviewDueStatus.markCompleted(for: plan, decision: .actionTaken, now: d(2024, 2, 1), in: context)
        XCTAssertEqual(plan.reviewDecision, .actionTaken)
        XCTAssertEqual(plan.reviewCompletedAt, d(2024, 2, 1))
    }

    // MARK: - Mehrere aktive Pläne: jeweils eigener Status, keine stillschweigende Auswahl

    func testIsAnyDueIsTrueWhenOnlyTheSecondOfTwoActivePlansIsDue() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // "Alpha" sortiert vor "Beta" (alphabetisch) — die bereits für den
        // Review-INHALT akzeptierte Vereinfachung würde "Alpha" bewerten.
        // Die Fälligkeits-AGGREGATION hier darf sich davon NICHT leiten
        // lassen: "Beta" allein ist fällig, muss also trotzdem erkannt werden.
        let alpha = TrainingPlan(name: "Alpha", programType: "custom", isActive: true)
        alpha.activatedAt = d(2024, 1, 20) // erst 12 Tage her -> noch nicht faellig
        let beta = TrainingPlan(name: "Beta", programType: "custom", isActive: true)
        beta.activatedAt = d(2024, 1, 1) // 31 Tage her -> faellig
        context.insert(alpha)
        context.insert(beta)
        try context.save()

        XCTAssertTrue(FourWeekReviewDueStatus.isAnyDue(among: [alpha, beta], now: d(2024, 2, 1), calendar: utc))
    }

    func testIsAnyDueIsFalseWhenNoActivePlanIsDueYet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 20)
        context.insert(plan)
        try context.save()

        XCTAssertFalse(FourWeekReviewDueStatus.isAnyDue(among: [plan], now: d(2024, 2, 1), calendar: utc))
    }

    func testEachActivePlanKeepsItsOwnCompletionStateIndependently() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let planA = TrainingPlan(name: "A", programType: "custom", isActive: true)
        planA.activatedAt = d(2024, 1, 1)
        let planB = TrainingPlan(name: "B", programType: "custom", isActive: true)
        planB.activatedAt = d(2024, 1, 1)
        context.insert(planA)
        context.insert(planB)
        try context.save()

        FourWeekReviewDueStatus.markCompleted(for: planA, decision: .keptAsIs, now: d(2024, 2, 1), in: context)

        // Plan A ist abgeschlossen, Plan B weiterhin faellig -> die
        // Aggregation darf Plan A's Abschluss nicht auf Plan B uebertragen.
        XCTAssertTrue(FourWeekReviewDueStatus.isAnyDue(among: [planA, planB], now: d(2024, 2, 1), calendar: utc))
        guard case .completed = FourWeekReviewDueStatus.state(for: planA, in: context, now: d(2024, 2, 1), calendar: utc) else {
            return XCTFail("Plan A sollte abgeschlossen sein")
        }
        guard case .due = FourWeekReviewDueStatus.state(for: planB, in: context, now: d(2024, 2, 1), calendar: utc) else {
            return XCTFail("Plan B sollte weiterhin faellig sein")
        }
    }

    // MARK: - unbekannter Zeitanker zählt nicht als fällig

    func testIsAnyDueIsFalseForActivePlanWithoutAnyAnchorYet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Ohne Anker", programType: "custom", isActive: true)
        plan.activatedAt = nil
        context.insert(plan)
        try context.save()

        // Bewusst OHNE establishObservationAnchorsIfNeeded aufzurufen: ein
        // Plan ganz ohne jeden Zeitanker ist `.unknown`, nie `.due` — kein
        // erfundenes Fälligkeitssignal.
        XCTAssertFalse(FourWeekReviewDueStatus.isAnyDue(among: [plan], now: d(2024, 2, 1), calendar: utc))
    }
}
#endif
