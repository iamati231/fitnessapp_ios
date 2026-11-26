import XCTest

/// Audit-Fund Modul 19: `repsInput` hatte, anders als `weightInput` (500-kg-
/// Cap), keine Obergrenze gegen implausible Zahlenpad-Vertipper. Kein
/// ViewInspector/XCUITest-Harness vorhanden, daher Source-Inspection statt
/// Rendering-Test (etabliertes Pattern in diesem Repo).
final class SetRowRepsClampTests: XCTestCase {

    private var source: String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile
            .deletingLastPathComponent() // SetRowRepsClampTests.swift -> DeltiqUITests
            .deletingLastPathComponent() // DeltiqUITests -> Tests
            .deletingLastPathComponent() // Tests -> repo root
        let setRowURL = repoRoot
            .appendingPathComponent("Sources/DeltiqUI/Workout/SetRow.swift")
        return (try? String(contentsOf: setRowURL, encoding: .utf8)) ?? ""
    }

    private func body(of signature: String) -> String {
        guard let start = source.range(of: signature) else { return "" }
        guard let end = source.range(of: "\n    }", range: start.upperBound..<source.endIndex) else { return "" }
        return String(source[start.upperBound..<end.lowerBound])
    }

    func testRepsInputClampsBothBounds() {
        let repsBody = body(of: "private var repsInput: some View {")
        XCTAssertFalse(repsBody.isEmpty, "repsInput nicht gefunden - Testaufbau pruefen")
        XCTAssertTrue(repsBody.contains(".onChange(of: reps)"), "repsInput hat keinen .onChange(of: reps)-Clamp")
        XCTAssertTrue(repsBody.contains("maxPlausibleReps"), "repsInput prueft nicht gegen eine Obergrenze")
        XCTAssertTrue(repsBody.contains("newValue < 0"), "repsInput schuetzt nicht gegen negative Werte")
    }

    func testMaxPlausibleRepsIsAGenerousButBoundedCap() {
        guard let range = source.range(of: "maxPlausibleReps = ") else {
            return XCTFail("maxPlausibleReps-Konstante nicht gefunden")
        }
        let tail = source[range.upperBound...].prefix(10)
        let digits = tail.prefix { $0.isNumber }
        guard let value = Int(digits) else {
            return XCTFail("maxPlausibleReps-Wert nicht parsebar")
        }
        XCTAssertGreaterThanOrEqual(value, 100, "Cap zu niedrig fuer legitime hohe Wiederholungszahlen")
        XCTAssertLessThan(value, 10_000, "Cap zu hoch, um Zahlenpad-Vertipper abzufangen")
    }
}
