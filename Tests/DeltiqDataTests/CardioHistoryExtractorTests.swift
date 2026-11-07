#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqData
import DeltiqCore

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md,
/// Abschnitt 3): SwiftData-Glue-Tests fuer `CardioHistoryExtractor`.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class CardioHistoryExtractorTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeCardioExercise(sportKind: TrainingTypeKind?) -> Exercise {
        let day = TrainingDay(name: "Run", weekday: 1, type: .fullBody)
        context.insert(day)
        let exercise = Exercise(name: "Run", isCardio: true, day: day)
        exercise.enduranceSportKind = sportKind
        context.insert(exercise)
        day.exercises.append(exercise)
        return exercise
    }

    private func makeStrengthExercise() -> Exercise {
        let day = TrainingDay(name: "Legs", weekday: 2, type: .legs)
        context.insert(day)
        let exercise = Exercise(name: "Squat", isCardio: false, day: day)
        context.insert(exercise)
        day.exercises.append(exercise)
        return exercise
    }

    private func makeSession(completed: Bool = true, isRestDay: Bool = false) -> WorkoutSession {
        let session = WorkoutSession(startTime: Date(timeIntervalSince1970: 1_700_000_000), isCompleted: completed, isRestDay: isRestDay)
        context.insert(session)
        return session
    }

    func testRunningOnlySessionIsClassifiedAsRunning() {
        let exercise = makeCardioExercise(sportKind: .running)
        let session = makeSession()
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: 5, durationSeconds: 1800)
        context.insert(log)

        let result = CardioHistoryExtractor.loggedSessions(from: [session])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isRunning)
        XCTAssertFalse(result[0].isCrossTrainingOnly)
        XCTAssertFalse(result[0].hasAmbiguousCardio)
        XCTAssertFalse(result[0].hasStrengthActivity)
        XCTAssertEqual(result[0].runningDistanceKm, 5)
        XCTAssertEqual(result[0].runningDurationSeconds, 1800)
    }

    // Testfall 18: bekannte Cross-Training-Session ist weder Running noch mehrdeutig.
    func testCyclingOnlySessionIsCrossTrainingNotRunningNotAmbiguous() {
        let exercise = makeCardioExercise(sportKind: .cycling)
        let session = makeSession()
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: 20, durationSeconds: 3000)
        context.insert(log)

        let result = CardioHistoryExtractor.loggedSessions(from: [session])
        XCTAssertFalse(result[0].isRunning)
        XCTAssertTrue(result[0].isCrossTrainingOnly)
        XCTAssertFalse(result[0].hasAmbiguousCardio)
        XCTAssertNil(result[0].runningDistanceKm, "Rad-Distanz darf nie als Lauf-Distanz gezaehlt werden")
    }

    // Testfall 19: Cardio ohne gepflegte Sportart ist mehrdeutig, nie Laufen.
    func testAmbiguousCardioSessionNeverCountsAsRunning() {
        let exercise = makeCardioExercise(sportKind: nil)
        let session = makeSession()
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: 5, durationSeconds: 1800)
        context.insert(log)

        let result = CardioHistoryExtractor.loggedSessions(from: [session])
        XCTAssertFalse(result[0].isRunning)
        XCTAssertFalse(result[0].isCrossTrainingOnly)
        XCTAssertTrue(result[0].hasAmbiguousCardio)
        XCTAssertNil(result[0].runningDistanceKm)
    }

    // Testfall 9/17: reine Krafteinheit ist nie ein Lauf-Signal.
    func testStrengthOnlySessionHasNoCardioSignalAtAll() {
        let exercise = makeStrengthExercise()
        let session = makeSession()
        let log = ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: exercise, session: session)
        context.insert(log)

        let result = CardioHistoryExtractor.loggedSessions(from: [session])
        XCTAssertFalse(result[0].isRunning)
        XCTAssertFalse(result[0].isCrossTrainingOnly)
        XCTAssertFalse(result[0].hasAmbiguousCardio)
        XCTAssertTrue(result[0].hasStrengthActivity)
    }

    /// Testfall 23: eine Session mit sowohl Lauf- als auch Rad-Logs zaehlt
    /// als Running (fuer die Umfangszahlen), der Cross-Training-Kontext
    /// bleibt zusaetzlich sichtbar - keine der beiden Signale verdraengt
    /// die andere (Implementierungs-Ruling, siehe `CardioHistoryExtractor`-
    /// Typdoku).
    func testMixedRunAndCyclingSessionCountsAsRunningWithCrossTrainingContextPreserved() {
        let runExercise = makeCardioExercise(sportKind: .running)
        let bikeExercise = makeCardioExercise(sportKind: .cycling)
        let session = makeSession()
        context.insert(ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: runExercise, session: session, distanceKm: 5, durationSeconds: 1500))
        context.insert(ExerciseLog(setIndex: 1, weight: 0, reps: 0, rir: 0, exercise: bikeExercise, session: session, distanceKm: 10, durationSeconds: 1200))

        let result = CardioHistoryExtractor.loggedSessions(from: [session])
        XCTAssertTrue(result[0].isRunning)
        XCTAssertTrue(result[0].isCrossTrainingOnly, "der Rad-Anteil darf nicht verschwinden, nur weil auch gelaufen wurde")
        XCTAssertEqual(result[0].runningDistanceKm, 5, "nur der Lauf-Anteil zaehlt in die Lauf-Distanz")
    }

    /// Bugfix-Regression (kritischer Migrations-Fund): eine Session, deren
    /// Log `exerciseNameSnapshot` gesetzt (wie jeder Log seit DEL-051), aber
    /// das NEUE `exerciseEnduranceSportKindSnapshot` noch `nil` hat (additive
    /// Migration, Feld existierte beim urspruenglichen Loggen noch nicht),
    /// muss trotzdem korrekt als Laufen klassifiziert werden - ueber den
    /// Live-Fallback auf die noch vorhandene Exercise. Beweist, dass der Fix
    /// bis in den Extractor durchschlaegt, nicht nur auf `ExerciseLog` selbst.
    func testMigratedSessionWithNilSportKindSnapshotStillClassifiesAsRunningViaLiveExercise() {
        let exercise = makeCardioExercise(sportKind: .running)
        let session = makeSession()
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: 8, durationSeconds: 2400)
        context.insert(log)
        XCTAssertNotNil(log.exerciseNameSnapshot, "Testaufbau: wie jeder Log seit DEL-051")
        log.exerciseEnduranceSportKindSnapshot = nil

        let result = CardioHistoryExtractor.loggedSessions(from: [session])

        XCTAssertTrue(result[0].isRunning, "eine migrierte Lauf-Session darf nicht als unbekannt/nicht-Lauf erscheinen")
        XCTAssertEqual(result[0].runningDistanceKm, 8)
        XCTAssertFalse(result[0].hasAmbiguousCardio)
    }

    /// Anforderung 4: eine geloeschte `Exercise` darf die Klassifikation
    /// nicht veraendern - der Extractor liest `resolvedEnduranceSportKind`
    /// (Snapshot-first), nicht die Live-Exercise.
    func testExtractorStillClassifiesCorrectlyAfterExerciseDeletion() throws {
        let exercise = makeCardioExercise(sportKind: .running)
        let session = makeSession()
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: 5, durationSeconds: 1800)
        context.insert(log)
        try context.save()

        context.delete(exercise)
        try context.save()

        let result = CardioHistoryExtractor.loggedSessions(from: [session])
        XCTAssertTrue(result[0].isRunning, "die Klassifikation muss trotz geloeschter Exercise erhalten bleiben")
        XCTAssertEqual(result[0].runningDistanceKm, 5)
    }

    /// Nicht abgeschlossene/Ruhetage-Sessions sind kein echtes Training
    /// (`isRealWorkout`) und duerfen die Historie nicht verfaelschen.
    func testIncompleteAndRestDaySessionsAreExcluded() {
        let incomplete = makeSession(completed: false)
        let restDay = makeSession(isRestDay: true)
        let result = CardioHistoryExtractor.loggedSessions(from: [incomplete, restDay])
        XCTAssertTrue(result.isEmpty)
    }
}
#endif
