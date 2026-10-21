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
    /// Beenden nur eine Minute auseinander. Die Minuten werden wie ueberall
    /// ABGERUNDET (nie 26), die Sekunden bleiben genau.
    func testRetroLoggedRunTakesTheLoggedTime() {
        let result = estimate(wall: 60, [run(25 * 60 + 56)])
        XCTAssertEqual(result.seconds, 25 * 60 + 56)
        XCTAssertEqual(result.minutes, 25)
        XCTAssertEqual(result.basis, .loggedCardioTime)
        XCTAssertTrue(result.isCorrected)
    }

    /// Nie aufrunden: 32:53 sind 32 Min, 18:57 sind 18 Min — wie die Wanduhr-Dauer.
    func testMinutesAreAlwaysFlooredNeverRoundedUp() {
        XCTAssertEqual(estimate(wall: 60, [run(32 * 60 + 53)]).minutes, 32)
        XCTAssertEqual(estimate(wall: 60, [run(18 * 60 + 57)]).minutes, 18)
        XCTAssertEqual(estimate(wall: 60, [run(19 * 60)]).minutes, 19)
        XCTAssertEqual(estimate(wall: 60, [run(19 * 60 + 59)]).seconds, 19 * 60 + 59)
    }

    /// Ein einzelner Lauf ist das ganze Training: Seine eingetragene Zeit ist die
    /// Dauer — auch wenn die Wanduhr laenger war (Start vor dem Loslaufen).
    func testSingleRunTakesItsLoggedTimeEvenWhenTheWallClockIsLonger() {
        let result = estimate(wall: 27 * 60 + 10, [run(25 * 60 + 56)])
        XCTAssertEqual(result.seconds, 25 * 60 + 56)
        XCTAssertEqual(result.minutes, 25)
        XCTAssertEqual(result.basis, .loggedCardioTime)
        XCTAssertTrue(result.isCorrected)
        // Offen gelassenes Training: 3 h Wanduhr, 30 min Lauf.
        XCTAssertEqual(estimate(wall: 3 * 3600, [run(30 * 60)]).minutes, 30)
    }

    /// Mehrere Cardio-Saetze (z.B. Intervalle mit Pausen) behalten die Wanduhr,
    /// solange sie nicht kuerzer ist als die Summe.
    func testSeveralCardioSetsKeepALongerWallClock() {
        let result = estimate(wall: 40 * 60, [run(300), run(1556)])
        XCTAssertEqual(result.basis, .measured)
        XCTAssertEqual(result.minutes, 40)
    }

    /// Reines Cardio: Die eingetragene Zeit ist die Dauer, sobald sie die Wanduhr
    /// ueberschreitet — auch knapp, damit neben dem Satz "32:53" nicht "32:41" steht.
    func testPureCardioUsesTheLoggedTimeEvenWhenItOnlyBarelyExceedsTheWallClock() {
        let barely = estimate(wall: 32 * 60 + 41, [run(32 * 60 + 53)])
        XCTAssertEqual(barely.basis, .loggedCardioTime)
        XCTAssertEqual(barely.seconds, 32 * 60 + 53)
        XCTAssertEqual(barely.minutes, 32)
        XCTAssertEqual(estimate(wall: 1500, [run(1556)]).seconds, 1556)
        // Mehrere Cardio-Saetze, Wanduhr gleich lang oder laenger als die Summe: Wanduhr.
        XCTAssertEqual(estimate(wall: 1856, [run(300), run(1556)]).basis, .measured)
        XCTAssertEqual(estimate(wall: 2000, [run(300), run(1556)]).seconds, 2000)
        // Barely-Fall mit zwei Saetzen: die Summe ueberschreitet die Wanduhr.
        XCTAssertEqual(estimate(wall: 1800, [run(300), run(1556)]).seconds, 1856)
    }

    /// Bei Mischtagen bleibt die Toleranz: Die Cardio-Zeit kann Teil einer
    /// laengeren Wanduhr sein.
    func testMixedSessionKeepsTheToleranceForCardio() {
        let logs = lifts(8) + [run(1556)]
        XCTAssertEqual(estimate(wall: 1500 + 600, logs).basis, .measured)
        // Wanduhr 25:00 mit 8 Saetzen: Cardio 56 s darueber, innerhalb der Toleranz.
        XCTAssertEqual(estimate(wall: 1500, logs).basis, .measured)
        XCTAssertEqual(estimate(wall: 1480, logs).basis, .estimatedFromSets)
    }

    func testSeveralCardioSetsAreSummed() {
        // 5 min Einlaufen + 25:56 Lauf = 30:56.
        let result = estimate(wall: 120, [run(300), run(1556)])
        XCTAssertEqual(result.seconds, 1856)
        XCTAssertEqual(result.minutes, 30)
    }

    func testCardioWithoutAnyTimeIsMeasured() {
        XCTAssertEqual(estimate(wall: 60, [run(nil)]).basis, .measured)
        XCTAssertEqual(estimate(wall: 60, [run(0), run(-5)]).minutes, 1)
    }

    // MARK: - Kraft: Schätzung aus den Sätzen

    func testRetroLoggedStrengthIsEstimatedFromTheSets() {
        // 12 Sätze in 3 Minuten eingetippt; je Satz 45 s + 90 s Standardpause.
        let result = estimate(wall: 180, lifts(12))
        XCTAssertEqual(result.seconds, 1620)
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
        // 6 Kraft-Sätze (6 x 135 s = 810 s) + 20 min Cardio = 2010 s -> 33 min (abgerundet).
        let result = estimate(wall: 120, lifts(6) + [run(1200)])
        XCTAssertEqual(result.minutes, 33)
        XCTAssertEqual(result.basis, .estimatedFromSets)
    }

    func testLiveStrengthWithALongerRetroLoggedRunAddsUp() {
        // 40 min live trainiert, danach einen 45-min-Lauf nachgetragen: die Wanduhr
        // kann den Lauf nicht enthalten -> Cardio 45 min + 10 Sätze (1350 s) = 4050 s -> 67 min.
        let result = estimate(wall: 40 * 60, lifts(10) + [run(45 * 60)])
        XCTAssertEqual(result.minutes, 67)
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
        // 25:56 -> 25 Min (abgerundet, wie ueberall).
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 1, logs: [run(1556)]), 25)
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 0, logs: [run(1556)]), 25)
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 20, logs: [run(1556)]), 25)
    }

    /// Mehrere Cardio-Saetze: Eine plausible (laengere) Dauer wird nie gekuerzt.
    func testRepairLeavesPlausibleDurationsOfSeveralSetsAlone() {
        let logs = [run(300), run(1556)]
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 31, logs: logs))
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 45, logs: logs))
        // Innerhalb der Toleranz (Summe 30:56, gespeichert 30).
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 30, logs: logs))
    }

    /// Kraft wird bei bestehenden Daten nie geschätzt, nur gemessene Cardio-Zeit zählt.
    func testRepairIgnoresStrengthAndMissingTimes() {
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 2, logs: lifts(12)))
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 1, logs: [run(nil)]))
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 1, logs: []))
        // Mischtag: nur der Cardio-Anteil als untere Grenze.
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 2, logs: lifts(12) + [run(1200)]), 20)
    }

    func testRepairIsCappedAndNeverLowersTheStoredValueOfSeveralSets() {
        XCTAssertEqual(
            SessionDurationEstimator.repairedMinutes(storedMinutes: 1, logs: [run(20 * 3600)]),
            SessionDurationEstimator.maximumMinutes
        )
        // Mehrere Saetze, bereits ueber der Obergrenze gespeichert: nichts tun.
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 700, logs: [run(20 * 3600), run(60)]))
    }

    // MARK: - Genaue Dauer

    func testExactSecondsWhenStartAndEndMatchTheStoredMinutes() {
        XCTAssertEqual(SessionDurationEstimator.exactSeconds(startToEndSeconds: 1556, storedMinutes: 25), 1556)
        XCTAssertEqual(SessionDurationEstimator.exactSeconds(startToEndSeconds: 1137, storedMinutes: 18), 1137)
        XCTAssertEqual(SessionDurationEstimator.exactSeconds(startToEndSeconds: 3903, storedMinutes: 65), 3903)
    }

    /// Im Verlauf geaenderte Dauer oder veraltetes Ende: nur die Minuten stimmen.
    func testNoExactSecondsWhenTheTimesDoNotMatchTheStoredMinutes() {
        XCTAssertNil(SessionDurationEstimator.exactSeconds(startToEndSeconds: 1556, storedMinutes: 30))
        XCTAssertNil(SessionDurationEstimator.exactSeconds(startToEndSeconds: 60, storedMinutes: 26))
        XCTAssertNil(SessionDurationEstimator.exactSeconds(startToEndSeconds: 0, storedMinutes: 0))
        XCTAssertNil(SessionDurationEstimator.exactSeconds(startToEndSeconds: -5, storedMinutes: 0))
    }

    // MARK: - Einzelner Lauf: Anzeige und Reparatur auch bei alten Einheiten

    func testSingleRunSecondsNeedsExactlyOneCardioSetWithATime() {
        XCTAssertEqual(SessionDurationEstimator.singleRunSeconds(in: [run(1556)]), 1556)
        XCTAssertNil(SessionDurationEstimator.singleRunSeconds(in: [run(nil)]))
        XCTAssertNil(SessionDurationEstimator.singleRunSeconds(in: [run(0)]))
        XCTAssertNil(SessionDurationEstimator.singleRunSeconds(in: [run(300), run(1556)]))
        XCTAssertNil(SessionDurationEstimator.singleRunSeconds(in: lifts(1)))
        XCTAssertNil(SessionDurationEstimator.singleRunSeconds(in: lifts(3) + [run(1556)]))
        XCTAssertNil(SessionDurationEstimator.singleRunSeconds(in: []))
    }

    /// Alte Einheit: Wanduhr 1 Min gespeichert, Lauf 25:56. Die Anzeige zeigt die
    /// Laufzeit, sobald die gespeicherten Minuten dazu passen (Reparatur), ohne
    /// Beginn und Ende anzufassen.
    func testDisplaySecondsUsesTheRunTimeWhenTheStoredMinutesMatch() {
        XCTAssertEqual(
            SessionDurationEstimator.displaySeconds(startToEndSeconds: 60, storedMinutes: 25, logs: [run(1556)]),
            1556
        )
    }

    /// Wurde die Dauer im Verlauf geaendert, gilt die Aenderung: keine Sekunden.
    func testDisplaySecondsHonoursAManuallyEditedDuration() {
        XCTAssertNil(
            SessionDurationEstimator.displaySeconds(startToEndSeconds: 60, storedMinutes: 30, logs: [run(1556)])
        )
    }

    func testDisplaySecondsFallsBackToStartAndEndWithoutASingleRun() {
        XCTAssertEqual(
            SessionDurationEstimator.displaySeconds(startToEndSeconds: 2407, storedMinutes: 40, logs: lifts(12)),
            2407
        )
        XCTAssertNil(
            SessionDurationEstimator.displaySeconds(startToEndSeconds: 2407, storedMinutes: 45, logs: lifts(12))
        )
    }

    /// Reparatur eines einzelnen Laufs geht in beide Richtungen.
    func testRepairSetsASingleRunToItsRunTimeInBothDirections() {
        // Zu kurz (nachgetragen) und aufgerundet vom frueheren Build (26).
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 1, logs: [run(1556)]), 25)
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 26, logs: [run(1556)]), 25)
        // Zu lang (Wanduhr laenger als der Lauf, offen gelassenes Training).
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 33, logs: [run(1556)]), 25)
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 1440, logs: [run(30 * 60)]), 30)
        // Schon richtig.
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 25, logs: [run(1556)]))
        // Mehrere Cardio-Saetze: nur der sichere Fall (zu kurz), nie kuerzen.
        XCTAssertNil(SessionDurationEstimator.repairedMinutes(storedMinutes: 40, logs: [run(300), run(1556)]))
        XCTAssertEqual(SessionDurationEstimator.repairedMinutes(storedMinutes: 2, logs: [run(300), run(1556)]), 30)
    }
}
