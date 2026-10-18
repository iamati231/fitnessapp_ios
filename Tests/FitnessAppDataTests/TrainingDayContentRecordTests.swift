#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// P8-Vorbereitung, Paket B (`docs/P8_STUFE2_VERSIONIERUNG_PLAN.md`):
/// `TrainingDayContentRecord` + `TrainingDayContentSnapshotWriter`. Deckt
/// die vom Auftrag benannten Kategorien ab: Roundtrip durch SwiftData,
/// Session-/Record-Isolation, ECHTE Bestandsdatenmigration (zwei Schemata
/// gegen DENSELBEN On-Disk-Store, kein frischer In-Memory-Container),
/// Löschverhalten, Schutz vor Überschreiben eines abgeschlossenen Records.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class TrainingDayContentRecordTests: XCTestCase {

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Diagnose (siehe Commit-Historie): baut ERST einen belanglosen,
    /// sofort verworfenen Container OHNE `TrainingDayContentRecord` im
    /// Schema, danach den eigentlichen Container MIT diesem Typ — exakt die
    /// Reihenfolge, die der einzige nie abstürzende Test dieser Datei
    /// (`testExistingWorkoutSessionsSurviveAddingTrainingDayContentRecordToTheSchema`)
    /// bereits hat. Testet die Hypothese, dass der Signal-5-Absturz nur
    /// auftritt, wenn ein Schema MIT `TrainingDayContentRecord` die ALLERERSTE
    /// `ModelContainer`-Erzeugung im Prozess ist.
    private func makeContainer() throws -> ModelContainer {
        _ = try? ModelContainer(
            for: Schema(preContentRecordSchemaTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Exakter Stand von `AppSchema.types` VOR diesem Paket — für den
    /// On-Disk-Migrationstest unten. Bewusst eine eigene, von `AppSchema`
    /// unabhängige Liste: ändert sich `AppSchema.types` künftig erneut,
    /// soll DIESER Test weiterhin exakt den historischen Vor-Zustand
    /// abbilden, nicht automatisch mitwandern.
    private var preContentRecordSchemaTypes: [any PersistentModel.Type] {
        [
            UserBodyProfile.self, BodyMeasurement.self, TrainingPlan.self, TrainingDay.self,
            Exercise.self, ExerciseLog.self, WorkoutSession.self, ExerciseTemplate.self,
            WaterEntry.self, PersonalRecordEntry.self, Gear.self, PeriodicCheckIn.self
        ]
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

        XCTAssertEqual(fixture.session.contentSnapshotState(in: context), .notCaptured, "vor dem ersten capture gibt es noch keinen Record")

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))

        guard case .available(let snapshot) = fixture.session.contentSnapshotState(in: context) else {
            return XCTFail("nach capture muss ein lesbarer Snapshot vorliegen: \(fixture.session.contentSnapshotState(in: context))")
        }
        XCTAssertEqual(snapshot.exercises.count, 2)
        XCTAssertEqual(snapshot.exercises.map(\.nameSnapshot), ["Bankdrücken", "Kurzhantel-Rudern"])
        XCTAssertEqual(snapshot.dayNameSnapshot, "Push A")
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
        XCTAssertEqual(session.contentSnapshotState(in: context), .notCaptured)
    }

    func testCaptureOnADayWithNoActiveExercisesYieldsAValidEmptySnapshotNotAnError() throws {
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context, exerciseCount: 0)
        try context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))
        guard case .available(let snapshot) = fixture.session.contentSnapshotState(in: context) else {
            return XCTFail("eine leere Übungsliste ist gültig, kein Fehler: \(fixture.session.contentSnapshotState(in: context))")
        }
        XCTAssertTrue(snapshot.exercises.isEmpty)
    }

    // MARK: - Session-/Record-Isolation

    func testTwoSessionsGetIndependentRecordsNeitherAffectsTheOther() throws {
        let context = try makeContainer().mainContext
        let fixtureA = makeFixture(in: context, exerciseCount: 1)
        let fixtureB = makeFixture(in: context, exerciseCount: 3)
        try context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixtureA.session, in: context))
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixtureB.session, in: context))

        guard case .available(let snapshotA) = fixtureA.session.contentSnapshotState(in: context),
              case .available(let snapshotB) = fixtureB.session.contentSnapshotState(in: context) else {
            return XCTFail("beide Sessions müssen unabhängig voneinander lesbare Snapshots haben")
        }
        XCTAssertEqual(snapshotA.exercises.count, 1)
        XCTAssertEqual(snapshotB.exercises.count, 3, "Bs Record darf nicht von As Inhalt beeinflusst sein")
        XCTAssertFalse(
            fixtureA.session.contentRecord(in: context) === fixtureB.session.contentRecord(in: context),
            "jede Session braucht ihren EIGENEN Record, kein geteiltes Objekt"
        )
    }

    // MARK: - Schutz vor Überschreiben eines abgeschlossenen Records

    func testCaptureAfterCompletionIsRejectedAndLeavesTheFrozenRecordUnchanged() throws {
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context, exerciseCount: 1)
        try context.save()

        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context))
        guard case .available(let originalSnapshot) = fixture.session.contentSnapshotState(in: context) else {
            return XCTFail("Erst-Aufnahme muss gelingen")
        }
        XCTAssertEqual(originalSnapshot.exercises.count, 1)

        // Session abschließen - der Record ist ab jetzt eingefroren.
        fixture.session.isCompleted = true

        // Tag nachträglich ändern (z.B. über einen DayEditorView-Äquivalent-
        // Pfad): eine dritte Übung hinzufügen.
        let extra = Exercise(name: "Zusatzübung", exerciseTemplateID: UUID(), orderIndex: 5, day: fixture.day)
        context.insert(extra)
        try context.save()

        let captureAfterCompletionSucceeded = TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context)
        XCTAssertFalse(captureAfterCompletionSucceeded, "ein Schreibversuch nach Abschluss darf nicht gelingen")

        guard case .available(let afterAttempt) = fixture.session.contentSnapshotState(in: context) else {
            return XCTFail("der eingefrorene Record muss weiterhin lesbar bleiben")
        }
        XCTAssertEqual(afterAttempt, originalSnapshot, "der eingefrorene Record darf sich durch den Versuch nicht verändert haben")
        XCTAssertEqual(afterAttempt.exercises.count, 1, "die nachträglich hinzugefügte Übung darf NICHT im Record auftauchen")
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
        guard case .available(let snapshot) = fixture.session.contentSnapshotState(in: context) else {
            return XCTFail("der Inhalts-Snapshot muss das Löschen des Tages unbeschadet überstehen")
        }
        XCTAssertEqual(snapshot.exercises.count, 2, "der historische Inhalt bleibt vollständig erhalten")
    }

    /// Kein `@Relationship`-Cascade (siehe Typ-Dokumentation auf
    /// `TrainingDayContentRecord`) — die Aufräumung ist ein expliziter
    /// Aufruf, den ein künftiger Session-Löschpfad (Paket C) VOR
    /// `context.delete(session)` machen muss. Dieser Test prüft genau das:
    /// `deleteRecord(for:in:)` entfernt den Record, ein nackter
    /// `context.delete(session)` allein wuerde ihn (bewusst) verwaist zurueck-
    /// lassen.
    func testDeleteRecordRemovesTheOrphanedRecordWhenCalledBeforeSessionDeletion() throws {
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context, exerciseCount: 1)
        try context.save()
        TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context)
        try context.save()

        let recordCountBefore = try context.fetchCount(FetchDescriptor<TrainingDayContentRecord>())
        XCTAssertEqual(recordCountBefore, 1)

        XCTAssertTrue(TrainingDayContentSnapshotWriter.deleteRecord(for: fixture.session, in: context))
        context.delete(fixture.session)
        try context.save()

        let recordCountAfter = try context.fetchCount(FetchDescriptor<TrainingDayContentRecord>())
        XCTAssertEqual(recordCountAfter, 0, "ein verwaister Record ohne Session hat keine eigenständige Bedeutung")
    }

    // MARK: - Beschädigter / nicht unterstützter Record (nie stillschweigend durch Live-Inhalt ersetzt)

    func testCorruptedStoredJSONSurfacesAsUnreadableNeverSilentlyReplacedByLiveContent() throws {
        let context = try makeContainer().mainContext
        let fixture = makeFixture(in: context, exerciseCount: 1)
        try context.save()
        TrainingDayContentSnapshotWriter.capture(for: fixture.session, in: context)
        try context.save()

        // Simuliert Store-Korruption — @testable erlaubt direkten Zugriff auf
        // das modul-interne Feld, genau wie dieser Test es braucht; kein
        // produktiver Call-Site hat diesen Zugriff.
        fixture.session.contentRecord(in: context)?.contentJSON = "{ kaputt"

        guard case .unreadable(.corrupted) = fixture.session.contentSnapshotState(in: context) else {
            return XCTFail("beschädigtes JSON muss als .unreadable(.corrupted) sichtbar werden: \(fixture.session.contentSnapshotState(in: context))")
        }
    }

    // MARK: - ECHTE Bestandsdatenmigration (zwei Schemata, ein On-Disk-Store)
    //
    // Ein frischer In-Memory-Container beweist NUR, dass ein frisch
    // erzeugtes Objekt den richtigen Default hat - er kann niemals zeigen,
    // dass ein VORHANDENER Store ohne das neue Modell weiterhin oeffnet.
    // Deshalb hier zwei echte, unterschiedliche `Schema`-Instanzen gegen
    // DIESELBE Store-Datei auf der Festplatte.

    func testExistingWorkoutSessionsSurviveAddingTrainingDayContentRecordToTheSchema() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrainingDayContentRecordMigrationTests-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
            }
        }

        let oldSessionStart = d(2024, 1, 1)
        do {
            // ALTER Store: Schema exakt wie vor diesem Paket, OHNE
            // TrainingDayContentRecord.
            let oldSchema = Schema(preContentRecordSchemaTypes)
            let oldConfig = ModelConfiguration(schema: oldSchema, url: storeURL)
            let oldContainer = try ModelContainer(for: oldSchema, configurations: oldConfig)
            let oldContext = oldContainer.mainContext

            let plan = TrainingPlan(name: "Alt-Plan", programType: "custom", isActive: true)
            oldContext.insert(plan)
            let day = TrainingDay(name: "Ganzkörper", weekday: 2, type: .fullBody, plan: plan)
            oldContext.insert(day)
            let session = WorkoutSession(
                startTime: oldSessionStart, endTime: oldSessionStart.addingTimeInterval(3600),
                durationMinutes: 60, exerciseCount: 1, isCompleted: true, day: day
            )
            oldContext.insert(session)
            try oldContext.save()
        }

        // NEUER Container, DERSELBE Store-Datei, volles AKTUELLES Schema
        // (inklusive TrainingDayContentRecord).
        let newSchema = Schema(AppSchema.types)
        let newConfig = ModelConfiguration(schema: newSchema, url: storeURL)
        let newContainer = try ModelContainer(for: newSchema, configurations: newConfig)
        let newContext = newContainer.mainContext

        let sessions = try newContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1, "die Altsession muss nach dem Schema-Zuwachs weiterhin ladbar sein")
        XCTAssertEqual(
            sessions.first.map { Int($0.startTime.timeIntervalSince1970) },
            Int(oldSessionStart.timeIntervalSince1970)
        )
        XCTAssertNil(sessions.first?.contentRecord(in: newContext), "kein rückwirkend erfundener Snapshot für eine Session von vor diesem Feld")
        XCTAssertEqual(sessions.first?.contentSnapshotState(in: newContext), .notCaptured)

        // Gegenprobe: der neue Schreibpfad funktioniert auf demselben (jetzt
        // migrierten) Store ganz normal weiter — NICHT an der Altsession
        // selbst (die ist bereits abgeschlossen und bleibt zu Recht
        // eingefroren/`notCaptured`), sondern an einer NEUEN, offenen Session,
        // wie sie nach dem App-Update real entstehen würde.
        guard let migratedDay = try newContext.fetch(FetchDescriptor<TrainingDay>()).first else {
            return XCTFail("migrierter Tag muss weiterhin auffindbar sein")
        }
        let newSession = WorkoutSession(
            startTime: Date(), endTime: Date().addingTimeInterval(1800),
            durationMinutes: 30, exerciseCount: 0, isCompleted: false, day: migratedDay
        )
        newContext.insert(newSession)
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: newSession, in: newContext))
        XCTAssertNotEqual(newSession.contentSnapshotState(in: newContext), .notCaptured)
    }
}
#endif
