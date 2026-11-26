import XCTest

/// Audit-Fund (Modul 19, SetRow). `initializeOnce()` prüfte `previousLog`
/// (irgendein historischer Log für denselben rohen Set-Index aus EINER
/// FRÜHEREN Session) vor `seedLog` (DEL-157: Log des Satzes direkt darüber in
/// DIESER Session, extra für per "+ Satz" dynamisch hinzugefügte Sätze
/// gedacht). Existierte für denselben rohen Index irgendein alter Log, gewann
/// er immer gegen seedLog - DEL-157s Vererbung vom Satz direkt darüber in der
/// laufenden Session griff dann nie.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class SetRowSeedLogPriorityTests: XCTestCase {
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

    func testSeedLogIsCheckedBeforePreviousLog() throws {
        let text = try source
        guard let start = text.range(of: "private func initializeOnce() {") else {
            return XCTFail("initializeOnce() not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of initializeOnce() not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        guard let seedLogRange = body.range(of: "else if let seedLog {") else {
            return XCTFail("seedLog branch not found in initializeOnce()")
        }
        guard let previousLogRange = body.range(of: "else if let previousLog {") else {
            return XCTFail("previousLog branch not found in initializeOnce()")
        }

        XCTAssertTrue(
            seedLogRange.lowerBound < previousLogRange.lowerBound,
            "seedLog (DEL-157: same-session set directly above) must be checked before previousLog " +
            "(any historical log for this raw index from an earlier session), otherwise a stale " +
            "previousLog hit for the same raw index permanently shadows DEL-157's inheritance"
        )
    }
}
