import XCTest

/// Audit-Fund (Modul 21, Plan-Builder/Editor): `ExerciseRow`s Superset-Link-
/// Icon trug ein hartcodiertes `.accessibilityLabel("Superset")`, waehrend
/// die Swipe-Action direkt darunter (`day.editor.superset.link`/`.unlink`)
/// bereits korrekt lokalisiert war.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe DayEditorSaveErrorHandlingTests).
final class DayEditorSupersetLinkIconLocalizationTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/DayEditorView.swift"),
                encoding: .utf8
            )
        }
    }

    private var catalog: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings"),
                encoding: .utf8
            )
        }
    }

    // Comments explaining a fix can quote the very string a naive .contains()
    // check searches for (Modul-11/19/20-Pitfall) - strip them first.
    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testExerciseRowSupersetLinkIconIsLocalizedNotHardcoded() throws {
        let text = try source
        guard let start = text.range(of: "private struct ExerciseRow: View {") else {
            return XCTFail("ExerciseRow not found at the expected signature")
        }
        guard let end = text.range(of: "\n}", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of ExerciseRow not found")
        }
        let code = Self.stripLineComments(String(text[start.upperBound..<end.lowerBound]))

        XCTAssertFalse(code.contains(#".accessibilityLabel("Superset")"#),
                        "the superset link icon must no longer use a hardcoded, non-localized accessibility label")
        XCTAssertTrue(code.contains(#".accessibilityLabel(Text("day.editor.superset.linkIcon", bundle: .module))"#),
                      "the superset link icon must use a localized catalog key, matching the sibling link/unlink action's pattern")
    }

    func testCatalogHasSupersetLinkIconKeyForAllThreeLanguages() throws {
        let catalog = try catalog
        XCTAssertTrue(catalog.contains(#""day.editor.superset.linkIcon""#))
        // Crude per-language check: the key's localizations block must contain all three language tags
        // before the next top-level key starts.
        guard let keyRange = catalog.range(of: #""day.editor.superset.linkIcon""#) else {
            return XCTFail("key not found")
        }
        guard let nextKeyRange = catalog.range(of: "\n    \"", range: keyRange.upperBound..<catalog.endIndex) else {
            return XCTFail("could not bound the key's block")
        }
        let block = catalog[keyRange.upperBound..<nextKeyRange.lowerBound]
        XCTAssertTrue(block.contains(#""de""#))
        XCTAssertTrue(block.contains(#""en""#))
        XCTAssertTrue(block.contains(#""tr""#))
    }
}
