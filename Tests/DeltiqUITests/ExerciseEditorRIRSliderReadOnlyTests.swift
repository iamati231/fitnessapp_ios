import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor). `isReadOnly`s
/// eigener Doc-Kommentar sagt: Trainings-Parameter (Suggested-Weight, Notiz,
/// Ziel-RIR) bleiben in einem Template-Plan editierbar, nur Struktur-Felder
/// werden gesperrt - der Ziel-RIR-Slider hatte trotzdem `.disabled(isReadOnly)`,
/// anders als die beiden Nachbar-Felder Suggested-Weight/Notiz.
final class ExerciseEditorRIRSliderReadOnlyTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ExerciseEditorView.swift"),
                encoding: .utf8
            )
        }
    }

    func testTargetRIRSliderRowIsNeverDisabledByReadOnly() throws {
        let text = try source
        guard let start = text.range(of: "private var targetRIRSliderRow: some View {") else {
            return XCTFail("targetRIRSliderRow not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of targetRIRSliderRow not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        // Strip "//"-comments before checking: this fix's own explanatory
        // comment quotes ".disabled(isReadOnly)", which would otherwise make
        // the .contains() check below a false positive against prose, not code.
        let code = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")

        XCTAssertFalse(code.contains(".disabled(isReadOnly)"),
                       "the target-RIR slider is a training parameter and must stay editable in a template plan, like Suggested-Weight/Notiz")
    }
}
