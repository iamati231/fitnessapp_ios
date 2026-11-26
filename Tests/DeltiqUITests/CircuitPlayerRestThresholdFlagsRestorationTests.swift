import XCTest

/// Audit-Fund (Modul 20): `hasFiredRest60`/`hasFiredRest30` sind Write-Once-Flags
/// pro Pause, die vor diesem Fix nur in `beginRest()` zurueckgesetzt wurden.
/// `init(session:)` restaurierte `restEndDate` fuer eine laufende Pause beim
/// Resume (neue View-Instanz), liess die beiden Flags aber immer bei ihrem
/// `false`-Default - `checkRestElapsed()` konnte so bereits abgehandelte
/// 60s-/30s-Schwellen nach einem View-Neuaufbau erneut ausloesen.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe CircuitEnduranceSaveErrorHandlingTests).
final class CircuitPlayerRestThresholdFlagsRestorationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/CircuitWorkoutPlayerView.swift"),
                encoding: .utf8
            )
        }
    }

    private func stripLineComments(_ text: Substring) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testInitRestoresRestThresholdFlagsConsistentlyWithRestEndDate() throws {
        let text = try source
        guard let start = text.range(of: "init(session: WorkoutSession) {") else {
            return XCTFail("init(session:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of init(session:) not found")
        }
        let code = stripLineComments(text[start.upperBound..<end.lowerBound])

        XCTAssertTrue(code.contains("_hasFiredRest60 = State(initialValue:"),
                      "init must restore hasFiredRest60 from the resumed rest state, not leave it at its false default")
        XCTAssertTrue(code.contains("_hasFiredRest30 = State(initialValue:"),
                      "init must restore hasFiredRest30 from the resumed rest state, not leave it at its false default")
        // Muss an denselben Gates haengen wie checkRestElapsed() (restSeconds > 60/30),
        // sonst koennte ein kurzer Pausen-Typ faelschlich als "schon gefeuert" starten.
        XCTAssertTrue(code.contains("total > 60"))
        XCTAssertTrue(code.contains("total > 30"))
    }

    func testCheckRestElapsedGatesMatchInitRestorationGates() throws {
        let text = try source
        guard let start = text.range(of: "private func checkRestElapsed() {") else {
            return XCTFail("checkRestElapsed() not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of checkRestElapsed() not found")
        }
        let code = stripLineComments(text[start.upperBound..<end.lowerBound])
        XCTAssertTrue(code.contains("restSeconds > 60"))
        XCTAssertTrue(code.contains("restSeconds > 30"))
    }
}
