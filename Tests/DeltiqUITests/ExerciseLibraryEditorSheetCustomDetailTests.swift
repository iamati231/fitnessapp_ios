#if canImport(SwiftUI) && canImport(SwiftData)
import XCTest

/// DEL-xxx: Eigene Übungen müssen wie Systemübungen dargestellt werden.
/// Quelltext-Prüfungen (Ponytail-Muster aus ExerciseLibraryEditorSheetPersistenceTests):
///   1. `isEditing` State vorhanden und startet für bestehende Templates als false.
///   2. Pencil-Aktion für Custom-Read-Only: setzt `isEditing = true`.
///   3. Nach Save im Edit-Modus: `isEditing = false` statt `dismiss()`.
///   4. `ExerciseGifSheet` hat einen `.background()`-Modifier.
@available(iOS 17.0, macOS 14.0, *)
final class ExerciseLibraryEditorSheetCustomDetailTests: XCTestCase {

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var editorSource: String {
        get throws { try readSource("Sources/DeltiqUI/Settings/ExerciseLibraryEditorSheet.swift") }
    }

    private var gifSheetSource: String {
        get throws { try readSource("Sources/DeltiqUI/Components/ExerciseGifSheet.swift") }
    }

    func testIsEditingStateExistsAndStartsFalseForExistingTemplates() throws {
        let source = try editorSource
        XCTAssertTrue(
            source.contains("@State private var isEditing: Bool"),
            "isEditing must be a @State var so the view re-renders on edit/detail toggle"
        )
        // Create-Modus (template == nil) → true; alles andere (Custom + System) → false.
        XCTAssertTrue(
            source.contains("_isEditing = State(initialValue: template == nil)"),
            "isEditing must start false for existing templates so they open in read-only detail view"
        )
    }

    func testReadOnlyCustomShowsPencilActionThatSetsIsEditing() throws {
        let source = try editorSource
        XCTAssertTrue(
            source.contains("existing?.isCustom == true"),
            "pencil action must be gated on existing?.isCustom == true"
        )
        XCTAssertTrue(
            source.contains(#"systemImage: "pencil""#),
            "read-only custom view must offer a pencil action to enter edit mode"
        )
        XCTAssertTrue(
            source.contains("isEditing = true"),
            "pencil action must set isEditing = true to open the edit form"
        )
    }

    func testSaveInEditModeReturnsToDetailViewInsteadOfDismissing() throws {
        let source = try editorSource
        guard let saveStart = source.range(of: "private func save() {") else {
            return XCTFail("save() not found")
        }
        let saveBody = String(source[saveStart.lowerBound...])
        XCTAssertTrue(
            saveBody.contains("isEditing = false"),
            "save() must set isEditing = false (back to detail view) for the edit path"
        )
        // Create-Pfad muss weiterhin dismiss() aufrufen.
        XCTAssertTrue(
            saveBody.contains("dismiss()"),
            "save() must still call dismiss() for the create path"
        )
    }

    func testGifSheetHasBackgroundModifierToPreventBlackBackground() throws {
        let source = try gifSheetSource
        XCTAssertTrue(
            source.contains("Color.Deltiq.surface.ignoresSafeArea()"),
            "ExerciseGifSheet must use Color.Deltiq.surface (dark-gray) not .background (black) to avoid black background regression"
        )
    }
}
#endif
