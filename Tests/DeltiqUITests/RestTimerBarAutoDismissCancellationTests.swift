import XCTest

/// Modul-8-Audit (Workout-Ausfuehrung): der Auto-Dismiss-Block 3s nach
/// Pausenende wurde bisher als reine Closure an `DispatchQueue.main.
/// asyncAfter` gegeben, nie als `DispatchWorkItem` festgehalten und nie
/// irgendwo storniert. Tippt der User innerhalb dieser 3s auf "Skip" und
/// startet danach eine NEUE Pause (z.B. durch das naechste geloggte Set),
/// feuert der veraltete Block trotzdem noch gegen `onDismiss` — derselbe
/// Handler raeumt dann die neue, noch laufende Pause samt Live Activity
/// weg. Quelltext-Pruefung (kein Test-Seam fuer echtes Timing/`scenePhase`
/// in diesem View), gleiches Muster wie die uebrigen Save-Error-/
/// Persistence-Quelltext-Tests dieses Moduls.
final class RestTimerBarAutoDismissCancellationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent() // this file
                    .deletingLastPathComponent() // DeltiqUITests
                    .deletingLastPathComponent() // Tests
                    .appendingPathComponent("Sources/DeltiqUI/Workout/RestTimerBar.swift"),
                encoding: .utf8
            )
        }
    }

    /// The auto-dismiss block must be captured as a cancellable
    /// `DispatchWorkItem`, not a bare closure handed directly to `asyncAfter`.
    func testAutoDismissIsCapturedAsACancellableDispatchWorkItem() throws {
        let text = try source
        XCTAssertTrue(text.contains("let workItem = DispatchWorkItem { onDismiss(.completed) }"),
                     "the 3s auto-dismiss must be wrapped in a DispatchWorkItem so it can be cancelled")
        XCTAssertTrue(text.contains("pendingAutoDismiss = workItem"),
                     "the work item must be stored so .onDisappear can reach it")
        XCTAssertTrue(text.contains("DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)"),
                     "asyncAfter must schedule the stored work item, not a fresh unstorable closure")
    }

    /// `.onDisappear` must cancel the pending work item — otherwise a bar
    /// torn down early (user tapped skip) still lets its stale 3s callback
    /// fire later against whatever bar is active by then.
    func testOnDisappearCancelsThePendingAutoDismiss() throws {
        let text = try source
        guard let onDisappearStart = text.range(of: ".onDisappear {") else {
            return XCTFail(".onDisappear not found")
        }
        guard let onDisappearEnd = text.range(of: "\n        }", range: onDisappearStart.upperBound..<text.endIndex) else {
            return XCTFail(".onDisappear's end not found")
        }
        let body = text[onDisappearStart.upperBound..<onDisappearEnd.lowerBound]
        XCTAssertTrue(body.contains("pendingAutoDismiss?.cancel()"),
                     ".onDisappear must cancel pendingAutoDismiss so a torn-down bar's stale callback never fires")
    }
}
