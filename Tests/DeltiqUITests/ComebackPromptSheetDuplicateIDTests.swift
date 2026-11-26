import XCTest

/// Audit-Fund (Modul 19, ActiveWorkout-Helpers). `previewSection` identifizierte
/// Zeilen per `ForEach(list.prefix(5), id: \.exerciseName)`. `AbsenceDeload.preview`
/// liefert Changes aber pro Tagesvorkommen einer Uebung
/// (`plans.flatMap(\.days).flatMap(\.activeExercises)`), nicht dedupliziert
/// nach Name - trainiert ein Split dieselbe Uebung an zwei Tagen mit
/// unterschiedlichem Progressionsstand, kollidiert die SwiftUI-Identitaet und
/// eine der beiden Zeilen wird nicht angezeigt.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class ComebackPromptSheetDuplicateIDTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ComebackPromptSheet.swift"),
                encoding: .utf8
            )
        }
    }

    func testPreviewSectionDoesNotIdentifyRowsByExerciseNameAlone() throws {
        let text = try source
        guard let start = text.range(of: "private var previewSection: some View {") else {
            return XCTFail("previewSection not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of previewSection not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        // Modul-11-Pitfall: ein erklaerender Kommentar ueber dem ForEach
        // erwaehnt die alte Identitaet woertlich - Code-Zeilen pruefen, nicht
        // den rohen Text inklusive Kommentare.
        let codeOnly = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentStart = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentStart.lowerBound]
            }
            .joined(separator: "\n")

        XCTAssertFalse(codeOnly.contains("id: \\.exerciseName"),
                        "two Changes for the same exercise on different plan days share an exerciseName - using it as the ForEach identity drops one of them")
        XCTAssertTrue(codeOnly.contains(".enumerated()"),
                      "previewSection must identify rows by something always-unique (e.g. index), not a value that can repeat across Changes")
    }
}
