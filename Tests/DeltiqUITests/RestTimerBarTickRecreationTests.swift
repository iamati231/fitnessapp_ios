import XCTest

/// Audit-Fund Modul 19: `tick` war ein reiner Stored-`let`, den SwiftUI bei
/// jeder Rekonstruktion von `RestTimerBar` (jedes Re-Render des ohne `.id()`
/// konditional eingebetteten Eltern-Views) neu erzeugte - exakt die in
/// `TimedWorkoutPlayerView.swift` dokumentierte Freeze-Bug-Klasse (`.onReceive`
/// baut seine Combine-Anmeldung neu auf, `.autoconnect()` bindet die
/// Timer-Lebensdauer daran). Kein ViewInspector/XCUITest-Harness vorhanden,
/// daher Source-Inspection gegen die echte Datei.
final class RestTimerBarTickRecreationTests: XCTestCase {

    private var source: String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let testsDir = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = testsDir
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Workout/RestTimerBar.swift")
        return (try? String(contentsOf: sourceURL, encoding: .utf8)) ?? ""
    }

    func testTickIsDeclaredAsStateNotPlainStoredLet() {
        XCTAssertFalse(source.isEmpty, "RestTimerBar.swift sollte lesbar sein")
        XCTAssertTrue(
            source.contains("@State private var tick = Timer.publish"),
            "tick muss als @State deklariert sein, sonst erzeugt jedes Re-Render des Eltern-Views einen neuen Timer"
        )
        XCTAssertFalse(
            source.contains("private let tick = Timer.publish"),
            "tick darf kein reiner Stored-let mehr sein (Audit-Fund Modul 19)"
        )
    }
}
