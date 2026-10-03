import XCTest
@testable import FitnessAppCore

final class SessionDurationEstimatorTests: XCTestCase {

    private typealias Input = SessionDurationEstimator.LogInput

    private func run(_ seconds: Int?) -> Input {
        Input(isCardio: true, durationSeconds: seconds)
    }

    private func lifts(_ count: Int, rest: Int? = nil) -> [Input] {
        Array(repeating: Input(isCardio: false, restSeconds: rest), count: count)
    }

    private func estimate(wall: Int, _ logs: [Input]) -> SessionDurationEstimate {
        SessionDurationEstimator.estimate(wallClockSeconds: wall, logs: logs)
    }

    // MARK: - Cardio: die eingetragene Zeit

    /// Der Fall aus dem Screenshot: Lauf nachgetragen (4,51 km in 25:56), Start und
    /// Beenden nur eine Minute auseinander.
    func testRetroLoggedRunTakesTheLoggedTime() {
        let result = estimate(wall: 60, [run(25 * 60 + 56)])
        XCTAssertEqual(result.minutes, 26)
        XCTAssertEqual(result.basis, .loggedCardioTime)
        XCTAssertTrue(result.isCorrected)
    }

    func testLiveRunKeepsTheWallClock() {
        let result = estimate(wall: 27 * 60 + 10, [run(25 * 60 + 56)])
        XCTAssertEqual(result.minutes, 27)
        XCTAssertEqual(result.basis, .measured)
        XCTAssertFalse(result.isCorrected)
    }

    func testSmallDifferenceWithinToleranceStaysMeasured() {
        // 56 s Unterschied <= 60 s Toleranz: Start kurz nach dem Loslaufen.
        XCTAssertEqual(estimate(wall: 1500, [run(1556)]).basis, .measured)
        XCTAssertEqual(estimate(wall: 1500, [run(1556)]).minutes, 25)
        // 76 s: nicht mehr.
        let beyond = estimate(wall: 1480, [run(1556)])
        XCTAssertEqual(beyond.basis, .loggedCardioTime)
        XCTAssertEqual(beyond.minutes, 26)
    }

    func testSeveralCardioSetsAreSummed() {
        // 5 min Einlaufen + 25:56 Lauf.
        XCTAssertEqual(estimate(wall: 120, [run(300), run(1556)]).minutes, 31)
    }

    func testCardioWithoutAnyTimeIsMeasured() {
        XCTAssertEqual(estimate(wall: 60, [run(nil)]).basis, .measured)
        XCTAssertEqual(estimate(wall: 60, [run(0), run(-5)]).minutes, 1)
    }

    // MARK: - Kraft: Schätzung aus den Sätzen

    func testRetroLoggedStrengthIsEstimatedFromTheSets() {
        // 12 Sätze in 3 Minuten eingetippt; je Satz 45 s + 90 s Standardpause.
        let result = estimate(wall: 180, lifts(12))
        XCTAssertEqual(result.minutes, 27)
        XCTAssertEqual(result.basis, .estimatedFromSets)
    }

    func testStrengthEstimateUsesTheRestTimeOfTheExercise() {
        // 3 Sätze mit 180 s Pause: 3 x 225 s = 675 s -> 11 min.
        XCTAssertEqual(estimate(wall: 60, lifts(3, rest: 180)).minutes, 11)
        // Pause 0 (Drop-/Supersätze): nur die Satzzeit.
        XCTAssertEqual(estimate(wall: 30, lifts(4, rest: 0)).minutes, 3)
        // Absurde Pause wird begrenzt (300 s).
        XCTAssertEqual(estimate(wall: 30, lifts(3, rest: 9999)).minutes, 17)
    }

    func testLiveStrengthKeepsTheWallClock() {
        let result = estimate(wall: 40 * 60, lifts(12))
        XCTAssertEqual(result.minutes, 40)
        XCTAssertEqual(result.basis, .measured)
    }

