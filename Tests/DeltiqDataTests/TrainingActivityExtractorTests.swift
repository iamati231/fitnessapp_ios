#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// AI-Running-Coach Phase 2, Work Package 2A (docs/superpowers/plans/
/// 2026-11-06-ai-running-coach-phase2-implementation.md). SwiftData-Glue-
/// Tests, Vorbild `CardioHistoryExtractorTests`.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class TrainingActivityExtractorTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeSession(startTime: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> WorkoutSession {
        let session = WorkoutSession(startTime: startTime, isCompleted: true)
        context.insert(session)
        return session
    }

    private func makeStrengthExercise(name: String = "Squat", equipment: Equipment? = nil) -> Exercise {
        let day = TrainingDay(name: "Legs", weekday: 2, type: .legs)
        context.insert(day)
        let exercise = Exercise(name: name, isCardio: false, equipment: equipment, day: day)
        context.insert(exercise)
        return exercise
    }

    private func makeRunningExercise() -> Exercise {
        let day = TrainingDay(name: "Run", weekday: 1, type: .fullBody)
        context.insert(day)
        let exercise = Exercise(name: "Easy Run", isCardio: true, day: day)
        exercise.enduranceSportKind = .running
        context.insert(exercise)
        return exercise
    }

    // MARK: - Testfall 6: Bodyweight-Training ohne erfundenes Gewicht

    func testBodyweightStrengthSetsCountAsActivityWithZeroVolume() {
        let exercise = makeStrengthExercise(name: "Pull-Up", equipment: .bodyweight)
        let session = makeSession()
        for i in 0..<3 {
            context.insert(ExerciseLog(setIndex: i, weight: 0, reps: 8, rir: 2, exercise: exercise, session: session))
        }

        let activities = TrainingActivityExtractor.extract(from: [session])
        XCTAssertEqual(activities.count, 1)
        XCTAssertTrue(activities[0].hasStrengthActivity)
        XCTAssertEqual(activities[0].strengthSetCount, 3, "3 echte Bodyweight-Saetze, kein erfundenes Gewicht noetig")
        XCTAssertEqual(activities[0].strengthVolumeKg, 0, "0 kg ist korrekt, nicht 'fehlend'")
    }

    // MARK: - Testfall 7: Kettlebell-Training

    func testKettlebellStrengthCountsLikeAnyOtherWeightedStrengthWork() {
        let exercise = makeStrengthExercise(name: "Kettlebell Swing", equipment: .kettlebell)
        let session = makeSession()
        context.insert(ExerciseLog(setIndex: 0, weight: 16, reps: 15, rir: 1, exercise: exercise, session: session))
        context.insert(ExerciseLog(setIndex: 1, weight: 16, reps: 15, rir: 1, exercise: exercise, session: session))

        let activities = TrainingActivityExtractor.extract(from: [session])
        XCTAssertEqual(activities[0].strengthSetCount, 2)
        XCTAssertEqual(activities[0].strengthVolumeKg, 16 * 15 * 2)
    }

    // MARK: - Testfall 8: mehrere Uebungen innerhalb einer Session

    func testMultipleExercisesInOneSessionAreSummedIntoOneActivity() {
        let squat = makeStrengthExercise(name: "Squat")
        let bench = makeStrengthExercise(name: "Bench Press")
        let session = makeSession()
        context.insert(ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: squat, session: session))
        context.insert(ExerciseLog(setIndex: 1, weight: 100, reps: 5, rir: 2, exercise: squat, session: session))
        context.insert(ExerciseLog(setIndex: 0, weight: 80, reps: 8, rir: 2, exercise: bench, session: session))

        let activities = TrainingActivityExtractor.extract(from: [session])
        XCTAssertEqual(activities.count, 1, "eine Session bleibt EINE Aktivitaet, auch mit mehreren Uebungen")
        XCTAssertEqual(activities[0].strengthSetCount, 3)
        XCTAssertEqual(activities[0].strengthVolumeKg, 100 * 5 * 2 + 80 * 8)
    }

    // MARK: - Testfall 9: mehrere Sessions innerhalb einer Woche

    func testMultipleSessionsInOneWeekProduceSeparateActivities() {
        let exercise = makeStrengthExercise()
        let session1 = makeSession(startTime: Date(timeIntervalSince1970: 1_700_000_000))
        let session2 = makeSession(startTime: Date(timeIntervalSince1970: 1_700_000_000 + 2 * 86400))
        context.insert(ExerciseLog(setIndex: 0, weight: 50, reps: 10, rir: 2, exercise: exercise, session: session1))
        context.insert(ExerciseLog(setIndex: 0, weight: 60, reps: 10, rir: 2, exercise: exercise, session: session2))

        let activities = TrainingActivityExtractor.extract(from: [session1, session2])
        XCTAssertEqual(activities.count, 2)
        XCTAssertEqual(activities.map(\.strengthVolumeKg).sorted(), [500, 600])
    }

    /// Run+Strength in einer Session ("Brick"): beide Zahlen bleiben
    /// nebeneinander sichtbar, keine vermischt die andere.
    func testMixedRunningAndStrengthSessionKeepsBothNumbersIndependently() {
        let runExercise = makeRunningExercise()
        let strengthExercise = makeStrengthExercise()
        let session = makeSession()
        context.insert(ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: runExercise, session: session, distanceKm: 5, durationSeconds: 1800))
        context.insert(ExerciseLog(setIndex: 0, weight: 40, reps: 10, rir: 2, exercise: strengthExercise, session: session))

        let activities = TrainingActivityExtractor.extract(from: [session])
        XCTAssertEqual(activities.count, 1)
        XCTAssertTrue(activities[0].isRunning)
        XCTAssertEqual(activities[0].runningDistanceKm, 5)
        XCTAssertTrue(activities[0].hasStrengthActivity)
        XCTAssertEqual(activities[0].strengthSetCount, 1)
        XCTAssertEqual(activities[0].strengthVolumeKg, 400)
    }

    // MARK: - Testfall 12: geloeschte Exercise mit vorhandenen historischen Snapshots

    func testDeletedExerciseStillCountsTowardStrengthLoadViaSnapshot() throws {
        let exercise = makeStrengthExercise()
        let session = makeSession()
        context.insert(ExerciseLog(setIndex: 0, weight: 70, reps: 6, rir: 2, exercise: exercise, session: session))
        try context.save()

        context.delete(exercise)
        try context.save()

        let activities = TrainingActivityExtractor.extract(from: [session])
        XCTAssertEqual(activities[0].hasStrengthActivity, true, "containsStrengthWork liest resolvedIsCardio snapshot-first, ueberlebt den Exercise-Delete")
        XCTAssertEqual(activities[0].strengthSetCount, 1)
        XCTAssertEqual(activities[0].strengthVolumeKg, 420)
    }

    // MARK: - Testfall 13: keine doppelte Zaehlung von ExerciseLogs und Session-Aggregaten

    /// `session.totalVolumeKg`/`totalSets` (vom bestehenden `recomputeTotals`-
    /// Pfad gepflegt) werden vom Extractor absichtlich NICHT gelesen - er
    /// berechnet den Kraft-Anteil unabhaengig direkt aus den gefilterten
    /// Logs. Dieser Test beweist, dass beide Wege (haette man sie addiert)
    /// NICHT zum doppelten Ergebnis fuehren, weil nur EINER tatsaechlich
    /// verwendet wird.
    func testStrengthVolumeIsNotDoubleCountedAgainstSessionLevelAggregates() {
        let exercise = makeStrengthExercise()
        let session = makeSession()
        context.insert(ExerciseLog(setIndex: 0, weight: 50, reps: 10, rir: 2, exercise: exercise, session: session))
        session.recomputeTotals()
        XCTAssertEqual(session.totalVolumeKg, 500, "Testaufbau: Session-Aggregat ist unabhaengig korrekt gepflegt")

        let activities = TrainingActivityExtractor.extract(from: [session])
        XCTAssertEqual(activities[0].strengthVolumeKg, 500, "nicht 1000 - der Extractor addiert sein eigenes Ergebnis nicht zum Session-Aggregat")
    }

    /// Platzhalter-Zeilen (DEL-223: nie ausgefuellte 0/0-Zeilen) duerfen die
    /// Krafttrainings-Satzzahl nicht aufblaehen.
    func testEmptyPlaceholderRowsAreExcludedFromStrengthSetCount() {
        let exercise = makeStrengthExercise()
        let session = makeSession()
        context.insert(ExerciseLog(setIndex: 0, weight: 50, reps: 10, rir: 2, exercise: exercise, session: session))
        context.insert(ExerciseLog(setIndex: 1, weight: 0, reps: 0, rir: 2, exercise: exercise, session: session))
        context.insert(ExerciseLog(setIndex: 2, weight: 0, reps: 0, rir: 2, exercise: exercise, session: session))

        let activities = TrainingActivityExtractor.extract(from: [session])
        XCTAssertEqual(activities[0].strengthSetCount, 1, "die beiden nie ausgefuellten Platzhalter-Zeilen zaehlen nicht mit")
    }

    func testIncompleteAndRestDaySessionsAreExcluded() {
        let incomplete = WorkoutSession(startTime: Date(), isCompleted: false)
        let restDay = WorkoutSession(startTime: Date(), isCompleted: true, isRestDay: true)
        context.insert(incomplete)
        context.insert(restDay)
        XCTAssertTrue(TrainingActivityExtractor.extract(from: [incomplete, restDay]).isEmpty)
    }
}
#endif
