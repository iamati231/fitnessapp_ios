import XCTest

/// Audit-Fund (Modul 22, Programm-Auswahl/Exercise-Editor). Der "Fertig"-
/// Checkmark in `ExerciseEditorView` rief bisher nur `dismiss()` auf, ohne
/// vorher `modelContext.save()` aufzurufen - `exercise` ist `@Bindable` und
/// mutiert sofort den Live-Objektgraphen, SwiftDatas impliziter Autosave ist
/// aber nicht garantiert vor einem direkt folgenden Kaltstart/App-Kill
/// gelaufen. `DayEditorView.saveAndDismiss()`/`PlanEditorView.saveAndDismiss()`
/// machen das bereits korrekt (save, bei Fehlschlag Toast statt dismiss).
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe `ComebackPromptSheetPercentLocalizationTests`).
final class ExerciseEditorCheckmarkSaveBeforeDismissTests: XCTestCase {
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

    private var catalogSource: String {
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

    func testCheckmarkActionSavesBeforeDismissingAndShowsToastOnFailure() throws {
        let text = try source
        guard let startMarker = text.range(of: "\"common.done\", bundle: .module)") else {
            return XCTFail("checkmark DeltiqHeaderAction not found at the expected marker")
        }
        guard let endMarker = text.range(of: "isModal: true", range: startMarker.upperBound..<text.endIndex) else {
            return XCTFail("end of DeltiqHeader(actions:) not found")
        }
        let body = text[startMarker.upperBound..<endMarker.lowerBound]

        guard let saveRange = body.range(of: "try modelContext.save()") else {
            return XCTFail("checkmark action must call modelContext.save()")
        }
        guard let dismissRange = body.range(of: "dismiss()") else {
            return XCTFail("checkmark action must still call dismiss() on success")
        }
        XCTAssertTrue(saveRange.lowerBound < dismissRange.lowerBound,
                      "save() must happen BEFORE dismiss(), not after - otherwise an unsaved exercise can still be lost on a crash right after dismiss")
        XCTAssertTrue(body.contains("catch"),
                      "a failed save must not silently proceed to dismiss() - needs a catch branch")
        XCTAssertTrue(body.contains("showTransientToast") && body.contains("editor.exercise.save.failed"),
                      "a failed save must surface an error to the user via the established toast convention")
    }

    func testCatalogHasSaveFailedKeyForAllThreeLocales() throws {
        let catalog = try catalogSource
        XCTAssertTrue(catalog.contains("\"editor.exercise.save.failed\""))
        for locale in ["\"de\"", "\"en\"", "\"tr\""] {
            guard let keyRange = catalog.range(of: "\"editor.exercise.save.failed\"") else { continue }
            let windowEnd = catalog.index(keyRange.upperBound, offsetBy: 600, limitedBy: catalog.endIndex) ?? catalog.endIndex
            let window = catalog[keyRange.upperBound..<windowEnd]
            XCTAssertTrue(window.contains(locale), "editor.exercise.save.failed is missing a \(locale) translation")
        }
    }
}
