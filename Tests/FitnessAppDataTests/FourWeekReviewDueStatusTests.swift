#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// P7.3/P8 Stufe 3 — deckt die Verbindung von `FourWeekReviewDueCalculator`
/// (Core) mit echten `TrainingPlan`-Objekten ab: Beobachtungs-Fallback wird
/// genau einmal, nachvollziehbar gesetzt (kein erfundenes historisches
/// Datum), Abschluss ist nur über eine ausdrückliche Aktion möglich und
/// eröffnet SOFORT den nächsten Block (kein zusätzlicher "Block starten"-
/// Schritt), Blockhistorie bleibt dauerhaft erhalten, mehrere gleichzeitig
/// aktive Pläne behalten JEWEILS ihren eigenen, unabhängigen Status.
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

    /// Ein nichtssagender, aber gültiger Review-Stub — diese Tests prüfen
    /// den Zyklus/die Historien-Mechanik, nicht den Review-INHALT (der ist
    /// bereits in `FourWeekReviewOrchestratorTests`/`FourWeekReviewAssemblerTests`
    /// abgedeckt).
    private func stubReview() -> FourWeekReviewOrchestrator.Review {
        FourWeekReviewOrchestrator.Review(
            participation: .notReliablyEvaluable(.activationStartUnknown),
            outcome: .keepAsIs,
            dataGaps: []
        )
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

    // MARK: - Erster Block: unverändert 28 Tage, Abschluss nur über ausdrückliche Aktion

    func testStateIsDueBeforeAnyCompletion() throws {
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
    }

    func testMarkingFirstBlockCompletePersistsDecisionAndOpensNextBlockImmediately() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        try context.save()

        let blockStart = FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc)
        XCTAssertEqual(blockStart, d(2024, 1, 1))

        let completedAt = d(2024, 2, 1)
        let didComplete = FourWeekReviewDueStatus.completeCurrentBlock(
            for: plan, expectedBlockStart: blockStart, decision: .keptAsIs,
            shownReview: stubReview(), now: completedAt, calendar: utc, in: context
        )
        XCTAssertTrue(didComplete)
        XCTAssertEqual(plan.reviewDecision, .keptAsIs)
        XCTAssertEqual(plan.reviewCompletedAt, completedAt)

        // Kein zusätzlicher "Block starten"-Schritt: der nächste Block ist
        // SOFORT offen, mit dem Kalendertag NACH dem Abschluss als Beginn —
        // der Abschlusstag selbst zählt noch vollständig zum abgeschlossenen
        // Block (keine doppelte Zählung an der Grenze).
        let nextBlockStart = FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc)
        XCTAssertEqual(nextBlockStart, d(2024, 2, 2))

        // activatedAt bleibt unverändert — der Blockstart wird separat
        // behandelt, nie aus activatedAt abgeleitet, sobald ein Block
        // abgeschlossen wurde.
        XCTAssertEqual(plan.activatedAt, d(2024, 1, 1))

        // Der neue Block nutzt 42 statt 28 Tage.
        XCTAssertEqual(FourWeekReviewDueStatus.intervalDays(for: plan), FourWeekReviewDueCalculator.subsequentBlockIntervalDays)
        let stateRightAfter = FourWeekReviewDueStatus.state(for: plan, in: context, now: completedAt, calendar: utc)
        guard case .notYetDue(let dueAt) = stateRightAfter else {
            return XCTFail("direkt nach Abschluss sollte der naechste Block noch nicht faellig sein: \(stateRightAfter)")
        }
        XCTAssertEqual(dueAt, utc.date(byAdding: .day, value: 42, to: d(2024, 2, 2)))
    }

    // MARK: - Doppeltippen/erneute Ausführung ändert nichts

    func testCompletingTheSameBlockTwiceIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        try context.save()

        let blockStart = FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc)
        let firstTap = FourWeekReviewDueStatus.completeCurrentBlock(
            for: plan, expectedBlockStart: blockStart, decision: .keptAsIs,
            shownReview: stubReview(), now: d(2024, 2, 1), calendar: utc, in: context
        )
        XCTAssertTrue(firstTap)

        // Zweiter Tap mit demselben (jetzt veralteten) erwarteten Blockstart —
        // z. B. ein Doppeltipp, dessen zweites Event erst nach dem ersten
        // Schreibvorgang ankommt. Darf KEINEN zweiten Historien-Eintrag
        // erzeugen.
        let secondTap = FourWeekReviewDueStatus.completeCurrentBlock(
            for: plan, expectedBlockStart: blockStart, decision: .actionTaken,
            shownReview: stubReview(), now: d(2024, 2, 1), calendar: utc, in: context
        )
        XCTAssertFalse(secondTap, "ein zweiter Aufruf mit demselben Blockstart darf nichts mehr aendern")
        XCTAssertEqual(FourWeekReviewDueStatus.history(for: plan).count, 1)
        XCTAssertEqual(plan.reviewDecision, .keptAsIs, "die zweite (falsche) Decision darf die erste nicht ueberschreiben")
    }

    // MARK: - Blockhistorie bleibt erhalten

    func testCompletingTwoBlocksInSequenceKeepsBothInHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        try context.save()

        let block1Start = FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc)
        FourWeekReviewDueStatus.completeCurrentBlock(
            for: plan, expectedBlockStart: block1Start, decision: .keptAsIs,
            shownReview: stubReview(), now: d(2024, 2, 1), calendar: utc, in: context
        )

        let block2Start = FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc)
        XCTAssertEqual(block2Start, d(2024, 2, 2))
        FourWeekReviewDueStatus.completeCurrentBlock(
            for: plan, expectedBlockStart: block2Start, decision: .actionTaken,
            shownReview: stubReview(), now: d(2024, 3, 20), calendar: utc, in: context
        )

        let history = FourWeekReviewDueStatus.history(for: plan)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].blockStart, d(2024, 1, 1))
        XCTAssertEqual(history[0].completedAt, d(2024, 2, 1))
        XCTAssertEqual(history[0].decision, .keptAsIs)
        XCTAssertEqual(history[1].blockStart, d(2024, 2, 2))
        XCTAssertEqual(history[1].completedAt, d(2024, 3, 20))
        XCTAssertEqual(history[1].decision, .actionTaken)

        // Altfelder spiegeln den JEWEILS LETZTEN Abschluss (Rückwärtskompatibilität).
        XCTAssertEqual(plan.reviewCompletedAt, d(2024, 3, 20))
        XCTAssertEqual(plan.reviewDecision, .actionTaken)

        // Ein alter Abschluss ändert sich nicht rückwirkend.
        XCTAssertEqual(history[0].decision, .keptAsIs, "Block 1 bleibt unveraendert, auch nachdem Block 2 abgeschlossen wurde")
    }

    /// Ein Plan, dessen einziger Abschluss noch aus der Zeit vor diesem
    /// Feature stammt (reine `reviewCompletedAt`/`reviewDecisionRaw`-Felder,
    /// P7), bekommt beim Lesen GENAU EINEN nachgebildeten Eintrag — ohne
    /// einen erfundenen gezeigten Befund.
    func testLegacyCompletionWithoutHistoryJSONIsReadAsOneRecordWithoutFabricatedOutcome() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Alt-Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        plan.reviewCompletedAt = d(2024, 2, 1)
        plan.reviewDecision = .keptAsIs
        context.insert(plan)
        try context.save()

        let history = FourWeekReviewDueStatus.history(for: plan)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].blockStart, d(2024, 1, 1))
        XCTAssertEqual(history[0].completedAt, d(2024, 2, 1))
        XCTAssertEqual(history[0].decision, .keptAsIs)
        XCTAssertNil(history[0].shownOutcome, "der frueher gezeigte Befund wurde nie gespeichert und darf nicht erfunden werden")
        XCTAssertNil(history[0].shownDataGaps)

        // Der naechste Block baut korrekt auf diesem migrierten Eintrag auf.
        XCTAssertEqual(FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc), d(2024, 2, 2))
        XCTAssertEqual(FourWeekReviewDueStatus.intervalDays(for: plan), FourWeekReviewDueCalculator.subsequentBlockIntervalDays)
    }

    // MARK: - Mehrere aktive Pläne: jeweils eigener, unabhängiger Status

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

    /// Jeder Plan behält seine EIGENE Blockhistorie und seinen eigenen
    /// Fälligkeitsstatus — der Abschluss des einen darf den anderen nicht
    /// beeinflussen, auch nicht über mehrere Blöcke hinweg.
    func testEachActivePlanKeepsItsOwnBlockHistoryAndStatusIndependently() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let planA = TrainingPlan(name: "A", programType: "custom", isActive: true)
        planA.activatedAt = d(2024, 1, 1)
        let planB = TrainingPlan(name: "B", programType: "custom", isActive: true)
        planB.activatedAt = d(2024, 1, 1)
        context.insert(planA)
        context.insert(planB)
        try context.save()

        let planABlockStart = FourWeekReviewDueStatus.currentBlockStart(for: planA, calendar: utc)
        FourWeekReviewDueStatus.completeCurrentBlock(
            for: planA, expectedBlockStart: planABlockStart, decision: .keptAsIs,
            shownReview: stubReview(), now: d(2024, 2, 1), calendar: utc, in: context
        )

        // Plan A ist abgeschlossen (naechster Block laeuft, noch nicht
        // faellig), Plan B weiterhin faellig -> die Aggregation darf Plan
        // As Abschluss nicht auf Plan B uebertragen.
        XCTAssertTrue(FourWeekReviewDueStatus.isAnyDue(among: [planA, planB], now: d(2024, 2, 1), calendar: utc))
        guard case .notYetDue = FourWeekReviewDueStatus.state(for: planA, in: context, now: d(2024, 2, 1), calendar: utc) else {
            return XCTFail("Plan As naechster Block sollte direkt nach Abschluss noch nicht faellig sein")
        }
        guard case .due = FourWeekReviewDueStatus.state(for: planB, in: context, now: d(2024, 2, 1), calendar: utc) else {
            return XCTFail("Plan B sollte weiterhin faellig sein")
        }
        XCTAssertEqual(FourWeekReviewDueStatus.history(for: planA).count, 1)
        XCTAssertEqual(FourWeekReviewDueStatus.history(for: planB).count, 0, "Plan B hat nie abgeschlossen")
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
