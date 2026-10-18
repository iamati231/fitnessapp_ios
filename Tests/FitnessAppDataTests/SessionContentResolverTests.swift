#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// P8 Stufe-2-Nachbesserung (Resume-Isolation): reproduziert zuerst die vom
/// Auftrag benannte Lücke — die bisherigen Player lasen bei Wiederaufnahme
/// ausschließlich den LIVE-Tag (`orderedExercises(in:)`/
/// `day.activeExercises`), nie den beim Session-Start eingefrorenen
/// Snapshot. `SessionContentResolver` ist die Stelle, die das behebt.
/// Besonders wichtig: eine naive Zuordnung über den AKTUELLEN `orderIndex`
/// würde nach einer externen Umsortierung während die Session offen ist
/// STILLE FALSCH-ZUORDNUNGEN erzeugen (Satz wird gegen die falsche Übung
/// geloggt) — genau das deckt der erste Test auf.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class SessionContentResolverTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let day: TrainingDay
        let session: WorkoutSession
        let bench: Exercise
        let rows: Exercise
    }

    @discardableResult
    private func makeTwoExerciseFixture() throws -> Fixture {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Push A", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let bench = Exercise(name: "Bankdrücken", exerciseTemplateID: UUID(), orderIndex: 0, sets: 3, day: day)
        let rows = Exercise(name: "Kurzhantel-Rudern", exerciseTemplateID: UUID(), orderIndex: 1, sets: 3, day: day)
        context.insert(bench)
        context.insert(rows)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: false, day: day)
        context.insert(session)
        try context.save()
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: session, in: context))
        return Fixture(container: container, context: context, day: day, session: session, bench: bench, rows: rows)
    }

    // MARK: - Kernregression: externe Umsortierung während offener Session

    /// Vor diesem Fix hätte ein Resume-Leser, der `orderedExercises(in:)`
    /// (live `orderIndex`-Sortierung) nutzt, nach diesem Tausch Sätze gegen
    /// die JEWEILS ANDERE Übung geloggt. Der Resolver muss stattdessen über
    /// `instanceID` auflösen und jeden Eintrag auf SEIN eigenes Objekt
    /// zurückführen.
    func testResumedSessionKeepsCorrectIdentityAfterExternalReorder() throws {
        let fixture = try makeTwoExerciseFixture()
        let context = fixture.context

        // Tag extern umsortieren, waehrend die Session offen bleibt (DayEditorView .onMove-Äquivalent).
        fixture.bench.orderIndex = 1
        fixture.rows.orderIndex = 0
        try context.save()

        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("Snapshot muss lesbar bleiben")
        }
        let resolved = SessionContentResolver.resolve(snapshot: snapshot, liveExercises: fixture.day.activeExercises)
        XCTAssertEqual(resolved.count, 2)

        guard case .live(let entry0, let exercise0) = resolved[0],
              case .live(let entry1, let exercise1) = resolved[1] else {
            return XCTFail("beide Einträge müssen trotz Umsortierung noch live auflösbar sein: \(resolved)")
        }
        // Reihenfolge bleibt die AUFNAHME-Reihenfolge (entry.orderIndex), nicht die jetzt live vertauschte.
        XCTAssertEqual(entry0.nameSnapshot, "Bankdrücken")
        XCTAssertEqual(entry1.nameSnapshot, "Kurzhantel-Rudern")
        XCTAssertTrue(exercise0 === fixture.bench, "der 'Bankdrücken'-Eintrag muss weiterhin auf das Bankdrücken-Objekt zeigen, nicht auf das nach dem Tausch an Position 0 stehende Rudern")
        XCTAssertTrue(exercise1 === fixture.rows, "der 'Rudern'-Eintrag muss weiterhin auf das Rudern-Objekt zeigen")
    }

    // MARK: - Extern hinzugefügte Übung bleibt unsichtbar

    func testExternallyAddedExerciseDoesNotAppearInResolvedList() throws {
        let fixture = try makeTwoExerciseFixture()
        let context = fixture.context

        let externallyAdded = Exercise(name: "Extern hinzugefügt", exerciseTemplateID: UUID(), orderIndex: 2, day: fixture.day)
        context.insert(externallyAdded)
        try context.save()

        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("Snapshot muss lesbar bleiben")
        }
        let resolved = SessionContentResolver.resolve(snapshot: snapshot, liveExercises: fixture.day.activeExercises)
        XCTAssertEqual(resolved.count, 2, "die extern hinzugefügte dritte Übung darf in der laufenden Session nicht auftauchen")
        XCTAssertFalse(resolved.contains { $0.exercise === externallyAdded })
    }

    // MARK: - Extern gelöschte Übung verschwindet nie still

    func testExternallyDeletedExerciseSurfacesAsRemovedFromLiveDayNotSilentlyDropped() throws {
        let fixture = try makeTwoExerciseFixture()
        let context = fixture.context

        context.delete(fixture.bench)
        try context.save()

        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("Snapshot muss lesbar bleiben")
        }
        let resolved = SessionContentResolver.resolve(snapshot: snapshot, liveExercises: fixture.day.activeExercises)
        XCTAssertEqual(resolved.count, 2, "beide ursprünglichen Einträge bleiben sichtbar, keiner verschwindet still")

        guard case .removedFromLiveDay(let removedEntry) = resolved[0] else {
            return XCTFail("der gelöschte Eintrag muss als .removedFromLiveDay markiert sein, nicht fehlen: \(resolved)")
        }
        XCTAssertEqual(removedEntry.nameSnapshot, "Bankdrücken")

        guard case .live(_, let stillLive) = resolved[1] else {
            return XCTFail("die nicht gelöschte Übung muss weiterhin .live auflösen")
        }
        XCTAssertTrue(stillLive === fixture.rows)
    }

    // MARK: - Eingefrorene Zielwerte überleben externe Live-Edits

    func testResolvedTargetValuesStayFrozenDespiteLiveExternalEdit() throws {
        let fixture = try makeTwoExerciseFixture()
        let context = fixture.context

        // Externe Änderung (z.B. ExerciseEditorView aus DayEditorView heraus,
        // UNABHÄNGIG von der offenen Session): Zielwerte der Live-Exercise ändern.
        fixture.bench.sets = 10
        fixture.bench.repsMin = 1
        fixture.bench.repsMax = 1
        fixture.bench.restSeconds = 5
        try context.save()
        XCTAssertEqual(fixture.bench.sets, 10, "die Live-Übung muss tatsächlich divergiert sein, sonst wäre dieser Test ein No-Op")

        guard case .available(let snapshot) = fixture.session.contentSnapshotState else {
            return XCTFail("Snapshot muss lesbar bleiben")
        }
        let resolved = SessionContentResolver.resolve(snapshot: snapshot, liveExercises: fixture.day.activeExercises)
        guard case .live(let entry, let exercise) = resolved[0] else {
            return XCTFail("muss weiterhin live auflösbar sein")
        }
        XCTAssertTrue(exercise === fixture.bench, "Logging-Identität bleibt die Live-Exercise")
        XCTAssertEqual(entry.sets, 3, "die laufende Session behält ihren EIGENEN, zum Start eingefrorenen Zielwert")
        XCTAssertEqual(entry.repsMin, 8)
        XCTAssertEqual(entry.restSeconds, 90)
    }

    // MARK: - Legacy-Fallback ohne instanceID

    /// Snapshots, die VOR diesem Feld aufgenommen wurden, haben
    /// `instanceID == nil` auf jedem Eintrag. Der Resolver darf solche
    /// Alt-Sessions nicht einfach komplett scheitern lassen, sondern fällt
    /// auf die bisherige (bekannt unsicherere, aber nicht schlechtere)
    /// `exerciseTemplateID`+`orderIndex`-Zuordnung zurück.
    func testLegacySnapshotWithoutInstanceIDFallsBackToTemplateAndOrderIndexMatching() throws {
        let fixture = try makeTwoExerciseFixture()
        let legacyEntry = TrainingDayContentSnapshot.ExerciseEntry(
            orderIndex: 0, instanceID: nil, exerciseTemplateID: fixture.bench.exerciseTemplateID,
            nameSnapshot: "Bankdrücken", customNameSnapshot: nil, role: .workingSet, supersetId: nil,
            isCardio: false, isTimeBased: false, cardioEquipment: .none,
            sets: 3, repsMin: 8, repsMax: 12, restSeconds: 90,
            targetRir: 2, targetDistanceKm: nil, targetDurationMinutes: nil
        )
        let legacySnapshot = TrainingDayContentSnapshot(
            dayNameSnapshot: "Push A", dayCustomNameSnapshot: nil, dayLocalizationKeySnapshot: nil,
            weekday: 2, dayType: .chest, timeFormat: nil, timeCapMinutes: nil,
            circuitRounds: nil, circuitRestSeconds: nil, circuitMode: nil,
            exercises: [legacyEntry]
        )

        let resolved = SessionContentResolver.resolve(snapshot: legacySnapshot, liveExercises: fixture.day.activeExercises)
        XCTAssertEqual(resolved.count, 1)
        guard case .live(_, let exercise) = resolved[0] else {
            return XCTFail("muss trotz fehlender instanceID ueber templateID+orderIndex auflösen")
        }
        XCTAssertTrue(exercise === fixture.bench)
    }
}
#endif
