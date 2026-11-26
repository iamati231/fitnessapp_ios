import XCTest

/// Audit-Fund (Modul 20, CircuitWorkoutPlayerView). `init(session:)` restaurierte beim
/// Resume einer Session, deren letzte Runde schon abgeschlossen war (`circuitRoundsCompleted`
/// non-nil), `roundsCompleted`/`restEndDate`/`checkedInRound`, aber NICHT `isFinished` - das
/// blieb beim @State-Default `false`. Ohne Guard konnte `completeCurrentRound()` danach ein
/// zweites Mal durchlaufen (ueber den "Runde beenden"-Button im `.toFailure`-Modus oder durch
/// Ab-/Wiederanhaken der letzten Uebung im `.fixedReps`-Modus) und `finishTimedSession()`
/// doppelt ausloesen (zweiter PersonalRecordEntry, zweite SummaryRoute).
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class CircuitPlayerIsFinishedRestoreTests: XCTestCase {
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

    private func body(of signature: String, in text: String) throws -> String {
        guard let start = text.range(of: signature) else {
            throw XCTSkip("Signature not found: \(signature)")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            throw XCTSkip("End of body not found for: \(signature)")
        }
        return stripLineComments(text[start.upperBound..<end.lowerBound])
    }

    func testInitRestoresIsFinishedWhenResumingAnAlreadyCompletedSession() throws {
        let code = try body(of: "init(session: WorkoutSession) {", in: try source)
        guard let resumeBranchStart = code.range(of: "if let existingRounds = session.circuitRoundsCompleted {") else {
            return XCTFail("resume branch not found in init(session:)")
        }
        let resumeBranch = code[resumeBranchStart.lowerBound...]
        XCTAssertTrue(resumeBranch.contains("_isFinished = State(initialValue:"),
                      "init(session:) must restore _isFinished when resuming, not just roundsCompleted/restEndDate/checkedInRound")
    }

    func testCompleteCurrentRoundGuardsAgainstRunningPastTotalRounds() throws {
        let code = try body(of: "private func completeCurrentRound() {", in: try source)
        guard let incrementRange = code.range(of: "roundsCompleted += 1") else {
            return XCTFail("roundsCompleted += 1 not found in completeCurrentRound()")
        }
        let beforeIncrement = code[code.startIndex..<incrementRange.lowerBound]
        XCTAssertTrue(beforeIncrement.contains("guard roundsCompleted < totalRounds else { return }"),
                      "completeCurrentRound() must bail out before incrementing once roundsCompleted already reached totalRounds")
    }
}
