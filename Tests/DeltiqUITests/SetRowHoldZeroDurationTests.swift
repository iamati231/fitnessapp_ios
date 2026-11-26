import XCTest

/// Audit-Fund (Modul 19, SetRow). `stopHoldAndLog()` loggte einen Haltesatz
/// (Plank/Wall-Sit) auch mit `elapsed == 0` als abgeschlossen - z.B. bei
/// einem Fehl-Tap direkt nach "GO!", noch vor dem ersten Timer-Tick. Anders
/// als bei Strength (`reps > 0`-Gate) oder Cardio (parsebare Distanz/Dauer)
/// gab es fuer zeitbasierte Haltesaetze keine aequivalente Minimalpruefung.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class SetRowHoldZeroDurationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/SetRow.swift"),
                encoding: .utf8
            )
        }
    }

    func testStopHoldAndLogIgnoresZeroElapsedInsteadOfLoggingIt() throws {
        let text = try source
        guard let start = text.range(of: "private func stopHoldAndLog() {") else {
            return XCTFail("stopHoldAndLog() not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of stopHoldAndLog() not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        guard let guardRange = body.range(of: "guard elapsed > 0 else {") else {
            return XCTFail("stopHoldAndLog must guard against elapsed == 0 before logging")
        }
        guard let onLoggedRange = body.range(of: "onLogged(LoggedSetValues(") else {
            return XCTFail("onLogged(LoggedSetValues(...)) call not found")
        }
        XCTAssertTrue(guardRange.upperBound < onLoggedRange.lowerBound,
                      "the elapsed > 0 guard must run BEFORE onLogged is called, not after")

        let earlyReturnBody = body[guardRange.upperBound..<onLoggedRange.lowerBound]
        XCTAssertFalse(earlyReturnBody.contains("onLogged("),
                      "the early-return branch for elapsed == 0 must not call onLogged")
        XCTAssertTrue(earlyReturnBody.contains("releaseTimedExerciseLockIfHeld()"),
                      "the elapsed == 0 early-return must still release the timed-exercise lock, or the slot stays locked forever")
    }
}
