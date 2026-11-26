import XCTest

/// Audit-Fund (Modul 20, Timed-Player): `saveNow()` in AMRAP-/EMOM-/ForTimePlayerView
/// wertete `prerollRemaining` nicht aus - das Session-Menue (inkl. "Speichern") ist aber
/// bereits waehrend des Vorlauf-Countdowns sichtbar und tappbar, BEVOR `finishPreroll()`
/// `session.startTime` je gesetzt hat. Ein Tap waehrend des Vorlaufs speicherte eine
/// "0 Sekunden/0 Runden/0 Minuten"-Session als abgeschlossen (isCompleted = true).
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe TimedWorkoutPlayerSaveErrorHandlingTests).
final class TimedWorkoutPlayerSaveDuringPrerollTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/TimedWorkoutPlayerView.swift"),
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

    /// Isoliert `saveNow()` innerhalb eines der drei privaten Player-Structs und
    /// prueft, dass der Preroll-Guard VOR der ersten `session.`-Mutation steht.
    private func assertSaveNowGuardsPreroll(structName: String, nextStructName: String?) throws {
        let cleaned = Self.stripLineComments(try source)
        guard let structStart = cleaned.range(of: "private struct \(structName)") else {
            return XCTFail("\(structName) not found")
        }
        let structEnd = nextStructName.flatMap {
            cleaned.range(of: "private struct \($0)", range: structStart.upperBound..<cleaned.endIndex)?.lowerBound
        } ?? cleaned.endIndex
        let slice = cleaned[structStart.upperBound..<structEnd]
        guard let funcStart = slice.range(of: "private func saveNow() {") else {
            return XCTFail("\(structName).saveNow() not found")
        }
        guard let guardRange = slice.range(of: "guard prerollRemaining == 0 else { return }", range: funcStart.upperBound..<slice.endIndex) else {
            return XCTFail("\(structName).saveNow() must guard against prerollRemaining > 0")
        }
        guard let firstMutation = slice.range(of: "session.", range: funcStart.upperBound..<slice.endIndex) else {
            return XCTFail("\(structName).saveNow() has no session mutation to compare against")
        }
        XCTAssertTrue(guardRange.lowerBound < firstMutation.lowerBound,
                      "\(structName).saveNow() must check prerollRemaining BEFORE mutating session fields")
    }

    func testAMRAPSaveNowGuardsPreroll() throws {
        try assertSaveNowGuardsPreroll(structName: "AMRAPPlayerView", nextStructName: "EMOMPlayerView")
    }

    func testEMOMSaveNowGuardsPreroll() throws {
        try assertSaveNowGuardsPreroll(structName: "EMOMPlayerView", nextStructName: "ForTimePlayerView")
    }

    func testForTimeSaveNowGuardsPreroll() throws {
        try assertSaveNowGuardsPreroll(structName: "ForTimePlayerView", nextStructName: nil)
    }
}
