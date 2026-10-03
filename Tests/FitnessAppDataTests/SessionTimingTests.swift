#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

/// Die Anbindung von `SessionDurationEstimator` an die SwiftData-Session:
/// `finalizeTiming` (Beenden) und `repairShortDuration` (bestehende Laeufe). Die
/// Regel selbst ist in `SessionDurationEstimatorTests` (Core) abgedeckt.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class SessionTimingTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(AppSchema.types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    private var context: ModelContext { container.mainContext }
    private let start = Date(timeIntervalSince1970: 1_760_000_000)

    // MARK: - Builders

    private func makeSession(durationMinutes: Int = 0) -> WorkoutSession {
        let session = WorkoutSession(
            startTime: start,
            endTime: start,
            durationMinutes: durationMinutes,
            exerciseCount: 1,
            totalSets: 0,
            totalVolumeKg: 0,
            isCompleted: false,
            dayName: "Test"
        )
        context.insert(session)
        return session
    }

    /// Ein Cardio-Satz mit Distanz und eingetragener Zeit.
    private func addRun(to session: WorkoutSession, seconds: Int, km: Double) {
        let log = ExerciseLog(
            date: start, setIndex: 0, weight: 0, reps: 0, rir: 0,
            session: session, distanceKm: km, durationSeconds: seconds
        )
        log.exerciseNameSnapshot = "Freier Lauf"
        log.exerciseIsCardioSnapshot = true
        context.insert(log)
        try? context.save()
    }

    private func addLifts(to session: WorkoutSession, count: Int) {
        for index in 0..<count {
            let log = ExerciseLog(
                date: start, setIndex: index, weight: 80, reps: 8, rir: 2, session: session
            )
            log.exerciseNameSnapshot = "Bankdruecken"
            context.insert(log)
        }
        try? context.save()
    }

    // MARK: - finalizeTiming

    /// Der Fall aus dem Screenshot: Lauf (4,51 km in 25:56) eine Minute nach dem
    /// Start eingetragen und beendet.
    func testRetroLoggedRunGetsTheLoggedTimeAndEndsAtFinish() {
        let session = makeSession()
        addRun(to: session, seconds: 25 * 60 + 56, km: 4.51)
        let end = start.addingTimeInterval(60)

        let estimate = session.finalizeTiming(endingAt: end)

        XCTAssertEqual(estimate.basis, .loggedCardioTime)
        // Abgerundet wie ueberall (nie 26), der Beginn aber sekundengenau.
        XCTAssertEqual(session.durationMinutes, 25)
        XCTAssertEqual(session.endTime, end)
        XCTAssertEqual(session.startTime, end.addingTimeInterval(-Double(25 * 60 + 56)))
        // Beginn, Ende und Dauer passen zusammen.
        XCTAssertEqual(session.endTime.timeIntervalSince(session.startTime), Double(25 * 60 + 56), accuracy: 0.001)
    }

    func testLiveRunKeepsTheWallClockAndTheStart() {
        let session = makeSession()
        addRun(to: session, seconds: 25 * 60 + 56, km: 4.51)
        let end = start.addingTimeInterval(27 * 60 + 10)

        let estimate = session.finalizeTiming(endingAt: end)

        XCTAssertEqual(estimate.basis, .measured)
        XCTAssertEqual(session.durationMinutes, 27)
        XCTAssertEqual(session.startTime, start)
        XCTAssertEqual(session.endTime, end)
    }

    func testRetroLoggedStrengthIsEstimatedFromTheSets() {
        let session = makeSession()
        addLifts(to: session, count: 12)
        let end = start.addingTimeInterval(180)

        let estimate = session.finalizeTiming(endingAt: end)

        XCTAssertEqual(estimate.basis, .estimatedFromSets)
        XCTAssertEqual(session.durationMinutes, 27)   // 12 x (45 s + 90 s Standardpause)
        XCTAssertEqual(session.startTime, end.addingTimeInterval(-27 * 60))
    }

    func testLiveStrengthKeepsTheWallClock() {
        let session = makeSession()
        addLifts(to: session, count: 12)
        let end = start.addingTimeInterval(40 * 60)

        session.finalizeTiming(endingAt: end)

        XCTAssertEqual(session.durationMinutes, 40)
        XCTAssertEqual(session.startTime, start)
    }

    /// Nie ausgefuellte Platzhalter-Zeilen zaehlen nicht als Saetze.
    func testPlaceholderRowsDoNotTriggerAnEstimate() {
        let session = makeSession()
        for index in 0..<5 {
            context.insert(ExerciseLog(
                date: start, setIndex: index, weight: 0, reps: 0, rir: 0, session: session
            ))
        }
        try? context.save()

        let estimate = session.finalizeTiming(endingAt: start.addingTimeInterval(30))

        XCTAssertEqual(estimate.basis, .measured)
        XCTAssertEqual(session.durationMinutes, 0)
        XCTAssertEqual(session.startTime, start)
    }

    // MARK: - Genaue Dauer

    func testExactDurationTextShowsTheSecondsWhenStartAndEndMatch() {
        let session = makeSession()
        addRun(to: session, seconds: 25 * 60 + 56, km: 4.51)
        session.finalizeTiming(endingAt: start.addingTimeInterval(60))

        XCTAssertEqual(session.exactDurationSeconds, 25 * 60 + 56)
        XCTAssertEqual(session.exactDurationText, "25:56")
    }

    /// Live gelaufen, Start einige Sekunden nach dem Loslaufen: Die Dauer ist die
    /// eingetragene Laufzeit, nicht die etwas kuerzere Wanduhr.
    func testBarelyShorterWallClockStillShowsTheLoggedRunTime() {
        let session = makeSession()
        addRun(to: session, seconds: 32 * 60 + 53, km: 5.03)
        session.finalizeTiming(endingAt: start.addingTimeInterval(32 * 60 + 41))

        XCTAssertEqual(session.durationMinutes, 32)
        XCTAssertEqual(session.exactDurationText, "32:53")
    }

    func testLiveSessionShowsItsWallClockToTheSecond() {
        let session = makeSession()
        addLifts(to: session, count: 12)
        session.finalizeTiming(endingAt: start.addingTimeInterval(40 * 60 + 7))

        XCTAssertEqual(session.exactDurationText, "40:07")
    }

    /// Nach einer im Verlauf geaenderten Dauer passen Beginn und Ende nicht mehr:
    /// nur die Minuten sind verlaesslich.
    func testNoExactDurationAfterTheDurationWasEditedInTheHistory() {
        let session = makeSession()
        addLifts(to: session, count: 12)
        session.finalizeTiming(endingAt: start.addingTimeInterval(40 * 60 + 7))
        session.durationMinutes = 45

        XCTAssertNil(session.exactDurationSeconds)
        XCTAssertNil(session.exactDurationText)
    }

    // MARK: - repairShortDuration

    func testRepairRaisesAShortStoredDurationAndLeavesTheTimesAlone() {
        let session = makeSession(durationMinutes: 1)
        session.endTime = start.addingTimeInterval(60)
        addRun(to: session, seconds: 25 * 60 + 56, km: 4.51)

        XCTAssertTrue(session.repairShortDuration())

        XCTAssertEqual(session.durationMinutes, 25)
        XCTAssertEqual(session.startTime, start)
        XCTAssertEqual(session.endTime, start.addingTimeInterval(60))
        // Zweiter Lauf: nichts mehr zu tun.
        XCTAssertFalse(session.repairShortDuration())
    }

    func testRepairNeverTouchesStrengthOrPlausibleDurations() {
        let strength = makeSession(durationMinutes: 2)
        addLifts(to: strength, count: 12)
        XCTAssertFalse(strength.repairShortDuration())
        XCTAssertEqual(strength.durationMinutes, 2)

        let longRun = makeSession(durationMinutes: 45)
        addRun(to: longRun, seconds: 25 * 60 + 56, km: 4.51)
        XCTAssertFalse(longRun.repairShortDuration())
        XCTAssertEqual(longRun.durationMinutes, 45)
    }
}
#endif