    /// Grenze: weniger als 30 s je Satz gilt als Eintragen, nicht als Training.
    func testStrengthBoundaryIsThirtySecondsPerSet() {
        XCTAssertEqual(estimate(wall: 12 * 30, lifts(12)).basis, .measured)
        XCTAssertEqual(estimate(wall: 12 * 30 - 1, lifts(12)).basis, .estimatedFromSets)
    }

    func testFewSetsAreNeverEstimated() {
        XCTAssertEqual(estimate(wall: 30, lifts(2)).basis, .measured)
        XCTAssertEqual(estimate(wall: 30, lifts(2)).minutes, 0)
        XCTAssertEqual(estimate(wall: 89, lifts(3)).basis, .estimatedFromSets)
    }

    // MARK: - Mischtage

    func testRetroMixedSessionSumsCardioAndTheStrengthEstimate() {
        // 6 Kraft-Sätze (6 x 135 s = 810 s) + 20 min Cardio = 2010 s -> 34 min.
        let result = estimate(wall: 120, lifts(6) + [run(1200)])
        XCTAssertEqual(result.minutes, 34)
        XCTAssertEqual(result.basis, .estimatedFromSets)
    }

    func testLiveStrengthWithALongerRetroLoggedRunAddsUp() {
        // 40 min live trainiert, danach einen 45-min-Lauf nachgetragen: die Wanduhr
        // kann den Lauf nicht enthalten -> Cardio 45 min + 10 Sätze (1350 s) = 68 min.
        let result = estimate(wall: 40 * 60, lifts(10) + [run(45 * 60)])
        XCTAssertEqual(result.minutes, 68)
    }

    func testLiveMixedSessionKeepsTheWallClock() {
        // 20 min Cardio innerhalb von 70 min Wanduhr.
        XCTAssertEqual(estimate(wall: 70 * 60, lifts(8) + [run(20 * 60)]).basis, .measured)
    }

    // MARK: - Grenzfälle

    func testEmptyLogsAndNegativeWallClockAreMeasured() {
        XCTAssertEqual(estimate(wall: 600, []).minutes, 10)
        XCTAssertEqual(estimate(wall: -5, []).minutes, 0)
        XCTAssertEqual(estimate(wall: -5, []).basis, .measured)
    }

    func testMeasuredMinutesAreFlooredLikeBefore() {
        // Wie bisher `Int(interval / 60)`: 59 s -> 0, 119 s -> 1.
        XCTAssertEqual(estimate(wall: 59, []).minutes, 0)
        XCTAssertEqual(estimate(wall: 119, []).minutes, 1)
    }

    func testCorrectedDurationIsCapped() {
        XCTAssertEqual(estimate(wall: 60, [run(20 * 3600)]).minutes, SessionDurationEstimator.maximumMinutes)
    }

    // MARK: - Reparatur bestehender Trainings

    func testRepairRaisesAShortStoredDurationToTheLoggedCardioTime() {
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 1, logs: [run(1556)]), 26)
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 0, logs: [run(1556)]), 26)
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 20, logs: [run(1556)]), 26)
    }

    func testRepairLeavesPlausibleDurationsAlone() {
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 26, logs: [run(1556)]))
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 45, logs: [run(1556)]))
        // Innerhalb der Toleranz.
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 25, logs: [run(1556)]))
    }

    /// Kraft wird bei bestehenden Daten nie geschätzt, nur gemessene Cardio-Zeit zählt.
    func testRepairIgnoresStrengthAndMissingTimes() {
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 2, logs: lifts(12)))
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 1, logs: [run(nil)]))
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 1, logs: []))
        // Mischtag: nur der Cardio-Anteil als untere Grenze.
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 2, logs: lifts(12) + [run(1200)]), 20)
    }

    func testRepairIsCappedAndNeverLowersTheStoredValue() {
        XCTAssertEqual(
            SessionDurationEstimator.repairedMinutes(storedMinutes: 1, logs: [run(20 * 3600)]),
            SessionDurationEstimator.maximumMinutes
        )
        // Bereits über der Obergrenze gespeichert: nichts tun.
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 700, logs: [run(20 * 3600)]))
    }
}
