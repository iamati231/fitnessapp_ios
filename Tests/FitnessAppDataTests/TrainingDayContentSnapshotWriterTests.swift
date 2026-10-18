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
/// Kein eigener On-Disk-Migrationstest (zwei Schema-Versionen gegen
/// denselben Store) hier: anders als die ursprüngliche Fassung (ein
/// eigenes `@Model`, siehe Commit-Historie für den Apple-CI-Absturz, der
/// zu diesem Redesign führte) sind `contentSnapshotJSON`/
/// `contentSnapshotCapturedAt` zwei zusätzliche OPTIONALE Felder auf dem
/// BESTEHENDEN `WorkoutSession`-Modell — exakt dieselbe Art Änderung wie
/// `dayName`, `timeFormatSnapshot` & Co. weiter oben in dieser Datei,
/// für die es im gesamten Codebase ebenfalls keinen dedizierten
/// Migrationstest gibt. Ein echter Vorher/Nachher-Vergleich ließe sich
/// ohnehin nur mit einer echten, von VOR diesem Commit stammenden
/// Store-Datei sinnvoll führen, die hier nicht existiert.
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

    private struct Fixture {
        let context: ModelContext
        let plan: TrainingPlan
        let day: TrainingDay
        let session: WorkoutSession
    }

    @discardableResult
    private func makeFixture(
        in context: ModelContext,
        isCompleted: Bool = false,
        exerciseCount: Int = 2
    ) -> Fixture {
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
        return Fixture(context: context, plan: plan, day: day, session: session)
    }

    // MARK: - Roundtrip durch SwiftData

    func testCaptureStoresAReadableSnapshotMatchingTheLiveDayAtCaptureTime() throws {
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context)
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
        let context = try makeContainer().mainContext
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
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context, exerciseCount: 0)
        try context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))
        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("eine leere Übungsliste ist gültig, kein Fehler: \(fixture.session.contentSnapshotState)")
        }
        XCTAssertTrue(snapshot.exercises.isEmpty)
    }

    // MARK: - Session-Isolation

    func testTwoSessionsGetIndependentSnapshotsNeitherAffectsTheOther() throws {
        let context = try makeContainer().mainContext
        let fixtureA = makeFixture(in: context, exerciseCount: 1)
        let fixtureB = makeFixture(in: context, exerciseCount: 3)
        try context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixtureA.session, in: context))
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixtureB.session, in: context))

        guard case .available(let snapshotA) = fixtureA.session.contentSnapshotState,
              case .available(let snapshotB) = fixtureB.session.contentSnapshotState else {
            return XCTFail("beide Sessions müssen unabhängig voneinander lesbare Snapshots haben")
        }
        XCTAssertEqual(snapshotA.exercises.count, 1)
        XCTAssertEqual(snapshotB.exercises.count, 3, "Bs Snapshot darf nicht von As Inhalt beeinflusst sein")
    }

    // MARK: - Schutz vor Überschreiben eines abgeschlossenen Snapshots

    func testCaptureAfterCompletionIsRejectedAndLeavesTheFrozenSnapshotUnchanged() throws {
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context, exerciseCount: 1)
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
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context, exerciseCount: 2)
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
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context, exerciseCount: 1)
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

    // MARK: - Beschädigter / nicht unterstützter Snapshot (nie stillschweigend durch Live-Inhalt ersetzt)

    func testCorruptedStoredJSONSurfacesAsUnreadableNeverSilentlyReplacedByLiveContent() throws {
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context, exerciseCount: 1)
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
