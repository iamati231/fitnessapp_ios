#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// P7.2 — deckt den Datenzusammenbau für `FourWeekReviewOrchestrator` ab.
/// Die DECISION-Logik selbst ist bereits in `FourWeekReviewOrchestratorTests`
/// (Core, Linux) abgedeckt; hier wird nur geprüft, dass reale SwiftData-
/// Objekte korrekt in die Orchestrator-Eingabe übersetzt werden.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class FourWeekReviewAssemblerTests: XCTestCase {

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

    // MARK: - Kein Plan vorhanden

    func testNoActivePlanYieldsKeepAsIsWithDataGapsNeverFabricated() throws {
        let container = try makeContainer()
        let review = FourWeekReviewAssembler.assemble(
            in: container.mainContext, now: d(2024, 2, 1), calendar: utc
        )
        XCTAssertEqual(review.outcome, .keepAsIs, "kein Befund erfindbar ohne jede Datengrundlage")
        XCTAssertTrue(review.dataGaps.contains(.participationNotReliablyEvaluable(.planNotCurrentlyActive)))
        XCTAssertTrue(review.dataGaps.contains(.noCheckInYet))
    }

    // MARK: - Plan vollständig eingehalten

    func testCompliantPlanWithGoodCheckInYieldsKeepAsIs() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Review-Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        let day = TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: plan)
        context.insert(day)

        // Vier abgeschlossene Sessions innerhalb des Fensters — genug, um
        // die flexible Wochenkadenz (1x/Woche, 32 Tage -> 4 faellige
        // Einheiten) vollstaendig zu erfuellen.
        for offset in [0, 7, 14, 21] {
            let date = utc.date(byAdding: .day, value: offset, to: d(2024, 1, 2))!
            context.insert(WorkoutSession(
                startTime: date, endTime: date.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 0,
                totalVolumeKg: 0, isCompleted: true, day: day
            ))
        }

        context.insert(PeriodicCheckIn(
            date: d(2024, 1, 28),
            frequencyFeedback: .asPlanned,
            durationFeedback: .justRight,
            hadComplaints: false,
            goalStillCurrent: true
        ))
        try context.save()

        let review = FourWeekReviewAssembler.assemble(in: context, now: d(2024, 2, 1), calendar: utc)
        guard case .evaluated(let summary) = review.participation else {
            return XCTFail("Teilnahme haette auswertbar sein muessen: \(review.participation)")
        }
        XCTAssertEqual(summary.completedCount, summary.plannedCount)
        XCTAssertEqual(summary.missedCount, 0)
        XCTAssertEqual(review.outcome, .keepAsIs)
        XCTAssertTrue(review.dataGaps.isEmpty)
    }

    // MARK: - Teilnahme deutlich unter Plan

    func testHeavilyMissedParticipationIsSurfacedAsConcern() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Review-Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        let day = TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: plan)
        context.insert(day)
        try context.save()

        // Keine einzige Session im gesamten Zeitraum.
        let review = FourWeekReviewAssembler.assemble(in: context, now: d(2024, 2, 1), calendar: utc)
        guard case .evaluated(let summary) = review.participation else {
            return XCTFail("Teilnahme haette auswertbar sein muessen: \(review.participation)")
        }
        XCTAssertEqual(summary.missedCount, summary.plannedCount)
        guard case .concernsFound(let concerns) = review.outcome else {
            return XCTFail("erwarteter Befund fehlt: \(review.outcome)")
        }
        XCTAssertTrue(concerns.contains {
            if case .participationBelowPlan = $0 { return true }
            return false
        })
        // Kein Check-in vorhanden -> explizit als Datenlücke sichtbar, nie
        // stillschweigend als "keine Beschwerden" interpretiert.
        XCTAssertTrue(review.dataGaps.contains(.noCheckInYet))
    }

    // MARK: - Periodisches Feedback wird unverändert durchgereicht

    func testLatestCheckInFeedbackIsAssembledFromRealData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        // Aelterer Eintrag: unauffaellig, darf keinen Befund ausloesen.
        context.insert(PeriodicCheckIn(
            date: d(2024, 1, 10),
            hadComplaints: false,
            goalStillCurrent: true
        ))
        // Neuerer Eintrag: auffaellig. Nur wenn der Assembler tatsaechlich
        // den LETZTEN Eintrag nimmt (nicht den ersten gefundenen), tauchen
        // diese beiden Befunde auf.
        context.insert(PeriodicCheckIn(
            date: d(2024, 1, 20),
            hadComplaints: true,
            complaintsNote: "Schulter",
            goalStillCurrent: false
        ))
        try context.save()

        let review = FourWeekReviewAssembler.assemble(in: context, now: d(2024, 2, 1), calendar: utc)
        guard case .concernsFound(let concerns) = review.outcome else {
            return XCTFail("erwartete Befunde aus dem NEUEREN Check-in fehlen: \(review.outcome)")
        }
        XCTAssertTrue(concerns.contains { if case .complaintsReported = $0 { return true }; return false })
        XCTAssertTrue(concerns.contains { if case .goalNoLongerCurrent = $0 { return true }; return false })
    }

    // MARK: - P9: explizite Planauswahl (Mehrplan-Bedienablauf)

    /// Beweist, dass `assemble(in:for:)` TATSÄCHLICH den übergebenen Plan
    /// bewertet, nicht die "erster Plan nach Name"-Vereinfachung — "Alpha"
    /// (ohne jede Session, würde `.concernsFound` liefern) sortiert
    /// alphabetisch VOR "Beta" (vollständig eingehalten, `.keepAsIs`). Ohne
    /// die explizite Auswahl würde dieser Test fälschlich Alphas Befund
    /// zeigen.
    func testAssembleForExplicitPlanUsesThatPlansParticipationNotTheAlphabeticallyFirst() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let alpha = TrainingPlan(name: "Alpha", programType: "custom", isActive: true)
        alpha.activatedAt = d(2024, 1, 1)
        context.insert(alpha)
        context.insert(TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: alpha))

        let beta = TrainingPlan(name: "Beta", programType: "custom", isActive: true)
        beta.activatedAt = d(2024, 1, 1)
        context.insert(beta)
        let betaDay = TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: beta)
        context.insert(betaDay)
        for offset in [0, 7, 14, 21] {
            let date = utc.date(byAdding: .day, value: offset, to: d(2024, 1, 2))!
            context.insert(WorkoutSession(
                startTime: date, endTime: date.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 0,
                totalVolumeKg: 0, isCompleted: true, day: betaDay
            ))
        }
        try context.save()

        // Ohne explizite Auswahl: "Alpha" (erster nach Name), keine
        // Sessions -> deutlich verfehlte Teilnahme.
        let defaultReview = FourWeekReviewAssembler.assemble(in: context, now: d(2024, 2, 1), calendar: utc)
        guard case .concernsFound = defaultReview.outcome else {
            return XCTFail("Default-Auswahl sollte weiterhin Alpha (verfehlte Teilnahme) liefern: \(defaultReview.outcome)")
        }

        // Mit expliziter Auswahl von "Beta": vollständig eingehalten.
        let betaReview = FourWeekReviewAssembler.assemble(in: context, for: beta, now: d(2024, 2, 1), calendar: utc)
        XCTAssertEqual(betaReview.outcome, .keepAsIs, "explizite Auswahl von Beta muss Betas eigene Teilnahme bewerten, nicht Alphas")
        guard case .evaluated(let summary) = betaReview.participation else {
            return XCTFail("Betas Teilnahme hätte auswertbar sein müssen: \(betaReview.participation)")
        }
        XCTAssertEqual(summary.missedCount, 0)
    }

    func testAllActivePlansReturnsOnlyActiveOnesSortedByName() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let zeta = TrainingPlan(name: "Zeta", programType: "custom", isActive: true)
        let alpha = TrainingPlan(name: "Alpha", programType: "custom", isActive: true)
        let inactive = TrainingPlan(name: "Inaktiv", programType: "custom", isActive: false)
        context.insert(zeta)
        context.insert(alpha)
        context.insert(inactive)
        try context.save()

        let result = FourWeekReviewAssembler.allActivePlans(in: context)
        XCTAssertEqual(result.map(\.name), ["Alpha", "Zeta"])
    }
}
#endif
