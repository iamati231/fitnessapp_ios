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
    /// bewertet, nicht die "erster Plan nach Name"-Vereinfachung. "Alpha"
    /// (ein Trainingstag, deutlich verfehlte Teilnahme) sortiert alphabetisch
    /// VOR "Beta" (gar keine Trainingstage — `.notReliablyEvaluable`, nie
    /// faelschlich als `keepAsIs`-Erfolg gewertet). Ohne die explizite
    /// Auswahl würde dieser Test fälschlich Alphas Befund zeigen.
    ///
    /// Bewusst OHNE `WorkoutSession`: `realOccurrences(in:)` liest ALLE
    /// Sessions der Datenbank global, unabhaengig vom Plan (dokumentierte
    /// Einschraenkung, `WorkoutSession` hat keine stabile Plan-Referenz) —
    /// Sessions fuer EINEN der beiden Pläne würden fälschlich auch in die
    /// Teilnahme-Auswertung des JEWEILS ANDEREN einfliessen und die
    /// eigentliche Prüfung dieses Tests (wird der richtige Plan STRUKTURELL
    /// ausgewählt) verdecken. Dieser Test prüft die Auswahl, nicht die
    /// (separat bereits dokumentierte) Session-Zuordnungs-Einschränkung.
    func testAssembleForExplicitPlanUsesThatPlansParticipationNotTheAlphabeticallyFirst() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let alpha = TrainingPlan(name: "Alpha", programType: "custom", isActive: true)
        alpha.activatedAt = d(2024, 1, 1)
        context.insert(alpha)
        context.insert(TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: alpha))

        // "Beta" hat bewusst KEINEN Trainingstag -> strukturell von Alpha
        // unterscheidbar, ohne auf globale Sessions angewiesen zu sein.
        let beta = TrainingPlan(name: "Beta", programType: "custom", isActive: true)
        beta.activatedAt = d(2024, 1, 1)
        context.insert(beta)
        try context.save()

        // Ohne explizite Auswahl: "Alpha" (erster nach Name), keine
        // Sessions -> deutlich verfehlte Teilnahme.
        let defaultReview = FourWeekReviewAssembler.assemble(in: context, now: d(2024, 2, 1), calendar: utc)
        guard case .concernsFound = defaultReview.outcome else {
            return XCTFail("Default-Auswahl sollte weiterhin Alpha (verfehlte Teilnahme) liefern: \(defaultReview.outcome)")
        }

        // Mit expliziter Auswahl von "Beta": keine Trainingstage -> nicht
        // auswertbar, NIE faelschlich als Erfolg (`keepAsIs` OHNE Datenlücke)
        // interpretiert.
        let betaReview = FourWeekReviewAssembler.assemble(in: context, for: beta, now: d(2024, 2, 1), calendar: utc)
        XCTAssertEqual(betaReview.outcome, .keepAsIs, "kein Befund erfindbar ohne jede Trainingstag-Grundlage")
        XCTAssertTrue(
            betaReview.dataGaps.contains(.participationNotReliablyEvaluable(.planHasNoTrainingDays)),
            "Betas fehlende Trainingstage müssen als Datenlücke sichtbar sein, nicht stillschweigend als Erfolg gelten: \(betaReview.dataGaps)"
        )
    }

    // MARK: - Nachbesserung: echte Session-Zuordnung statt globalem Topf

    /// Echter Regressionstest für den vom Nutzer korrigierten Fund: anders
    /// als der strukturelle Auswahltest oben (bewusst OHNE Sessions) belegt
    /// DIESER Test die eigentliche Teilnahme-Isolation mit ECHTEN, über
    /// `day:` zugeordneten Sessions — genau wie `DayEditorView`/
    /// `DashboardView` sie beim echten Workout-Start erzeugen. Plan Bs
    /// Sessions dürfen Plan As Auswertung nicht mehr verfälschen (vorher:
    /// `realOccurrences` las global, ohne Plan-Filter).
    func testParticipationIsIsolatedPerPlanWhenBothPlansHaveRealSessions() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let planA = TrainingPlan(name: "Alpha", programType: "custom", isActive: true)
        planA.activatedAt = d(2024, 1, 1)
        context.insert(planA)
        let dayA = TrainingDay(name: "Ganzkörper A", weekday: 2, type: .fullBody, plan: planA)
        context.insert(dayA)

        let planB = TrainingPlan(name: "Beta", programType: "custom", isActive: true)
        planB.activatedAt = d(2024, 1, 1)
        context.insert(planB)
        let dayB = TrainingDay(name: "Ganzkörper B", weekday: 2, type: .fullBody, plan: planB)
        context.insert(dayB)

        // Plan A: 4 abgeschlossene Sessions -> volle Teilnahme.
        for offset in [0, 7, 14, 21] {
            let date = utc.date(byAdding: .day, value: offset, to: d(2024, 1, 2))!
            context.insert(WorkoutSession(
                startTime: date, endTime: date.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 0,
                totalVolumeKg: 0, isCompleted: true, day: dayA
            ))
        }
        // Plan B: deutlich MEHR Sessions als A — würden sie faelschlich in
        // As Auswertung einfliessen, waere As Teilnahme nicht mehr "genau
        // erfuellt", sondern "ueberschuessig"/verzerrt.
        for offset in [0, 3, 7, 10, 14, 17, 21, 24] {
            let date = utc.date(byAdding: .day, value: offset, to: d(2024, 1, 2))!
            context.insert(WorkoutSession(
                startTime: date, endTime: date.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 0,
                totalVolumeKg: 0, isCompleted: true, day: dayB
            ))
        }
        try context.save()

        let reviewA = FourWeekReviewAssembler.assemble(in: context, for: planA, now: d(2024, 2, 1), calendar: utc)
        guard case .evaluated(let summaryA) = reviewA.participation else {
            return XCTFail("Plan A haette auswertbar sein muessen: \(reviewA.participation)")
        }
        XCTAssertEqual(summaryA.completedCount, 4, "nur As eigene 4 Sessions, nicht Bs 8")
        XCTAssertEqual(summaryA.plannedCount, 4)
        XCTAssertEqual(summaryA.missedCount, 0)
        XCTAssertEqual(summaryA.extraOccurrenceCount, 0, "Bs Sessions duerfen bei A nicht als Ueberschuss auftauchen")

        let reviewB = FourWeekReviewAssembler.assemble(in: context, for: planB, now: d(2024, 2, 1), calendar: utc)
        guard case .evaluated(let summaryB) = reviewB.participation else {
            return XCTFail("Plan B haette auswertbar sein muessen: \(reviewB.participation)")
        }
        XCTAssertEqual(summaryB.completedCount, 4, "flexible Kadenz: nur die ersten 4 faelligen Tage zaehlen, nicht alle 8 geloggten")
        XCTAssertFalse(
            summaryB.dataGaps.contains(.unattributableHistoryExcludedDueToMultipleActivePlans),
            "alle Bs Sessions sind ueber day.plan korrekt zugeordnet, nichts wurde ausgeschlossen"
        )
    }

    /// Echtes Ad-hoc-Training (ephemerer Tag ohne Plan, `day.plan == nil`,
    /// exakt wie `DashboardView.startAdHocWorkout` ihn erzeugt) zählt
    /// weiterhin für JEDEN aktiven Plan mit — das ist keine Regression,
    /// sondern eine bewusst beibehaltene Produktregel ("frei trainiert ist
    /// auch trainiert").
    func testAdHocSessionsStillCountTowardEveryActivePlanWithMultiplePlansActive() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let planA = TrainingPlan(name: "Alpha", programType: "custom", isActive: true)
        planA.activatedAt = d(2024, 1, 1)
        context.insert(planA)
        context.insert(TrainingDay(name: "Tag A", weekday: 2, type: .fullBody, plan: planA))

        let planB = TrainingPlan(name: "Beta", programType: "custom", isActive: true)
        planB.activatedAt = d(2024, 1, 1)
        context.insert(planB)
        context.insert(TrainingDay(name: "Tag B", weekday: 2, type: .fullBody, plan: planB))

        let adHocDay = TrainingDay(name: "Spontanes Training", weekday: 2, type: .custom, plan: nil)
        context.insert(adHocDay)
        for offset in [0, 7, 14, 21] {
            let date = utc.date(byAdding: .day, value: offset, to: d(2024, 1, 2))!
            context.insert(WorkoutSession(
                startTime: date, endTime: date.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 0,
                totalVolumeKg: 0, isCompleted: true, isAdHoc: true, day: adHocDay
            ))
        }
        try context.save()

        for plan in [planA, planB] {
            let review = FourWeekReviewAssembler.assemble(in: context, for: plan, now: d(2024, 2, 1), calendar: utc)
            guard case .evaluated(let summary) = review.participation else {
                return XCTFail("\(plan.name) haette auswertbar sein muessen: \(review.participation)")
            }
            XCTAssertEqual(summary.completedCount, 4, "Ad-hoc-Training zaehlt fuer \(plan.name) mit")
        }
    }

    /// Sessions OHNE jede Tag-Referenz (`day == nil` direkt, z.B. aus einem
    /// CSV-Import/Restore oder einem seither geloeschten/regenerierten Tag)
    /// lassen sich bei zwei gleichzeitig aktiven Plänen keinem der beiden
    /// zuverlässig zuordnen. Sie dürfen weder geraten noch stillschweigend
    /// irgendeinem Plan gutgeschrieben werden — stattdessen ausgeschlossen
    /// UND als Datenlücke offen ausgewiesen.
    func testSessionsWithoutAnyDayReferenceAreExcludedAndDisclosedWhenMultiplePlansActive() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let planA = TrainingPlan(name: "Alpha", programType: "custom", isActive: true)
        planA.activatedAt = d(2024, 1, 1)
        context.insert(planA)
        context.insert(TrainingDay(name: "Tag A", weekday: 2, type: .fullBody, plan: planA))

        let planB = TrainingPlan(name: "Beta", programType: "custom", isActive: true)
        planB.activatedAt = d(2024, 1, 1)
        context.insert(planB)
        context.insert(TrainingDay(name: "Tag B", weekday: 2, type: .fullBody, plan: planB))

        // Simuliert einen CSV-Import/Restore: `day` wird dort nie gesetzt.
        let orphanDate = d(2024, 1, 2)
        context.insert(WorkoutSession(
            startTime: orphanDate, endTime: orphanDate.addingTimeInterval(3600),
            durationMinutes: 60, exerciseCount: 1, totalSets: 0,
            totalVolumeKg: 0, isCompleted: true
        ))
        try context.save()

        let reviewA = FourWeekReviewAssembler.assemble(in: context, for: planA, now: d(2024, 2, 1), calendar: utc)
        guard case .evaluated(let summaryA) = reviewA.participation else {
            return XCTFail("Plan A haette auswertbar sein muessen: \(reviewA.participation)")
        }
        XCTAssertEqual(summaryA.completedCount, 0, "nicht zuordenbare Session darf A nicht stillschweigend gutgeschrieben werden")
        XCTAssertTrue(summaryA.dataGaps.contains(.unattributableHistoryExcludedDueToMultipleActivePlans))

        let reviewB = FourWeekReviewAssembler.assemble(in: context, for: planB, now: d(2024, 2, 1), calendar: utc)
        guard case .evaluated(let summaryB) = reviewB.participation else {
            return XCTFail("Plan B haette auswertbar sein muessen: \(reviewB.participation)")
        }
        XCTAssertEqual(summaryB.completedCount, 0, "nicht zuordenbare Session darf auch B nicht stillschweigend gutgeschrieben werden")
        XCTAssertTrue(summaryB.dataGaps.contains(.unattributableHistoryExcludedDueToMultipleActivePlans))
    }

    /// Gegenprobe zum vorigen Test: bei nur EINEM aktiven Plan besteht keine
    /// Mehrdeutigkeit — dieselbe Session ohne Tag-Referenz zaehlt wie bisher
    /// fuer den einen Plan, ohne Ausschluss/Datenlücke.
    func testSessionsWithoutAnyDayReferenceStillCountWithOnlyOneActivePlan() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Alpha", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        context.insert(TrainingDay(name: "Tag A", weekday: 2, type: .fullBody, plan: plan))

        let orphanDate = d(2024, 1, 2)
        context.insert(WorkoutSession(
            startTime: orphanDate, endTime: orphanDate.addingTimeInterval(3600),
            durationMinutes: 60, exerciseCount: 1, totalSets: 0,
            totalVolumeKg: 0, isCompleted: true
        ))
        try context.save()

        let review = FourWeekReviewAssembler.assemble(in: context, for: plan, now: d(2024, 2, 1), calendar: utc)
        guard case .evaluated(let summary) = review.participation else {
            return XCTFail("haette auswertbar sein muessen: \(review.participation)")
        }
        XCTAssertEqual(summary.completedCount, 1, "bei nur einem aktiven Plan besteht keine Zuordnungs-Mehrdeutigkeit")
        XCTAssertFalse(summary.dataGaps.contains(.unattributableHistoryExcludedDueToMultipleActivePlans))
    }

    // MARK: - Task #252 (TestFlight-Crash-Audit): echte verwaiste Tag-Referenz

    /// Regression fuer den Build-164-Fund (`docs/TESTFLIGHT_CRASH_164.md`),
    /// angewendet auf `realOccurrences` (damals betraf er nur
    /// `DashboardView.nextScheduledDay`): ein Plan samt Tag wird ECHT
    /// geloescht (nicht nur `day: nil` konstruiert wie in den beiden Tests
    /// oben), seine Session bleibt bestehen — exakt wie
    /// `DashboardNextScheduledDayTests.testOrphanedSessionFromADeletedPlan-
    /// NeverAffectsAnUnrelatedLivePlan`. Datei-basierter Store +
    /// Container-Neuoeffnung (echter Kaltstart-Nachbau, kein In-Memory-
    /// Artefakt), damit das Verhalten unabhaengig davon gilt, ob SwiftDatas
    /// Nullify-Inverse die Session-Referenz beim Loeschen tatsaechlich auf
    /// `nil` gesetzt hat oder (wie auf einem Bestandsgeraet vor Build 164)
    /// nicht — `realOccurrences` liest `.day`/`.plan` dieser Session in
    /// KEINEM der beiden Faelle mehr rueckwaerts, daher ist das Ergebnis in
    /// beiden Faellen identisch und abstuerzt nie.
    func testOrphanedSessionFromADeletedPlanCountsTowardTheSoleSurvivingActivePlanAfterARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("four-week-review-orphaned-session-single-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let deletedPlan = TrainingPlan(name: "Geloeschter Plan", programType: "custom", isActive: false)
            context.insert(deletedPlan)
            let deletedDay = TrainingDay(name: "Alter Tag", weekday: 2, type: .chest, plan: deletedPlan)
            context.insert(deletedDay)
            let orphanDate = d(2024, 1, 2)
            context.insert(WorkoutSession(
                startTime: orphanDate, endTime: orphanDate.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 0,
                totalVolumeKg: 0, isCompleted: true, day: deletedDay
            ))
            try context.save()

            context.delete(deletedPlan)
            try context.save()

            let survivingPlan = TrainingPlan(name: "Lebender Plan", programType: "custom", isActive: true)
            survivingPlan.activatedAt = d(2024, 1, 1)
            context.insert(survivingPlan)
            context.insert(TrainingDay(name: "Eigener Tag", weekday: 2, type: .fullBody, plan: survivingPlan))
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let context = reopened.mainContext

        let allSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(allSessions.count, 1, "die Session des geloeschten Plans darf durch dessen Loeschung nicht mitgeloescht werden")

        let livePlans = try context.fetch(FetchDescriptor<TrainingPlan>(predicate: #Predicate<TrainingPlan> { $0.isActive == true }))
        guard let survivingPlan = livePlans.first else {
            return XCTFail("der lebende Plan muss den Store-Neustart ueberstehen")
        }

        // Der eigentliche Nachweis: kein Absturz, UND dieselbe Behandlung wie
        // eine Session ganz ohne Tag-Referenz (siehe Test oben) — zaehlt bei
        // nur einem aktiven Plan mit, keine Datenluecke.
        let review = FourWeekReviewAssembler.assemble(in: context, for: survivingPlan, now: d(2024, 2, 1), calendar: utc)
        guard case .evaluated(let summary) = review.participation else {
            return XCTFail("haette auswertbar sein muessen: \(review.participation)")
        }
        XCTAssertEqual(summary.completedCount, 1, "verwaiste Session zaehlt bei nur einem aktiven Plan wie Ad-hoc-Training mit")
        XCTAssertFalse(summary.dataGaps.contains(.unattributableHistoryExcludedDueToMultipleActivePlans))
    }

    /// Gegenprobe zum vorigen Test, diesmal mit ZWEI gleichzeitig aktiven
    /// Plaenen nach dem Store-Neustart: dieselbe echte Altreferenz auf einen
    /// geloeschten Plan/Tag darf keinem der beiden stillschweigend
    /// gutgeschrieben werden — ausgeschlossen und als Datenluecke offen
    /// ausgewiesen, identisch zu `testSessionsWithoutAnyDayReferenceAre-
    /// ExcludedAndDisclosedWhenMultiplePlansActive`.
    func testOrphanedSessionFromADeletedPlanIsExcludedAndDisclosedWithMultiplePlansActiveAfterARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("four-week-review-orphaned-session-multi-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let deletedPlan = TrainingPlan(name: "Geloeschter Plan", programType: "custom", isActive: false)
            context.insert(deletedPlan)
            let deletedDay = TrainingDay(name: "Alter Tag", weekday: 2, type: .chest, plan: deletedPlan)
            context.insert(deletedDay)
            let orphanDate = d(2024, 1, 2)
            context.insert(WorkoutSession(
                startTime: orphanDate, endTime: orphanDate.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 0,
                totalVolumeKg: 0, isCompleted: true, day: deletedDay
            ))
            try context.save()

            context.delete(deletedPlan)
            try context.save()

            let planA = TrainingPlan(name: "Alpha", programType: "custom", isActive: true)
            planA.activatedAt = d(2024, 1, 1)
            context.insert(planA)
            context.insert(TrainingDay(name: "Tag A", weekday: 2, type: .fullBody, plan: planA))

            let planB = TrainingPlan(name: "Beta", programType: "custom", isActive: true)
            planB.activatedAt = d(2024, 1, 1)
            context.insert(planB)
            context.insert(TrainingDay(name: "Tag B", weekday: 2, type: .fullBody, plan: planB))
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let context = reopened.mainContext

        let livePlans = try context.fetch(FetchDescriptor<TrainingPlan>(predicate: #Predicate<TrainingPlan> { $0.isActive == true }))
        XCTAssertEqual(livePlans.count, 2, "beide ueberlebenden Plaene muessen den Store-Neustart ueberstehen")

        for plan in livePlans {
            let review = FourWeekReviewAssembler.assemble(in: context, for: plan, now: d(2024, 2, 1), calendar: utc)
            guard case .evaluated(let summary) = review.participation else {
                return XCTFail("\(plan.name) haette auswertbar sein muessen: \(review.participation)")
            }
            XCTAssertEqual(summary.completedCount, 0, "verwaiste Session darf \(plan.name) bei mehreren aktiven Plaenen nicht stillschweigend gutgeschrieben werden")
            XCTAssertTrue(summary.dataGaps.contains(.unattributableHistoryExcludedDueToMultipleActivePlans))
        }
    }

    // MARK: - P8 Stufe 3: blockbezogener Zeitraum statt gesamter Planlaufzeit

    /// Kernregression für Paket B: nach Abschluss von Block 1 zählt die
    /// Teilnahme NUR NOCH seit Block 2s Beginn — nicht mehr seit
    /// `plan.activatedAt` über die gesamte Planlaufzeit. Eine Session, die
    /// klar in Block 1 fiel, darf Block 2s Auswertung nicht verfälschen.
    func testParticipationForASubsequentBlockCountsOnlySinceThatBlocksStartNotSinceActivation() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        let day = TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: plan)
        context.insert(day)
        try context.save()

        // Block 1 abgeschlossen am 1. Februar -> Block 2 beginnt am 2. Februar.
        // Durchgängig `calendar: utc` (wie `d(...)`), sonst waere dieser Test
        // von der lokalen Zeitzone der CI-Maschine abhängig (`.current`-Default).
        FourWeekReviewDueStatus.completeCurrentBlock(
            for: plan,
            expectedBlockStart: FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc),
            decision: .keptAsIs,
            shownReview: FourWeekReviewOrchestrator.Review(
                participation: .notReliablyEvaluable(.activationStartUnknown), outcome: .keepAsIs, dataGaps: []
            ),
            now: d(2024, 2, 1),
            calendar: utc,
            in: context
        )
        XCTAssertEqual(FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc), d(2024, 2, 2))

        // Vier abgeschlossene Sessions klar INNERHALB von Block 1 (Januar) —
        // duerfen fuer Block 2 nicht mitzaehlen.
        for offset in [1, 8, 15, 22] {
            let date = utc.date(byAdding: .day, value: offset, to: d(2024, 1, 1))!
            context.insert(WorkoutSession(
                startTime: date, endTime: date.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 0,
                totalVolumeKg: 0, isCompleted: true, day: day
            ))
        }
        try context.save()

        let reviewForBlock2 = FourWeekReviewAssembler.assemble(in: context, for: plan, now: d(2024, 3, 1), calendar: utc)
        guard case .evaluated(let summary) = reviewForBlock2.participation else {
            return XCTFail("Block 2 haette auswertbar sein muessen: \(reviewForBlock2.participation)")
        }
        XCTAssertEqual(summary.completedCount, 0, "Block 1s Sessions duerfen Block 2 nicht gutgeschrieben werden")
        XCTAssertEqual(summary.periodStart, d(2024, 2, 2), "Block 2 muss ab seinem EIGENEN Beginn ausgewertet werden")
    }

    /// Ein Check-in aus Block 1 zählt für Block 2 NICHT als aktuell — bleibt
    /// stattdessen eine sichtbare Datenlücke (`noCheckInYet`).
    func testCheckInFromAPreviousBlockDoesNotCountAsCurrentForTheNextBlock() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        let day = TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: plan)
        context.insert(day)
        try context.save()

        // Check-in klar innerhalb von Block 1.
        context.insert(PeriodicCheckIn(
            date: d(2024, 1, 20), hadComplaints: true, goalStillCurrent: false
        ))
        try context.save()

        FourWeekReviewDueStatus.completeCurrentBlock(
            for: plan,
            expectedBlockStart: FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc),
            decision: .keptAsIs,
            shownReview: FourWeekReviewOrchestrator.Review(
                participation: .notReliablyEvaluable(.activationStartUnknown), outcome: .keepAsIs, dataGaps: []
            ),
            now: d(2024, 2, 1),
            calendar: utc,
            in: context
        )

        // Vier abgeschlossene Sessions an allen vier Montagen INNERHALB von
        // Block 2 (2. Februar bis 1. Maerz) — ohne diese wuerde die
        // Teilnahme-Auswertung "0 von 4" melden und dieser Test faelschlich
        // einen `.participationBelowPlan`-Befund statt des hier eigentlich
        // untersuchten Check-in-Verhaltens zeigen. Isoliert so gezielt NUR
        // die Check-in-Zuordnung (siehe Testname).
        for date in [d(2024, 2, 5), d(2024, 2, 12), d(2024, 2, 19), d(2024, 2, 26)] {
            context.insert(WorkoutSession(
                startTime: date, endTime: date.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, totalSets: 0,
                totalVolumeKg: 0, isCompleted: true, day: day
            ))
        }
        try context.save()

        let reviewForBlock2 = FourWeekReviewAssembler.assemble(in: context, for: plan, now: d(2024, 3, 1), calendar: utc)
        XCTAssertEqual(reviewForBlock2.outcome, .keepAsIs, "das alte Block-1-Check-in darf fuer Block 2 keine Befunde ausloesen")
        XCTAssertTrue(
            reviewForBlock2.dataGaps.contains(.noCheckInYet),
            "ohne einen Check-in SEIT Block 2s Beginn muss das als Datenlücke sichtbar sein"
        )
    }

    /// Gegenprobe: ein Check-in NACH Block 2s Beginn zählt normal.
    func testCheckInWithinTheCurrentBlockStillCounts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "Plan", programType: "custom", isActive: true)
        plan.activatedAt = d(2024, 1, 1)
        context.insert(plan)
        context.insert(TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: plan))
        try context.save()

        FourWeekReviewDueStatus.completeCurrentBlock(
            for: plan,
            expectedBlockStart: FourWeekReviewDueStatus.currentBlockStart(for: plan, calendar: utc),
            decision: .keptAsIs,
            shownReview: FourWeekReviewOrchestrator.Review(
                participation: .notReliablyEvaluable(.activationStartUnknown), outcome: .keepAsIs, dataGaps: []
            ),
            now: d(2024, 2, 1),
            calendar: utc,
            in: context
        )

        // Check-in klar innerhalb von Block 2 (nach dem 2. Februar).
        context.insert(PeriodicCheckIn(
            date: d(2024, 2, 10), hadComplaints: true, goalStillCurrent: true
        ))
        try context.save()

        let reviewForBlock2 = FourWeekReviewAssembler.assemble(in: context, for: plan, now: d(2024, 3, 1), calendar: utc)
        XCTAssertFalse(reviewForBlock2.dataGaps.contains(.noCheckInYet))
        guard case .concernsFound(let concerns) = reviewForBlock2.outcome else {
            return XCTFail("das aktuelle Check-in haette einen Befund ausloesen muessen: \(reviewForBlock2.outcome)")
        }
        XCTAssertTrue(concerns.contains { if case .complaintsReported = $0 { return true }; return false })
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
