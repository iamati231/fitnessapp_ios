import XCTest
@testable import FitnessAppCore

final class PausableTimerStateTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testIdleStateHasZeroElapsed() {
        let state = PausableTimerState()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertEqual(state.elapsed(now: t0), 0)
    }

    func testRunningElapsedGrowsWithWallClock() {
        var state = PausableTimerState()
        state.start(now: t0)
        XCTAssertEqual(state.elapsed(now: t0.addingTimeInterval(5)), 5, accuracy: 1e-9)
        XCTAssertEqual(state.elapsed(now: t0.addingTimeInterval(30)), 30, accuracy: 1e-9)
    }

    func testPauseFreezesElapsedUntilResumed() {
        var state = PausableTimerState()
        state.start(now: t0)
        state.pause(now: t0.addingTimeInterval(10))
        XCTAssertEqual(state.phase, .paused)
        // Weiterhin 10s, egal wie viel Wand-Zeit seitdem vergangen ist.
        XCTAssertEqual(state.elapsed(now: t0.addingTimeInterval(500)), 10, accuracy: 1e-9)
    }

    func testResumeContinuesFromThePausedElapsedValue() {
        var state = PausableTimerState()
        state.start(now: t0)
        state.pause(now: t0.addingTimeInterval(10))
        state.resume(now: t0.addingTimeInterval(100)) // lange Pause-Dauer, darf nicht mitzaehlen
        XCTAssertEqual(state.phase, .running)
        XCTAssertEqual(state.elapsed(now: t0.addingTimeInterval(105)), 15, accuracy: 1e-9)
    }

    func testMultiplePauseResumeCyclesAccumulateCorrectly() {
        var state = PausableTimerState()
        state.start(now: t0)
        state.pause(now: t0.addingTimeInterval(5))   // 5s erfasst
        state.resume(now: t0.addingTimeInterval(20))
        state.pause(now: t0.addingTimeInterval(23))  // +3s = 8s erfasst
        state.resume(now: t0.addingTimeInterval(50))
        XCTAssertEqual(state.elapsed(now: t0.addingTimeInterval(52)), 10, accuracy: 1e-9) // +2s = 10s
    }

    func testCancelResetsToZeroAndIdle() {
        var state = PausableTimerState()
        state.start(now: t0)
        _ = state.elapsed(now: t0.addingTimeInterval(20))
        state.cancel()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertEqual(state.elapsed(now: t0.addingTimeInterval(1000)), 0)
    }

    func testFinishFreezesElapsedPermanently() {
        var state = PausableTimerState()
        state.start(now: t0)
        state.finish(now: t0.addingTimeInterval(30))
        XCTAssertEqual(state.phase, .finished)
        XCTAssertEqual(state.elapsed(now: t0.addingTimeInterval(9999)), 30, accuracy: 1e-9)
    }

    func testPauseWhileNotRunningIsANoOp() {
        var state = PausableTimerState()
        state.pause(now: t0) // idle -> no-op
        XCTAssertEqual(state.phase, .idle)

        state.start(now: t0)
        state.pause(now: t0.addingTimeInterval(5))
        state.pause(now: t0.addingTimeInterval(50)) // already paused -> no-op, must not double-count
        XCTAssertEqual(state.elapsed(now: t0.addingTimeInterval(100)), 5, accuracy: 1e-9)
    }

    func testResumeWhileNotPausedIsANoOp() {
        var state = PausableTimerState()
        state.resume(now: t0) // idle -> no-op
        XCTAssertEqual(state.phase, .idle)

        state.start(now: t0)
        state.resume(now: t0.addingTimeInterval(5)) // already running -> no-op
        XCTAssertEqual(state.elapsed(now: t0.addingTimeInterval(10)), 10, accuracy: 1e-9)
    }

    /// Simuliert einen Hintergrundwechsel: die View haelt kein eigenes
    /// Zaehl-Intervall, sondern fragt bei jedem Redraw `elapsed(now:)` neu ab
    /// — ein langes Zeit-Delta (z.B. 10 Minuten im Hintergrund) darf beim
    /// naechsten Redraw sofort korrekt erscheinen, ohne nachzulaufen.
    func testSurvivesALongGapLikeBackgroundingWithoutDrift() {
        var state = PausableTimerState()
        state.start(now: t0)
        let afterBackgrounding = t0.addingTimeInterval(600)
        XCTAssertEqual(state.elapsed(now: afterBackgrounding), 600, accuracy: 1e-9)
    }
}
