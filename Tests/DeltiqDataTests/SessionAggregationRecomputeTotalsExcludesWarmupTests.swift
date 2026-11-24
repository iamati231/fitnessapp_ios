#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// Audit-Fund (Modul 13, Analytics): `recomputeTotals()` - der einzige Schreiber
/// von `session.totalSets`/`totalVolumeKg` (siehe `SessionAggregation.swift`-Header) -
/// summierte bisher `loggedSets` statt `workingSetLogs` und zaehlte damit
/// Warmup-/Cooldown-Saetze in genau die Aggregate mit, die Dashboard-
/// Wochenvolumen, die 5000kg-Coach-Schwelle, DeloadAdvisor und die
/// Muskel-Heatmap lesen.
@available(iOS 17.0, macOS 14.0, *)
final class SessionAggregationRecomputeTotalsExcludesWarmupTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    func testRecomputeTotalsExcludesWarmupAndCooldownVolumeAndSetCount() throws {
        let context = try makeContext()

        let working = Exercise(name: "Kniebeuge", role: .workingSet)
        let warmup = Exercise(name: "Kniebeuge", role: .warmup)
        let cooldown = Exercise(name: "Kniebeuge", role: .cooldown)
        context.insert(working)
        context.insert(warmup)
        context.insert(cooldown)

        let session = WorkoutSession(durationMinutes: 45, isCompleted: true, dayName: "Test")
        context.insert(session)

        // 3 Warmups + 3 Working Sets (je 100kg x 5) - Working-Volumen = 1500kg/3 Saetze.
        context.insert(ExerciseLog(setIndex: 0, weight: 40, reps: 10, rir: 5, exercise: warmup, session: session))
        context.insert(ExerciseLog(setIndex: 1, weight: 60, reps: 5, rir: 4, exercise: warmup, session: session))
        context.insert(ExerciseLog(setIndex: 2, weight: 80, reps: 3, rir: 4, exercise: warmup, session: session))
        context.insert(ExerciseLog(setIndex: 3, weight: 100, reps: 5, rir: 2, exercise: working, session: session))
        context.insert(ExerciseLog(setIndex: 4, weight: 100, reps: 5, rir: 2, exercise: working, session: session))
        context.insert(ExerciseLog(setIndex: 5, weight: 100, reps: 5, rir: 2, exercise: working, session: session))
        context.insert(ExerciseLog(setIndex: 6, weight: 40, reps: 8, rir: 4, exercise: cooldown, session: session))
        try context.save()

        session.recomputeTotals()

        XCTAssertEqual(session.totalSets, 3,
            "Warmup-/Cooldown-Saetze duerfen nicht in totalSets einfliessen")
        XCTAssertEqual(session.totalVolumeKg, 1500, accuracy: 0.001,
            "Warmup-/Cooldown-Volumen darf totalVolumeKg nicht aufblaehen")
    }
}
#endif
