#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import SwiftData
@testable import DeltiqUI
import DeltiqData
import DeltiqHealth
import DeltiqCore

/// Dashboard-Fix "0.0 km vor Coaching-Beginn" (siehe Abschlussbericht):
/// `ExternalWorkoutImportService.insertSession` setzte `Exercise.
/// enduranceSportKind` nie, obwohl `sample.activityType` zum Importzeitpunkt
/// bekannt ist — damit klassifizierte `CardioHistoryExtractor` JEDEN
/// importierten Lauf dauerhaft als "Sportart unklar" statt "Laufen".
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ExternalWorkoutImportServiceSportKindTests: XCTestCase {

    var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(AppSchema.types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testSportKindMapsRunningAndCyclingActivityTypesCorrectly() {
        XCTAssertEqual(ExternalWorkoutImportService.sportKind(for: .running), .running)
        XCTAssertEqual(ExternalWorkoutImportService.sportKind(for: .cycling), .cycling)
    }

    private func makeSample(activityType: ExternalWorkoutActivityType, uuid: String = "hk-1") -> ExternalWorkoutSample {
        ExternalWorkoutSample(
            hkUUID: uuid,
            activityType: activityType,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_003_600),
            distanceKm: 8,
            sourceName: "Strava",
            sourceBundleIdentifier: "com.strava.app"
        )
    }

    /// Migrations-Backfill: eine bereits importierte Session (vor diesem Fix)
    /// hat eine Exercise mit `enduranceSportKind == nil`. Ein erneuter Sync
    /// liefert dasselbe Sample erneut (gleiche `hkUUID`) — der Backfill muss
    /// die Sportart nachtragen, nicht raten.
    func testBackfillSetsEnduranceSportKindWhenExerciseIsCardioAndUnclassified() {
        let day = TrainingDay(name: "Run", weekday: 1, type: .fullBody)
        context.insert(day)
        let exercise = Exercise(name: "Freier Lauf", isCardio: true, day: day)
        context.insert(exercise)
        let session = WorkoutSession(startTime: Date(timeIntervalSince1970: 1_700_000_000), isCompleted: true, isAdHoc: true, healthKitSampleUUID: "hk-1")
        context.insert(session)
        let log = ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: 8, durationSeconds: 3600)
        context.insert(log)
        XCTAssertNil(exercise.enduranceSportKind, "Testaufbau: unklassifizierter Alt-Import")

        ExternalWorkoutImportService.backfillEnduranceSportKindIfNeeded(session, from: makeSample(activityType: .running))

        XCTAssertEqual(exercise.enduranceSportKind, .running)
    }

    /// Bereits klassifizierte Exercises (z.B. nach diesem Fix neu importiert,
    /// oder manuell vom Nutzer gepflegt) duerfen NIE ueberschrieben werden —
    /// der Backfill ist ausschliesslich fuer echte Alt-Importe gedacht.
    func testBackfillNeverOverwritesAnAlreadyClassifiedExercise() {
        let day = TrainingDay(name: "Ride", weekday: 1, type: .fullBody)
        context.insert(day)
        let exercise = Exercise(name: "Radfahren (outdoor)", isCardio: true, day: day)
        exercise.enduranceSportKind = .cycling
        context.insert(exercise)
        let session = WorkoutSession(startTime: Date(timeIntervalSince1970: 1_700_000_000), isCompleted: true, isAdHoc: true, healthKitSampleUUID: "hk-1")
        context.insert(session)
        context.insert(ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: 20, durationSeconds: 3600))

        ExternalWorkoutImportService.backfillEnduranceSportKindIfNeeded(session, from: makeSample(activityType: .running))

        XCTAssertEqual(exercise.enduranceSportKind, .cycling, "ein bereits bekannter Wert darf nie ueberschrieben werden")
    }

    func testBackfillDoesNothingForAStrengthExercise() {
        let day = TrainingDay(name: "Legs", weekday: 1, type: .legs)
        context.insert(day)
        let exercise = Exercise(name: "Squat", isCardio: false, day: day)
        context.insert(exercise)
        let session = WorkoutSession(startTime: Date(timeIntervalSince1970: 1_700_000_000), isCompleted: true)
        context.insert(session)
        context.insert(ExerciseLog(setIndex: 0, weight: 100, reps: 5, rir: 2, exercise: exercise, session: session))

        ExternalWorkoutImportService.backfillEnduranceSportKindIfNeeded(session, from: makeSample(activityType: .running))

        XCTAssertNil(exercise.enduranceSportKind)
    }

    /// Wiederholte Synchronisierung desselben Samples (gleiche `hkUUID`) darf
    /// weder die Klassifikation noch die Objektanzahl veraendern - der
    /// Backfill ist bewusst idempotent, nicht nur "zufaellig beim ersten Mal
    /// richtig".
    func testRepeatedBackfillCallForTheSameSampleIsIdempotent() {
        let day = TrainingDay(name: "Run", weekday: 1, type: .fullBody)
        context.insert(day)
        let exercise = Exercise(name: "Freier Lauf", isCardio: true, day: day)
        context.insert(exercise)
        let session = WorkoutSession(startTime: Date(timeIntervalSince1970: 1_700_000_000), isCompleted: true, isAdHoc: true, healthKitSampleUUID: "hk-1")
        context.insert(session)
        context.insert(ExerciseLog(setIndex: 0, weight: 0, reps: 0, rir: 0, exercise: exercise, session: session, distanceKm: 8, durationSeconds: 3600))

        let sample = makeSample(activityType: .running)
        ExternalWorkoutImportService.backfillEnduranceSportKindIfNeeded(session, from: sample)
        ExternalWorkoutImportService.backfillEnduranceSportKindIfNeeded(session, from: sample)
        ExternalWorkoutImportService.backfillEnduranceSportKindIfNeeded(session, from: sample)

        XCTAssertEqual(exercise.enduranceSportKind, .running)
        XCTAssertEqual(session.logs.count, 1, "der Backfill darf nie neue Logs/Sessions anlegen, nur die bestehende Exercise klassifizieren")
    }

    // MARK: - Realer Importpfad (`insertSession`), nicht nur handgebaute Fixtures

    /// Deckt den TATSAECHLICHEN Produktionspfad ab: `insertSession` ist exakt
    /// die Funktion, die `syncExternalWorkouts` fuer jedes neue HealthKit-
    /// Sample aufruft. Ein Regressions-Test, der stattdessen von Hand eine
    /// bereits korrekt klassifizierte Exercise baut, wuerde einen erneuten
    /// Wegfall der `enduranceSportKind`-Zuweisung in `insertSession` selbst
    /// NICHT bemerken.
    func testInsertSessionViaTheRealImportPathClassifiesARunningSampleAsRunning() throws {
        let sample = ExternalWorkoutSample(
            hkUUID: "hk-run-1", activityType: .running,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_003_600),
            distanceKm: 10, sourceName: "Strava", sourceBundleIdentifier: "com.strava.app"
        )
        ExternalWorkoutImportService.insertSession(for: sample, in: context)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let session = try XCTUnwrap(sessions.first)
        let log = try XCTUnwrap(session.logs.first)

        XCTAssertEqual(log.exercise?.enduranceSportKind, .running)
        XCTAssertEqual(log.distanceKm, 10)

        let extracted = TrainingActivityExtractor.extract(from: sessions)
        XCTAssertTrue(extracted[0].isRunning)
        XCTAssertEqual(extracted[0].runningDistanceKm, 10)
    }

    func testInsertSessionViaTheRealImportPathClassifiesACyclingSampleAsCrossTrainingNeverAsRunning() throws {
        let sample = ExternalWorkoutSample(
            hkUUID: "hk-ride-1", activityType: .cycling,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_003_600),
            distanceKm: 25, sourceName: "Strava", sourceBundleIdentifier: "com.strava.app"
        )
        ExternalWorkoutImportService.insertSession(for: sample, in: context)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.logs.first?.exercise?.enduranceSportKind, .cycling)

        let extracted = TrainingActivityExtractor.extract(from: sessions)
        XCTAssertFalse(extracted[0].isRunning, "ein importierter Radfahrt-Sample darf nie als Laufen gezaehlt werden")
        XCTAssertTrue(extracted[0].isCrossTrainingOnly)
        XCTAssertNil(extracted[0].runningDistanceKm)
    }

    /// Ticket-Anforderung: realistischer Bestand aus Lauf- UND Radfahrten -
    /// die resultierenden Laufkilometer duerfen AUSSCHLIESSLICH aus den
    /// Laufaktivitaeten stammen, unabhaengig von der Reihenfolge des Imports.
    func testRealisticMixOfRunningAndCyclingImportsOnlyCountsRunningDistance() throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 86400
        let samples: [(ExternalWorkoutActivityType, Double, TimeInterval)] = [
            (.running, 10, 0), (.cycling, 30, 1 * day), (.running, 8, 2 * day),
            (.cycling, 45, 3 * day), (.running, 12, 4 * day),
        ]
        for (index, entry) in samples.enumerated() {
            let (activity, km, offset) = entry
            ExternalWorkoutImportService.insertSession(for: ExternalWorkoutSample(
                hkUUID: "hk-mixed-\(index)", activityType: activity,
                startDate: base.addingTimeInterval(offset), endDate: base.addingTimeInterval(offset + 3600),
                distanceKm: km, sourceName: "Strava", sourceBundleIdentifier: "com.strava.app"
            ), in: context)
        }

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 5)
        let extracted = TrainingActivityExtractor.extract(from: sessions)

        let totalRunningKm = extracted.compactMap(\.runningDistanceKm).reduce(0, +)
        XCTAssertEqual(totalRunningKm, 10 + 8 + 12, "Laufkilometer duerfen ausschliesslich aus den 3 Laufaktivitaeten stammen")
        XCTAssertEqual(extracted.filter(\.isCrossTrainingOnly).count, 2)
        XCTAssertEqual(extracted.filter(\.isRunning).count, 3)
        XCTAssertTrue(extracted.filter(\.isCrossTrainingOnly).allSatisfy { $0.runningDistanceKm == nil })
    }
}
#endif
