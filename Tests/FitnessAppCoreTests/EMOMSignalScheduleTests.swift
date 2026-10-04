import XCTest
@testable import FitnessAppCore

final class EMOMSignalScheduleTests: XCTestCase {

    private func delays(_ total: Int, _ elapsed: Int) -> [Int] {
        EMOMSignalSchedule.signals(totalMinutes: total, elapsedSeconds: elapsed).map(\.delaySeconds)
    }

    /// Am Start: ein Signal pro Minutenende, wie bisher.
    func testFreshRunSignalsEveryMinuteEnd() {
        let signals = EMOMSignalSchedule.signals(totalMinutes: 3, elapsedSeconds: 0)
        XCTAssertEqual(signals.map(\.minute), [1, 2, 3])
        XCTAssertEqual(signals.map(\.delaySeconds), [60, 120, 180])
        XCTAssertEqual(signals.map(\.isFinal), [false, false, true])
    }

    /// Mitten im Lauf (z.B. zurueck von einem anderen Tab): die Signale bleiben an
    /// der Startzeit ausgerichtet statt bei "jetzt" neu zu beginnen.
    func testMidRunSignalsStayAlignedToTheStart() {
        let signals = EMOMSignalSchedule.signals(totalMinutes: 4, elapsedSeconds: 90)
        XCTAssertEqual(signals.map(\.minute), [2, 3, 4])
        XCTAssertEqual(signals.map(\.delaySeconds), [30, 90, 150])
        XCTAssertEqual(signals.last?.isFinal, true)
    }

    /// Ein Signal, das genau jetzt faellig waere, entfaellt (Trigger >= 1 s).
    func testASignalDueRightNowIsSkipped() {
        XCTAssertEqual(delays(3, 60), [60, 120])
        XCTAssertEqual(delays(3, 59), [1, 61, 121])
    }

    func testNothingIsLeftAtOrAfterTheEnd() {
        XCTAssertEqual(delays(3, 180), [])
        XCTAssertEqual(delays(3, 9_999), [])
    }

    /// Eine Sekunde vor dem Ende bleibt nur noch das Abschluss-Signal.
    func testOnlyTheFinalSignalIsLeftInTheLastSecond() {
        let signals = EMOMSignalSchedule.signals(totalMinutes: 3, elapsedSeconds: 179)
        XCTAssertEqual(signals, [EMOMSignal(minute: 3, delaySeconds: 1, isFinal: true)])
    }

    func testNonsenseInputIsHarmless() {
        XCTAssertEqual(delays(0, 0), [])
        XCTAssertEqual(delays(-2, 10), [])
        XCTAssertEqual(delays(2, -30), [60, 120])
    }
}
