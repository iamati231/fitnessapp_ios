import XCTest

/// Audit-Fund (Modul 21, Plan-Builder/Editor). `switchPlanEnvAndAdd(conflict:)`
/// baute seinen Erfolgs-Toast aus hartcodierten deutschen String-Literalen
/// statt ueber den lokalisierten Catalog, anders als jede andere Zeichenkette
/// in dieser Datei.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe DayEditorSaveErrorHandlingTests).
final class DayEditorSwitchPlanEnvToastLocalizationTests: XCTestCase {
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

    private static func stripLineComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testSwitchPlanEnvAndAddToastIsLocalizedNotHardcoded() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let start = cleaned.range(of: "private func switchPlanEnvAndAdd(conflict: PendingEquipmentConflict) {") else {
            return XCTFail("switchPlanEnvAndAdd(conflict:) not found at the expected signature")
        }
        guard let end = cleaned.range(of: "\n    }", range: start.upperBound..<cleaned.endIndex) else {
            return XCTFail("end of switchPlanEnvAndAdd(conflict:) not found")
        }
        let body = cleaned[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("\"Plan auf "),
                       "the success toast must no longer hardcode German text for the environment part")
        XCTAssertFalse(body.contains("\" ersetzt\""),
                       "the success toast must no longer hardcode German text for the swapped-count part")
        XCTAssertTrue(body.contains("day.editor.switchPlan.toast.environment"))
        XCTAssertTrue(body.contains("day.editor.switchPlan.toast.swapped"))
    }

    func testCatalogHasBothSwitchPlanToastKeysInAllThreeLanguages() throws {
        let text = try catalog
        for key in ["day.editor.switchPlan.toast.environment", "day.editor.switchPlan.toast.swapped"] {
            guard let keyRange = text.range(of: "\"\(key)\": {") else {
                XCTFail("\(key) missing from catalog")
                continue
            }
            guard let entryEnd = text.range(of: "\n    },", range: keyRange.upperBound..<text.endIndex) else {
                XCTFail("end of \(key) entry not found")
                continue
            }
            let entry = text[keyRange.upperBound..<entryEnd.lowerBound]
            for lang in ["\"de\"", "\"en\"", "\"tr\""] {
                XCTAssertTrue(entry.contains(lang), "\(key) is missing a \(lang) translation")
            }
        }
    }
}
