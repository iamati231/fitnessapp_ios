#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest
import FitnessAppCore
@testable import FitnessAppUI

/// Audit Fix 4: `TimedWorkoutBackground`'s token guard was flagged as risky,
/// untested state machine — "Training fortsetzen" hands a running Zeitformat
/// a NEW token while the old player's `end()` is still in flight; a stale
/// `end`/`sync` must be a no-op, or it would tear down the newer run instead
/// of the one it actually belongs to.
///
/// `TimedWorkoutBackground.shared` is a real `@MainActor` singleton wired to
/// live `AVAudioSession`/`ActivityKit` side effects, so these tests only
/// exercise `begin`/`end` with `soundEnabled: false` (never triggers
/// `audio.start()`) and never call `sync(...)` (the only path that touches
/// `TimedWorkoutActivityController.apply`) — `end`'s `TimedWorkoutActivityController.end()`
/// call is a documented no-op without a running activity (see its header
/// comment: "Auf Nicht-iOS-Plattformen ... ist jede Methode ein No-Op", and on
/// iOS it does nothing when no activity was ever requested). That keeps the
/// test deterministic and side-effect-free while still exercising the real
/// stale-token guard in production code, not a reimplementation of it.
///
/// `activeToken` is `private(set)` instead of `private` specifically so this
/// `@testable import` can observe it — the same pattern already used by
/// `AddMealViewDiscardTests`' `MealDraftItemFieldsSnapshot`.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class TimedWorkoutBackgroundTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset the shared singleton to "no active run" before each test —
        // it has no per-test isolation of its own.
        TimedWorkoutBackground.shared.endAll()
    }

    override func tearDown() {
        TimedWorkoutBackground.shared.endAll()
        super.tearDown()
    }

    func testBeginStartsANewActivityAndBecomesTheActiveToken() {
        let token = TimedWorkoutBackground.shared.begin(
            sessionKey: "s1", format: .amrap, dayName: "Test", soundEnabled: false
        )
        XCTAssertEqual(TimedWorkoutBackground.shared.activeToken, token,
                       "begin() must make its own token the active one")
    }

    func testEndWithAStaleTokenIsIgnored() {
        let oldToken = TimedWorkoutBackground.shared.begin(
            sessionKey: "s1", format: .amrap, dayName: "Test", soundEnabled: false
        )
        // "Training fortsetzen": a new player attaches to the same running
        // Zeitformat before the old one's `end()` arrives.
        let newToken = TimedWorkoutBackground.shared.begin(
            sessionKey: "s1", format: .amrap, dayName: "Test", soundEnabled: false
        )
        XCTAssertNotEqual(oldToken, newToken)

        TimedWorkoutBackground.shared.end(token: oldToken)

        XCTAssertEqual(TimedWorkoutBackground.shared.activeToken, newToken,
                       "A stale end(oldToken) must not tear down the newer run")
    }

    func testEndWithTheCurrentTokenTearsDown() {
        let token = TimedWorkoutBackground.shared.begin(
            sessionKey: "s1", format: .amrap, dayName: "Test", soundEnabled: false
        )

        TimedWorkoutBackground.shared.end(token: token)

        XCTAssertNil(TimedWorkoutBackground.shared.activeToken,
                     "end(currentToken) must clear the active run")
    }
}
#endif
