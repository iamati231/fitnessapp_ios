#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
import FitnessAppCore
import FitnessAppData
@testable import FitnessAppUI

/// TestFlight-Crash (Build 164): `DashboardView.nextScheduledDay(in:)` zaehlte
/// bisher ueber die globale `completedSessions`-Query +
/// `$0.day?.plan?.persistentModelID` — das liest `.plan` auf einem
/// `TrainingDay`, das nur ueber die RUECKWAERTIGE `WorkoutSession.day`-
/// Relationship erreicht wird. Zeigt diese Relationship auf einen bereits
/// geloeschten Tag (z.B. Bestandsdaten von vor der `TrainingDay.sessions`-
/// Nullify-Inverse-Korrektur), bricht SwiftData beim Lesen JEDER Property
/// dieses Tages fatal ab (`_InvalidFutureBackingData`, siehe
/// `docs/TESTFLIGHT_CRASH_164.md`) — nicht per `try?`/optionalem Verketten
/// abfangbar, deshalb bewusst KEIN Test, der diesen Absturz tatsaechlich
/// auszuloesen versucht (wuerde den ganzen `swift test`-Prozess mitreissen).
/// Stattdessen: Nachweis, dass die neue Implementierung (Vorwaerts-Traversal
/// `plan.days` -> `day.sessions`) (a) bei unbeschaedigten Daten dasselbe
/// Ergebnis liefert wie zuvor und (b) eine verwaiste, nicht mehr erreichbare
/// Session niemals beruehrt — simuliert durch einen bereits geloeschten
/// Plan mit einer abgeschlossenen Session, DANEBEN ein zweiter, lebender
/// Plan, dessen `nextScheduledDay` berechnet wird.
///
/// Datei-basierter Store + Container-Neuoeffnung (nicht nur In-Memory) —
/// siehe `TrainingDayContentSnapshotWriterTests`-Typ-Dokumentation: nur so
/// ist sichergestellt, dass das Verhalten auch nach einem echten
/// Prozess-Neustart (Kaltstart mit vorhandener Datenbank) gilt, nicht nur
/// innerhalb desselben In-Memory-Objektgraphen.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class DashboardNextScheduledDayTests: XCTestCase {

    private func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testOrphanedSessionFromADeletedPlanNeverAffectsAnUnrelatedLivePlan() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dashboard-next-scheduled-day-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        // Schreibphase: eigener Scope, Container faellt danach weg.
        do {
            let schema = Schema(AppSchema.types)
            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: schema, configurations: config)
            let context = container.mainContext

            // Plan A: wird nach einer abgeschlossenen Session wieder
            // geloescht — cascaded ueber TrainingPlan.days (.cascade) auf
            // ihren einen Tag; dessen `sessions`-Inverse (.nullify) soll die
            // Session A's `day`-Referenz dabei auf nil setzen.
            let planA = TrainingPlan(name: "Alt-Plan", programType: "custom", isActive: false)
            context.insert(planA)
            let dayA = TrainingDay(name: "Tag A", weekday: 2, type: .chest, plan: planA)
            context.insert(dayA)
            let sessionA = WorkoutSession(
                startTime: d(2024, 1, 1), endTime: d(2024, 1, 1).addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, isCompleted: true, day: dayA
            )
            context.insert(sessionA)
            try context.save()

            context.delete(planA)
            try context.save()

            // Plan B: unabhaengig, lebend, zwei Tage, keine Sessions.
            let planB = TrainingPlan(name: "Lebender Plan", programType: "custom", isActive: true)
            context.insert(planB)
            let dayB1 = TrainingDay(name: "Tag B1", weekday: 2, type: .chest, plan: planB)
            context.insert(dayB1)
            let dayB2 = TrainingDay(name: "Tag B2", weekday: 3, type: .back, plan: planB)
            context.insert(dayB2)
            try context.save()
        }

        // Lesephase: frischer Container, dieselbe Datei-URL — simuliert den
        // Kaltstart, der den Absturz in Build 164 ausgeloest hat.
        let schema = Schema(AppSchema.types)
        let reopenConfig = ModelConfiguration(url: storeURL)
        let reopenedContainer = try ModelContainer(for: schema, configurations: reopenConfig)
        let reopenedContext = reopenedContainer.mainContext

        // Die verwaiste Session muss weiterhin existieren (sie wurde NICHT
        // geloescht, nur ihr Tag) — sonst waere der Testfall gegenstandslos.
        let allSessions = try reopenedContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(allSessions.count, 1, "die Session von Plan A darf durch dessen Loeschung nicht mitgeloescht werden")

        let livePlans = try reopenedContext.fetch(
            FetchDescriptor<TrainingPlan>(predicate: #Predicate<TrainingPlan> { $0.isActive == true })
        )
        guard let planB = livePlans.first else {
            return XCTFail("Plan B muss den Store-Neustart ueberstehen")
        }
        XCTAssertEqual(planB.days.count, 2)

        // Der eigentliche Nachweis: `nextScheduledDay` darf hier NICHT
        // abstuerzen und muss, da Plan B keine eigenen abgeschlossenen
        // Sessions hat, auf den ersten (Montag-first-sortierten) Tag zeigen —
        // exakt das Verhalten vor diesem Fund, nur ohne den gefaehrlichen
        // Zugriffspfad.
        let dashboard = DashboardView()
        let next = dashboard.nextScheduledDay(in: planB)
        XCTAssertEqual(next.name, "Tag B1")
    }

    func testCompletedSessionsOnlyCountForTheirOwnPlanAndAdvanceTheRotation() throws {
        let container = try ModelContainer(
            for: Schema(AppSchema.types),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let plan = TrainingPlan(name: "Push/Pull", programType: "custom", isActive: true)
        context.insert(plan)
        let day1 = TrainingDay(name: "Push", weekday: 2, type: .chest, plan: plan)
        context.insert(day1)
        let day2 = TrainingDay(name: "Pull", weekday: 4, type: .back, plan: plan)
        context.insert(day2)
        let day3 = TrainingDay(name: "Legs", weekday: 6, type: .legs, plan: plan)
        context.insert(day3)

        // Ein zweiter, unabhaengiger Plan mit eigener abgeschlossener Session
        // darf die Rotation von `plan` nicht beeinflussen.
        let otherPlan = TrainingPlan(name: "Anderer Plan", programType: "custom", isActive: true)
        context.insert(otherPlan)
        let otherDay = TrainingDay(name: "Anderer Tag", weekday: 2, type: .chest, plan: otherPlan)
        context.insert(otherDay)
        context.insert(WorkoutSession(
            startTime: d(2024, 1, 1), endTime: d(2024, 1, 1).addingTimeInterval(3600),
            durationMinutes: 60, exerciseCount: 1, isCompleted: true, day: otherDay
        ))

        context.insert(WorkoutSession(
            startTime: d(2024, 1, 2), endTime: d(2024, 1, 2).addingTimeInterval(3600),
            durationMinutes: 60, exerciseCount: 1, isCompleted: true, day: day1
        ))
        try context.save()

        let dashboard = DashboardView()
        let next = dashboard.nextScheduledDay(in: plan)
        XCTAssertEqual(next.name, "Pull", "genau eine abgeschlossene Session fuer `plan` muss die Rotation exakt einen Schritt weiterstellen")
    }

    // MARK: - Task #252: DashboardView.owningPlan (Resume-Tile-Faelle)

    /// Dieselbe Regression wie oben, jetzt fuer `owningPlan(forSessionID:in:)`
    /// — den gemeinsamen Vorwaerts-Helfer hinter `resumeAnyOpenFromConflict`,
    /// `unrepresentedOpenSession` und `resumeOpenSession` (alle drei lesen
    /// `openSessions`, eine APP-WEITE `@Query`, strukturell derselbe Zugriff
    /// wie `completedSessions` im urspruenglichen Crash). Die drei Funktionen
    /// selbst sind `private`/`@Environment`-gebunden und ohne echten
    /// View-/UI-Test-Harness (siehe `DayEditorPersistenceTests`-Dokumentation)
    /// nicht direkt testbar — deshalb hier, wie bei `nextScheduledDay`, die
    /// zugrundeliegende, bewusst Environment-freie Funktion direkt.
    func testOwningPlanNeverTouchesAnOrphanedSessionsDayAfterARealStoreRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dashboard-owning-plan-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        }

        do {
            let container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
            let context = container.mainContext

            let deletedPlan = TrainingPlan(name: "Alt-Plan", programType: "custom", isActive: false)
            context.insert(deletedPlan)
            let deletedDay = TrainingDay(name: "Alter Tag", weekday: 2, type: .chest, plan: deletedPlan)
            context.insert(deletedDay)
            let orphanSession = WorkoutSession(
                startTime: d(2024, 1, 1), endTime: d(2024, 1, 1).addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, isCompleted: false, day: deletedDay
            )
            context.insert(orphanSession)
            try context.save()

            context.delete(deletedPlan)
            try context.save()

            let planB = TrainingPlan(name: "Lebender Plan", programType: "custom", isActive: true)
            context.insert(planB)
            let dayB = TrainingDay(name: "Tag B", weekday: 2, type: .chest, plan: planB)
            context.insert(dayB)
            let sessionB = WorkoutSession(
                startTime: d(2024, 1, 2), endTime: d(2024, 1, 2).addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, isCompleted: false, day: dayB
            )
            context.insert(sessionB)
            try context.save()
        }

        let reopened = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(url: storeURL))
        let context = reopened.mainContext

        let openSessions = try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == false }
        ))
        XCTAssertEqual(openSessions.count, 2, "beide offenen Sessions (auch die verwaiste) muessen den Store-Neustart ueberstehen")

        let allPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        XCTAssertEqual(allPlans.count, 1, "der geloeschte Plan darf nicht mehr existieren")

        for session in openSessions {
            // Der eigentliche Nachweis: kein Absturz fuer KEINE der beiden
            // Sessions — weder fuer die verwaiste (muss `nil` liefern) noch
            // fuer die echte (muss den lebenden Plan liefern).
            let owner = DashboardView.owningPlan(forSessionID: session.persistentModelID, in: allPlans)
            if session.startTime == d(2024, 1, 1) {
                XCTAssertNil(owner, "die verwaiste Session darf keinem Plan gutgeschrieben werden")
            } else {
                XCTAssertEqual(owner?.name, "Lebender Plan")
            }
        }
    }
}
#endif
