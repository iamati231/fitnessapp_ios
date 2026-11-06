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
}
#endif
