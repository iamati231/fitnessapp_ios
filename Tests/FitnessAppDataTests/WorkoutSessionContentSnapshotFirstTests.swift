#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Geräteabnahme-Befund (Stufe-2-Abnahme, Block D): `WorkoutRootView`
/// und `TimedWorkoutPlayerView` wählten den anzuzeigenden Player bislang
/// über `session.day?.timeFormat` (live), nicht über den beim
/// Session-Start eingefrorenen Snapshot — obwohl der Snapshot
/// `timeFormat` bereits mitführt. Ein externer Formatwechsel am Tag
/// während die Session offen bleibt, hätte nach Wiederaufnahme den
/// falschen Player öffnen können. `contentSnapshotTimeFormat` ist die
/// Korrektur dafür; dieser Test reproduziert die Lücke am reinen
/// Datenmodell (ohne SwiftUI), bevor sie behoben wurde.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class WorkoutSessionContentSnapshotFirstTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    func testTimeFormatStaysFrozenAfterExternalFormatChangeOnOpenSession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Zirkel-Plan", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(
            name: "Zirkel A", weekday: 2, type: .fullBody, plan: plan,
            timeFormat: .circuit, circuitRounds: 3, circuitRestSeconds: 90, circuitMode: .fixedReps
        )
        context.insert(day)
        let exercise = Exercise(name: "Kettlebell Swing", exerciseTemplateID: UUID(), sets: 3, orderIndex: 0, day: day)
        context.insert(exercise)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: false, day: day)
        context.insert(session)
        try context.save()
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: session, in: context))

        // Externe Änderung waehrend die Session offen bleibt (DayEditorView-Äquivalent).
        day.timeFormat = .amrap
        try context.save()
        XCTAssertEqual(day.timeFormat, .amrap, "der Live-Tag muss tatsächlich divergiert sein, sonst wäre dieser Test ein No-Op")

        XCTAssertEqual(
            session.contentSnapshotTimeFormat, .circuit,
            "die laufende Session muss beim eingefrorenen Zeitformat bleiben, nicht dem extern geänderten live Format folgen"
        )
    }

    func testTimeFormatFallsBackToLiveWhenNeverCaptured() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "AMRAP-Plan", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "AMRAP A", weekday: 2, type: .fullBody, plan: plan, timeFormat: .amrap)
        context.insert(day)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: false, day: day)
        context.insert(session)
        try context.save()

        XCTAssertEqual(session.contentSnapshotState, .notCaptured)
        XCTAssertEqual(
            session.contentSnapshotTimeFormat, .amrap,
            "ohne jemals aufgenommenen Snapshot (Alt-Session) bleibt der Live-Fallback erhalten"
        )
    }

    func testTimeFormatStandardDayRoutesToStandardPlayer() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = TrainingPlan(name: "Kraft-Plan", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: false, day: day)
        context.insert(session)
        try context.save()
        XCTAssertTrue(TrainingDayContentSnapshotWriter.capture(for: session, in: context))

        XCTAssertNil(
            session.contentSnapshotTimeFormat,
            "ein Standard-Krafttag bleibt auch im eingefrorenen Stand ohne Zeitformat (routet zu ActiveWorkoutView)"
        )
    }
}
#endif
