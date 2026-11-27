import XCTest

/// Audit-Fund (Modul 21, PlanEditorView). Alle vier `swapResultToast`-
/// Aufrufstellen planten unabhaengig per `DispatchQueue.main.asyncAfter`
/// ein unbedingtes `swapResultToast = nil` nach 3s, ohne zu pruefen, ob
/// der Toast zwischenzeitlich durch eine neuere Nachricht ersetzt wurde -
/// ein aelterer Clear-Task konnte eine juengere, noch aktive Meldung
/// vorzeitig loeschen.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class PlanEditorSwapToastRaceTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/PlanEditorView.swift"),
                encoding: .utf8
            )
        }
    }

    private func codeOnly(_ text: Substring) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentStart = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentStart.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testOnlyOneSiteSetsOrClearsSwapResultToast() throws {
        let text = try source
        guard let start = text.range(of: "private func showTransientToast(_ message: String) {") else {
            return XCTFail("showTransientToast(_:) not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of showTransientToast(_:) not found")
        }
        let body = codeOnly(text[start.upperBound..<end.lowerBound])

        XCTAssertTrue(body.contains("swapResultToastGeneration += 1"),
                      "showTransientToast must bump a generation token before showing a new toast")
        XCTAssertTrue(body.contains("guard swapResultToastGeneration == generation else { return }"),
                      "the delayed clear must bail out if a newer toast has replaced this one")

        // Alle vier urspruenglichen Set-Stellen muessen jetzt ausschliesslich
        // ueber diesen einen Helper laufen - keine eigene Set+asyncAfter-
        // Sequenz mehr ausserhalb von showTransientToast selbst.
        let wholeFileCodeOnly = codeOnly(text[text.startIndex..<text.endIndex])
        let assignmentCount = wholeFileCodeOnly.components(separatedBy: "swapResultToast = message").count - 1
        XCTAssertEqual(assignmentCount, 1,
                       "swapResultToast should be assigned in exactly one place (inside showTransientToast), found \(assignmentCount)")
    }
}
