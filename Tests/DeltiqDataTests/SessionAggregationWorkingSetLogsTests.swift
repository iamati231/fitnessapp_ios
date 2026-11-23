#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Modul-9-Audit (Dashboard): `DashboardView` zaehlte Warmup-/Cooldown-Saetze
/// in fuenf Metriken/Charts (Compound-Trend, Wochen-Zusammenfassung, Volume-
/// Chart, Muskel-Heatmap, Cardio-Pace) mit, weil es rohe `logs`/`loggedSets`
/// statt einer rollen-gefilterten Quelle las. `workingSetLogs` ist der eine
/// gemeinsame Fix fuer alle fuenf Stellen.
@available(iOS 17.0, macOS 14.0, *)
final class SessionAggregationWorkingSetLogsTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    func testWorkingSetLogsExcludesWarmupAndCooldownButKeepsWorkingSets() throws {
        let context = try makeContext()

        let working = Exercise(name: "Kniebeuge", role: .workingSet)
        let warmup = Exercise(name: "Kniebeuge", role: .warmup)
        let cooldown = Exercise(name: "Kniebeuge", role: .cooldown)
        context.insert(working)
        context.insert(warmup)
        context.insert(cooldown)

        let session = WorkoutSession(
            durationMinutes: 45,
            exerciseCount: 1,
            totalSets: 3,
            isCompleted: true,
            dayName: "Test"
        )
        context.insert(session)

        let workingLog = ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: working, session: session)
        let warmupLog = ExerciseLog(setIndex: 0, weight: 60, reps: 5, rir: 4, exercise: warmup, session: session)
        let cooldownLog = ExerciseLog(setIndex: 0, weight: 40, reps: 8, rir: 4, exercise: cooldown, session: session)
        context.insert(workingLog)
        context.insert(warmupLog)
        context.insert(cooldownLog)
        try context.save()

        let result = session.workingSetLogs
        XCTAssertEqual(result.count, 1,
                      "a heavy warmup/cooldown set must not be counted as a working set")
        XCTAssertEqual(result.first?.weight, 100)
    }

    /// `workingSetLogs` baut auf `loggedSets` auf — ein nie ausgefuellter
    /// Platzhalter (DEL-223) muss weiterhin ausgeschlossen bleiben.
    func testWorkingSetLogsStillExcludesEmptyPlaceholders() throws {
        let context = try makeContext()

        let working = Exercise(name: "Bankdruecken", role: .workingSet)
        context.insert(working)
        let session = WorkoutSession(durationMinutes: 10, isCompleted: true, dayName: "Test")
        context.insert(session)

        let realLog = ExerciseLog(setIndex: 0, weight: 80, reps: 5, rir: 2, exercise: working, session: session)
        let placeholder = ExerciseLog(setIndex: 1, weight: 0, reps: 0, rir: 0, exercise: working, session: session)
        context.insert(realLog)
        context.insert(placeholder)
        try context.save()

        let result = session.workingSetLogs
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.weight, 80)
    }
}
#endif
