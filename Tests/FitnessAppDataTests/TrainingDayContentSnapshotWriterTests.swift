#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// P8-Vorbereitung, Paket B (`docs/P8_STUFE2_VERSIONIERUNG_PLAN.md`):
/// `WorkoutSession.contentSnapshotJSON` + `TrainingDayContentSnapshotWriter`.
/// Deckt die vom Auftrag benannten Kategorien ab: Roundtrip durch
/// SwiftData, Session-Isolation, Löschverhalten, Schutz vor Überschreiben
/// eines abgeschlossenen Snapshots.
///
/// **Container-Lifetime ist kein Implementierungsdetail, sondern Teil des
/// Testvertrags:** jeder Test hält seinen `ModelContainer` in einer
/// benannten `let`-Variable für die gesamte Testlaufzeit (über `Fixture`
/// bzw. direkt im Testkörper) — NIE `try makeContainer().mainContext` als
/// anonymen Ausdruck. Ein früherer Fassung dieser Datei nutzte genau dieses
/// Muster und stürzte auf Apple-CI reproduzierbar mit Signal 5 ab
/// (SwiftData-interner Precondition-Trap, `_SD_get_current_context_tsd`
/// lieferte `nil`); ein gezielter Kontrolltest (`ModelContainer` per
/// `withExtendedLifetime` gehalten) lief im selben CI-Lauf fehlerfrei
/// durch, während alle acht Tests mit dem alten Muster weiterhin
/// abstürzten — ein vorzeitig deallozierter `ModelContainer` ist die am
/// besten belegte Erklärung. Siehe docs/P8_STUFE2_VERSIONIERUNG_PLAN.md,
/// Abschnitt "Ergebnis Paket A+B", für die volle Diagnose-Historie.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class TrainingDayContentSnapshotWriterTests: XCTestCase {

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

    // MARK: - Fixture
    //
    // Hält den `ModelContainer` als eigenes Feld (nicht nur den daraus
    // gezogenen `ModelContext`) — siehe Typ-Dokumentation oben. Solange ein
    // `Fixture`-Wert lebt, lebt sein Container mit.

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let plan: TrainingPlan
        let day: TrainingDay
        let session: WorkoutSession
    }

    @discardableResult
    private func makeFixture(
        isCompleted: Bool = false,
        exerciseCount: Int = 2
    ) throws -> Fixture {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Push A", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        for i in 0..<exerciseCount {
            let exercise = Exercise(
                name: i == 0 ? "Bankdrücken" : "Kurzhantel-Rudern",
                exerciseTemplateID: UUID(), orderIndex: i, day: day
            )
            context.insert(exercise)
        }
        let session = WorkoutSession(
            startTime: d(2024, 1, 2), endTime: d(2024, 1, 2).addingTimeInterval(3600),
            durationMinutes: 60, exerciseCount: exerciseCount, isCompleted: isCompleted, day: day
        )
        context.insert(session)
        return Fixture(container: container, context: context, plan: plan, day: day, session: session)
    }

    // MARK: - Roundtrip durch SwiftData

    func testCaptureStoresAReadableSnapshotMatchingTheLiveDayAtCaptureTime() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        try context.save()

        XCTAssertEqual(fixture.session.contentSnapshotState, .notCaptured, "vor dem ersten capture gibt es noch keinen Snapshot")

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))

        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("nach capture muss ein lesbarer Snapshot vorliegen: \(fixture.session.contentSnapshotState)")
        }
        XCTAssertEqual(snapshot.exercises.count, 2)
        XCTAssertEqual(snapshot.exercises.map(\.nameSnapshot), ["Bankdrücken", "Kurzhantel-Rudern"])
        XCTAssertEqual(snapshot.dayNameSnapshot, "Push A")
        XCTAssertNotNil(fixture.session.contentSnapshotCapturedAt)
    }

    func testCaptureOnASessionWithoutADayDoesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(
            startTime: d(2024, 1, 2), endTime: d(2024, 1, 2).addingTimeInterval(1800),
            durationMinutes: 30, exerciseCount: 0, isCompleted: true, isAdHoc: true
        )
        context.insert(session)
        try context.save()

        XCTAssertFalse(TrainingDayContentSnapshotWriter.capture(for: session, in: context))
        XCTAssertEqual(session.contentSnapshotState, .notCaptured)
        XCTAssertNil(session.contentSnapshotCapturedAt)
    }

    func testCaptureOnADayWithNoActiveExercisesYieldsAValidEmptySnapshotNotAnError() throws {
        let fixture = try makeFixture(exerciseCount: 0)
        try fixture.context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: fixture.context))
        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("eine leere Übungsliste ist gültig, kein Fehler: \(fixture.session.contentSnapshotState)")
        }
        XCTAssertTrue(snapshot.exercises.isEmpty)
    }

    // MARK: - Session-Isolation

    func testTwoSessionsGetIndependentSnapshotsNeitherAffectsTheOther() throws {
        let fixtureA = try makeFixture(exerciseCount: 1)
        let fixtureB = try makeFixture(exerciseCount: 3)
        try fixtureA.context.save()
        try fixtureB.context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixtureA.session, in: fixtureA.context))
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixtureB.session, in: fixtureB.context))

        guard case .available(let snapshotA) = fixtureA.session.contentSnapshotState,
              case .available(let snapshotB) = fixtureB.session.contentSnapshotState else {
            return XCTFail("beide Sessions müssen unabhängig voneinander lesbare Snapshots haben")
        }
        XCTAssertEqual(snapshotA.exercises.count, 1)
        XCTAssertEqual(snapshotB.exercises.count, 3, "Bs Snapshot darf nicht von As Inhalt beeinflusst sein")
    }

    // MARK: - Schutz vor Überschreiben eines abgeschlossenen Snapshots

    func testCaptureAfterCompletionIsRejectedAndLeavesTheFrozenSnapshotUnchanged() throws {
        let fixture = try makeFixture(exerciseCount: 1)
        let context = fixture.context
        try context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))
        guard case .available(let originalSnapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("Erst-Aufnahme muss gelingen")
        }
        XCTAssertEqual(originalSnapshot.exercises.count, 1)

        // Session abschließen - der Snapshot ist ab jetzt eingefroren.
        fixture.session.isCompleted = true

        // Tag nachträglich ändern (z.B. über einen DayEditorView-Äquivalent-
        // Pfad): eine dritte Übung hinzufügen.
        let extra = Exercise(name: "Zusatzübung", exerciseTemplateID: UUID(), orderIndex: 5, day: fixture.day)
        context.insert(extra)
        try context.save()

        let captureAfterCompletionSucceeded = TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context)
        XCTAssertFalse(captureAfterCompletionSucceeded, "ein Schreibversuch nach Abschluss darf nicht gelingen")

        guard case .available(let afterAttempt) = fixture.session.contentSnapshotState else {
            return XCTFail("der eingefrorene Snapshot muss weiterhin lesbar bleiben")
        }
        XCTAssertEqual(afterAttempt, originalSnapshot, "der eingefrorene Snapshot darf sich durch den Versuch nicht verändert haben")
        XCTAssertEqual(afterAttempt.exercises.count, 1, "die nachträglich hinzugefügte Übung darf NICHT im Snapshot auftauchen")
    }

    // MARK: - Löschverhalten

    func testDeletingTheDayLeavesTheSnapshotFullyReadableWithNoGuessedPlanLink() throws {
        let fixture = try makeFixture(exerciseCount: 2)
        let context = fixture.context
        try context.save()
        TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context)
        fixture.session.isCompleted = true
        try context.save()

        context.delete(fixture.day)
        try context.save()

        XCTAssertNil(fixture.session.day, "die Plan-/Tag-Zuordnung fehlt danach ausdrücklich (nullify)")
        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("der Inhalts-Snapshot muss das Löschen des Tages unbeschadet überstehen")
        }
        XCTAssertEqual(snapshot.exercises.count, 2, "der historische Inhalt bleibt vollständig erhalten")
    }

    func testDeletingTheSessionRemovesItsSnapshotToo() throws {
        let fixture = try makeFixture(exerciseCount: 1)
        let context = fixture.context
        try context.save()
        TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context)
        try context.save()

        let sessionCountBefore = try context.fetchCount(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessionCountBefore, 1)

        context.delete(fixture.session)
        try context.save()

        let sessionCountAfter = try context.fetchCount(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessionCountAfter, 0, "der Snapshot ist ein Feld der Session und verschwindet automatisch mit ihr")
    }

    // MARK: - Lebenszyklus: niemals erneut aus dem Live-Tag lesen

    /// P8 Stufe-2, Vertragspunkt 1: ein zweiter `capture`-Aufruf auf einer
    /// bereits erfassten, noch offenen Session (z. B. versehentlich bei
    /// Wiederaufnahme) darf den bestehenden Snapshot NICHT durch den dann
    /// aktuellen Live-Tag ersetzen — auch nicht, wenn der Tag zwischendurch
    /// extern verändert wurde.
    func testCaptureNeverOverwritesAnAlreadyCapturedSnapshotEvenAfterExternalDayChange() throws {
        let fixture = try makeFixture(exerciseCount: 1)
        let context = fixture.context
        try context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))
        guard case .available(let originalSnapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("Erst-Aufnahme muss gelingen")
        }
        XCTAssertEqual(originalSnapshot.exercises.count, 1)

        // Externe Änderung am (noch offenen) Tag, z.B. ein Equipment-Swap.
        let externallyAdded = Exercise(name: "Extern hinzugefügt", exerciseTemplateID: UUID(), orderIndex: 9, day: fixture.day)
        context.insert(externallyAdded)
        try context.save()

        let secondCaptureSucceeded = TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context)
        XCTAssertFalse(secondCaptureSucceeded, "ein zweiter capture-Aufruf auf einer bereits erfassten Session ist ein No-Op")

        guard case .available(let afterSecondCall) = fixture.session.contentSnapshotState else {
            return XCTFail("der bestehende Snapshot muss weiterhin lesbar bleiben")
        }
        XCTAssertEqual(afterSecondCall, originalSnapshot, "der Stand darf sich durch den zweiten Aufruf nicht verändert haben")
        XCTAssertEqual(afterSecondCall.exercises.count, 1, "die extern hinzugefügte Übung darf NICHT übernommen werden")
    }

    // MARK: - Explizite In-Session-Änderung (Ad-hoc)

    func testRecordAdHocExerciseAddedAppendsOnlyTheGivenExerciseNotAnyExternalChange() throws {
        let fixture = try makeFixture(exerciseCount: 0)
        fixture.session.isAdHoc = true
        let context = fixture.context
        try context.save()
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))

        // Simuliert eine Mutation am Tag, die NICHT über den Ad-hoc-Writer-
        // Pfad lief (darf trotzdem nicht in den Snapshot einsickern).
        let bypassed = Exercise(name: "Bypass", exerciseTemplateID: UUID(), orderIndex: 0, day: fixture.day)
        context.insert(bypassed)

        let explicit = Exercise(name: "Kurzhantel-Curls", exerciseTemplateID: UUID(), orderIndex: 1, day: fixture.day)
        context.insert(explicit)
        try context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.recordAdHocExerciseAdded(explicit, to: fixture.session, in: context))

        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("Snapshot muss weiterhin lesbar sein")
        }
        XCTAssertEqual(snapshot.exercises.count, 1, "nur die EXPLIZIT übergebene Übung darf aufgenommen werden")
        XCTAssertEqual(snapshot.exercises.first?.nameSnapshot, "Kurzhantel-Curls")
    }

    func testRecordAdHocExerciseRemovedRemovesExactlyTheMatchingEntryEvenWithDuplicateNames() throws {
        let fixture = try makeFixture(exerciseCount: 0)
        fixture.session.isAdHoc = true
        let context = fixture.context
        try context.save()
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))

        let templateID = UUID()
        let first = Exercise(name: "Bankdrücken", exerciseTemplateID: templateID, orderIndex: 0, day: fixture.day)
        let second = Exercise(name: "Bankdrücken", exerciseTemplateID: templateID, orderIndex: 1, day: fixture.day)
        context.insert(first)
        context.insert(second)
        try context.save()
        XCTAssertTrue(TrainingDayContentSnapshotWriter.recordAdHocExerciseAdded(first, to: fixture.session, in: context))
        XCTAssertTrue(TrainingDayContentSnapshotWriter.recordAdHocExerciseAdded(second, to: fixture.session, in: context))

        XCTAssertTrue(TrainingDayContentSnapshotWriter.recordAdHocExerciseRemoved(first, from: fixture.session, in: context))

        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("Snapshot muss weiterhin lesbar sein")
        }
        XCTAssertEqual(snapshot.exercises.count, 1, "nur der erste, namensgleiche Eintrag darf entfernt werden")
        XCTAssertEqual(snapshot.exercises.first?.orderIndex, 1, "der zweite (ebenfalls 'Bankdrücken') bleibt erhalten")
    }

    func testRecordAdHocExerciseRejectedForNonAdHocSession() throws {
        let fixture = try makeFixture(exerciseCount: 1)
        let context = fixture.context
        try context.save()
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))

        let extra = Exercise(name: "Zusatz", exerciseTemplateID: UUID(), orderIndex: 5, day: fixture.day)
        context.insert(extra)
        try context.save()

        XCTAssertFalse(
            TrainingDayContentSnapshotWriter.recordAdHocExerciseAdded(extra, to: fixture.session, in: context),
            "eine Plan-Session hat kein ihr allein gehörendes Tag — recordAdHocExercise* darf hier nichts tun"
        )
        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("Snapshot muss weiterhin lesbar sein")
        }
        XCTAssertEqual(snapshot.exercises.count, 1, "unverändert gegenüber der Erst-Aufnahme")
    }

    func testRecordAdHocExerciseRejectedWhenNoSnapshotWasEverCaptured() throws {
        let fixture = try makeFixture(exerciseCount: 0)
        fixture.session.isAdHoc = true
        let context = fixture.context
        try context.save()
        // Bewusst KEIN capture()-Aufruf.

        let exercise = Exercise(name: "Erste Übung", exerciseTemplateID: UUID(), orderIndex: 0, day: fixture.day)
        context.insert(exercise)
        try context.save()

        XCTAssertFalse(
            TrainingDayContentSnapshotWriter.recordAdHocExerciseAdded(exercise, to: fixture.session, in: context),
            "ohne vorherige Erst-Aufnahme darf kein Snapshot nachträglich erfunden werden"
        )
        XCTAssertEqual(fixture.session.contentSnapshotState, .notCaptured)
    }

    func testRecordAdHocExerciseRejectedAfterCompletion() throws {
        let fixture = try makeFixture(exerciseCount: 0)
        fixture.session.isAdHoc = true
        let context = fixture.context
        try context.save()
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))
        fixture.session.isCompleted = true

        let exercise = Exercise(name: "Zu spät", exerciseTemplateID: UUID(), orderIndex: 0, day: fixture.day)
        context.insert(exercise)
        try context.save()

        XCTAssertFalse(TrainingDayContentSnapshotWriter.recordAdHocExerciseAdded(exercise, to: fixture.session, in: context))
        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("eingefrorener Snapshot muss lesbar bleiben")
        }
        XCTAssertTrue(snapshot.exercises.isEmpty, "der eingefrorene (leere) Stand bleibt unverändert")
    }

    // MARK: - Beschädigter / nicht unterstützter Snapshot (nie stillschweigend durch Live-Inhalt ersetzt)

    func testCorruptedStoredJSONSurfacesAsUnreadableNeverSilentlyReplacedByLiveContent() throws {
        let fixture = try makeFixture(exerciseCount: 1)
        let context = fixture.context
        try context.save()
        TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context)
        try context.save()

        // Simuliert Store-Korruption.
        fixture.session.contentSnapshotJSON = "{ kaputt"

        guard case .unreadable(.corrupted) = fixture.session.contentSnapshotState else {
            return XCTFail("beschädigtes JSON muss als .unreadable(.corrupted) sichtbar werden: \(fixture.session.contentSnapshotState)")
        }
    }
}
#endif
