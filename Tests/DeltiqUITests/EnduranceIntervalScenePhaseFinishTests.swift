import XCTest

/// Modul-8-Audit (Workout-Ausfuehrung): `EnduranceIntervalPlayerView.
/// checkPhaseElapsed()` wird sowohl vom Sekundentakt (`.onReceive(tick)`,
/// dort hinter einem eigenen `guard !isFinished`) als auch von
/// `.onChange(of: scenePhase)` gerufen - letzterer Call-Site hatte KEINEN
/// `isFinished`-Guard. Ein gewoehnliches Sperrbildschirm-Auf/Zu NACH dem
/// natuerlichen Session-Ende (waehrend die Summary-Route schon gepusht,
/// der Player selbst aber nur ueberdeckt, nicht entfernt ist) liess
/// `checkPhaseElapsed()` den laengst in der Vergangenheit liegenden
/// `phaseEndDate`-Anker erneut als "abgelaufen" lesen und `advancePhase`
/// ein zweites Mal ausloesen - doppelter `PersonalRecordEntry`, doppelte
/// HealthKit-Schreibung (Race), doppelte Summary-Route im Nav-Stack.
/// Quelltext-Pruefung (gleiches Muster wie `CircuitEnduranceSaveErrorHandlingTests`),
/// weil der Player keinen Test-Seam fuer `scenePhase`-Aenderungen hat.
final class EnduranceIntervalScenePhaseFinishTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent() // this file
                    .deletingLastPathComponent() // DeltiqUITests
                    .deletingLastPathComponent() // Tests
                    .appendingPathComponent("Sources/DeltiqUI/Workout/EnduranceIntervalPlayerView.swift"),
                encoding: .utf8
            )
        }
    }

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    /// `checkPhaseElapsed()`'s own guard must short-circuit on `isFinished`
    /// BEFORE reading `remainingPhaseSeconds()` - that way every call site
    /// (today's `tick` and `scenePhase`, and any future one) is safe by
    /// construction, matching `TimedWorkoutPlayerView`'s `checkCapReached()`/
    /// `checkLastMinuteWarning()`/`resyncMinuteState()` convention.
    func testCheckPhaseElapsedGuardsIsFinishedBeforeReadingRemainingSeconds() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let funcStart = cleaned.range(of: "private func checkPhaseElapsed() {") else {
            return XCTFail("checkPhaseElapsed() not found at expected signature")
        }
        guard let guardRange = cleaned.range(of: "guard ", range: funcStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("checkPhaseElapsed() has no guard statement")
        }
        guard let elseRange = cleaned.range(of: "else { return }", range: guardRange.upperBound..<cleaned.endIndex) else {
            return XCTFail("checkPhaseElapsed()'s guard has no else { return }")
        }
        let guardBody = cleaned[guardRange.upperBound..<elseRange.lowerBound]
        XCTAssertTrue(guardBody.hasPrefix("!isFinished"),
                     "checkPhaseElapsed()'s guard must check !isFinished first, so every call site (tick AND scenePhase) is protected")
    }

    /// Locks the regression in directly: the `.onChange(of: scenePhase)`
    /// call site itself no longer needs - and must not rely on - its own
    /// separate guard, since the shared function now protects itself.
    func testScenePhaseHandlerCallsTheNowSelfGuardingFunction() throws {
        let cleaned = Self.stripLineComments(try source)
        XCTAssertTrue(cleaned.contains(".onChange(of: scenePhase)"))
        guard let onChangeStart = cleaned.range(of: ".onChange(of: scenePhase)") else { return }
        guard let callRange = cleaned.range(of: "checkPhaseElapsed()", range: onChangeStart.upperBound..<cleaned.endIndex) else {
            return XCTFail(".onChange(of: scenePhase) must still call checkPhaseElapsed()")
        }
        XCTAssertLessThan(
            cleaned.distance(from: onChangeStart.upperBound, to: callRange.lowerBound), 200,
            "checkPhaseElapsed() should be called close to the scenePhase handler's own guard newPhase == .active"
        )
    }
}
