import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl). `baselineConflictBanner` hatte
/// zwei Bugs: (a) die zwei Label-Texte waren hartcodiertes Deutsch statt
/// lokalisiert, (b) jeder Konflikt-Eintrag bekam blind das Suffix " entfernt"
/// angehaengt - fuer einen kritischen Konflikt (leerer Trainingstag) ist
/// `exerciseName` aber bereits ein vollstaendiger Hinweissatz, kein
/// Uebungsname, wodurch ein unsinniger Doppelsatz entstand.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe ComebackPromptSheetPercentLocalizationTests).
final class ProgramTemplatePickerBaselineConflictBannerTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ProgramTemplatePickerView.swift"),
                encoding: .utf8
            )
        }
    }

    private func bannerBody() throws -> Substring {
        let text = try source
        guard let start = text.range(of: "private var baselineConflictBanner: some View {") else {
            XCTFail("baselineConflictBanner not found at the expected signature")
            return text[text.startIndex..<text.startIndex]
        }
        guard let end = text.range(of: "\n    }\n", range: start.upperBound..<text.endIndex) else {
            XCTFail("end of baselineConflictBanner not found")
            return text[text.startIndex..<text.startIndex]
        }
        return text[start.upperBound..<end.lowerBound]
    }

    /// Strip "//"-comment text before any `.contains()` check: this fix's own
    /// explanatory comment quotes both the old hardcoded strings and the old
    /// suffix literal, which would otherwise make the checks below false
    /// positives against prose, not code.
    private func codeOnly(_ body: Substring) -> String {
        body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let commentRange = line.range(of: "//") else { return line }
                return line[line.startIndex..<commentRange.lowerBound]
            }
            .joined(separator: "\n")
    }

    func testLabelTitlesAreLocalizedNotHardcoded() throws {
        let code = codeOnly(try bannerBody())
        XCTAssertFalse(code.contains("\"Plan kann nicht übernommen werden"),
                       "the critical banner title must no longer be a hardcoded German literal")
        XCTAssertFalse(code.contains("\"Einige Übungen wurden für dein Fitnesslevel angepasst\""),
                       "the warning banner title must no longer be a hardcoded German literal")
        XCTAssertTrue(code.contains("picker.plan.baselineConflict.titleCritical"))
        XCTAssertTrue(code.contains("picker.plan.baselineConflict.titleWarning"))
    }

    func testCriticalConflictDoesNotAppendRemovedSuffix() throws {
        let code = codeOnly(try bannerBody())
        XCTAssertTrue(code.contains("conflict.isCritical"),
                      "the per-conflict Text must branch on isCritical before appending \" entfernt\"")
        let collapsed = code.replacingOccurrences(of: " ", with: "")
        XCTAssertFalse(collapsed.contains("Text(\"•\\(conflict.dayName):\\(conflict.exerciseName)entfernt\")"),
                       "a conflict's \" entfernt\" suffix must no longer be unconditional")
    }

    func testCatalogHasBothTitleKeysInAllThreeLocales() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        for key in ["picker.plan.baselineConflict.titleCritical", "picker.plan.baselineConflict.titleWarning"] {
            XCTAssertTrue(catalog.contains("\"\(key)\""), "missing catalog entry for \(key)")
        }
    }
}
