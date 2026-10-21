#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// P8 Stufe-2, Paket E: `WorkoutSummaryView.exercisesWithLogs` verwarf
/// bisher jedes Log, dessen `Exercise` gelöscht wurde (orphan) — der Satz
/// blieb in `session.totalSets` mitgezählt, war in der Aufschlüsselung
/// aber unsichtbar. Diese Tests decken die ausgelagerte Gruppierlogik
/// (`ExerciseLogGrouping.group`) direkt ab, insbesondere die vom Auftrag
/// explizit genannte Gefahr: zwei gleichnamige, inzwischen gelöschte
/// Übungen dürfen NICHT allein über den Namen zu einer Gruppe verschmolzen
/// werden.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ExerciseLogGroupingTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    func testLiveExerciseLogsAreGroupedByObjectIdentity() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let bench = Exercise(name: "Bankdrücken", exerciseTemplateID: UUID(), orderIndex: 0, day: day)
        let rows = Exercise(name: "Kurzhantel-Rudern", exerciseTemplateID: UUID(), orderIndex: 1, day: day)
        context.insert(bench)
        context.insert(rows)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        context.insert(session)

        let log1 = ExerciseLog(setIndex: 0, weight: 80, reps: 8, rir: 2, exercise: bench, session: session)
        let log2 = ExerciseLog(setIndex: 0, weight: 20, reps: 10, rir: 2, exercise: rows, session: session)
        context.insert(log1)
        context.insert(log2)
        try context.save()

        let groups = ExerciseLogGrouping.group(session.logs)
        XCTAssertEqual(groups.count, 2)
        guard case .live(let first, _) = groups[0] else { return XCTFail("erste Gruppe muss live sein") }
        guard case .live(let second, _) = groups[1] else { return XCTFail("zweite Gruppe muss live sein") }
        XCTAssertEqual(first.orderIndex, 0, "Sortierung folgt orderIndex (Plan-Reihenfolge)")
        XCTAssertEqual(second.orderIndex, 1)
    }

    /// Der vom Auftrag explizit benannte Gefahrenfall: zwei Vorkommen
    /// DERSELBEN Übung (identischer Name UND identische Vorlagen-ID) am
    /// selben Tag, beide gelöscht. Eine namensbasierte Gruppierung würde
    /// ihre Logs faelschlich zusammenwerfen.
    func testOrphanedLogsWithDuplicateNamesStayInSeparateGroups() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let templateID = UUID()
        let main = Exercise(name: "Bankdrücken", exerciseTemplateID: templateID, orderIndex: 0, day: day)
        let finisher = Exercise(name: "Bankdrücken", exerciseTemplateID: templateID, orderIndex: 1, day: day)
        context.insert(main)
        context.insert(finisher)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        context.insert(session)

        let mainLog = ExerciseLog(setIndex: 0, weight: 80, reps: 8, rir: 2, exercise: main, session: session)
        let finisherLog = ExerciseLog(setIndex: 0, weight: 40, reps: 15, rir: 1, exercise: finisher, session: session)
        context.insert(mainLog)
        context.insert(finisherLog)
        try context.save()

        // Beide Exercises jetzt löschen - die Logs werden (ExerciseLog.exercise
        // ist .nullify) zu Orphanen, behalten aber ihre DEL-051/P8-Snapshot-
        // Felder inkl. exerciseOrderIndexSnapshot.
        context.delete(main)
        context.delete(finisher)
        try context.save()

        XCTAssertNil(mainLog.exercise)
        XCTAssertNil(finisherLog.exercise)
        XCTAssertEqual(mainLog.exerciseOrderIndexSnapshot, 0)
        XCTAssertEqual(finisherLog.exerciseOrderIndexSnapshot, 1)

        let groups = ExerciseLogGrouping.group(session.logs)
        XCTAssertEqual(groups.count, 2, "zwei gleichnamige, gelöschte Übungen dürfen NICHT zu einer Gruppe verschmolzen werden")
        for group in groups {
            guard case .orphaned(_, let logs) = group else { return XCTFail("beide Gruppen müssen orphaned sein") }
            XCTAssertEqual(logs.count, 1, "jede Gruppe enthält nur die Logs IHRER Übung")
        }
        let orderIndices = groups.map(\.orderIndex).sorted()
        XCTAssertEqual(orderIndices, [0, 1])
    }

    /// Kernregression: vor diesem Fix verschwanden orphane Logs komplett
    /// aus der Aufschlüsselung (wurden via `compactMap { ... nil }`
    /// verworfen), obwohl sie weiterhin in `session.logs` existierten.
    func testOrphanedLogsAreNeverDroppedAfterExerciseDeletion() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = TrainingPlan(name: "P", programType: "custom", isActive: true)
        context.insert(plan)
        let day = TrainingDay(name: "Push A", weekday: 2, type: .chest, plan: plan)
        context.insert(day)
        let exercise = Exercise(name: "Bankdrücken", exerciseTemplateID: UUID(), orderIndex: 0, day: day)
        context.insert(exercise)
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, day: day)
        context.insert(session)
        let log = ExerciseLog(setIndex: 0, weight: 80, reps: 8, rir: 2, exercise: exercise, session: session)
        context.insert(log)
        try context.save()

        context.delete(exercise)
        try context.save()

        XCTAssertEqual(session.logs.count, 1, "das Log selbst bleibt (nullify, nicht cascade)")
        let groups = ExerciseLogGrouping.group(session.logs)
        XCTAssertEqual(groups.count, 1, "darf nicht stillschweigend verschwinden")
        guard case .orphaned(_, let logs) = groups[0] else { return XCTFail("muss als orphaned auftauchen") }
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.exerciseNameSnapshot, "Bankdrücken", "Name bleibt über den Snapshot lesbar")
    }

    func testOrphanedLogsWithoutOrderIndexSnapshotFallBackToTemplateIDAndName() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = WorkoutSession(startTime: Date(), endTime: Date(), isCompleted: true, isAdHoc: true)
        context.insert(session)

        // Alt-Log ohne exerciseOrderIndexSnapshot (vor diesem Feld), aber mit
        // DEL-051-Snapshot - exakt der Bestandsfall, den der Fallback deckt.
        let legacyOrphan = ExerciseLog(setIndex: 0, weight: 0, reps: 10, rir: 2, session: session)
        legacyOrphan.exerciseNameSnapshot = "Klimmzüge"
        legacyOrphan.exerciseTemplateIDSnapshot = UUID()
        context.insert(legacyOrphan)
        try context.save()

        let groups = ExerciseLogGrouping.group(session.logs)
        XCTAssertEqual(groups.count, 1)
        guard case .orphaned(_, let logs) = groups[0] else { return XCTFail("muss orphaned sein") }
        XCTAssertEqual(logs.count, 1)
    }
}
#endif
