import XCTest
#if canImport(SwiftUI)

/// Task 7 (docs/superpowers/sdd/2026-10-23-nutrition-ai-bugfixes): `AddMealView`
/// used a blocking `.alert()` for a failed save/delete — the ONLY Form-based
/// editor in the app doing so. Every comparable screen (and `AddMealView`'s
/// OWN `aiErrorMessage`/`onlineSearch.errorMessage` rows further up in the
/// same file) instead shows an inline `Text` row inside the `Form`, styled
/// `.font(.caption)` + `Color.Deltiq.textSecondary`. `CustomFoodEntrySheet` —
/// in the same file family, also a native Form+NavigationStack sheet
/// presented directly from `AddMealView` — is the closest sibling and uses
/// exactly that inline-row pattern already.
///
/// Neither `AddMealView.body` nor `CustomFoodEntrySheet.body` has a testable
/// runtime surface (both only produce opaque `some View`), so this reads the
/// source files directly — same pattern as `MainTabStructureTests`/
/// `DeltiqLabelScalesDownInsteadOfWrappingTests`.
@available(iOS 17.0, macOS 14.0, *)
final class AddMealViewSaveErrorStyleTests: XCTestCase {

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // FitnessAppUITests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var addMealViewSource: String {
        get throws { try readSource("Sources/FitnessAppUI/Nutrition/AddMealView.swift") }
    }

    private var customFoodEntrySheetSource: String {
        get throws { try readSource("Sources/FitnessAppUI/Nutrition/CustomFoodEntrySheet.swift") }
    }

    func testAddMealViewNoLongerUsesABlockingAlertForSaveFailure() throws {
        let source = try addMealViewSource
        XCTAssertFalse(
            source.contains(".alert("),
            "AddMealView must not use a blocking .alert() for save/delete failure — the Deltiq standard for a Form editor is an inline error row."
        )
    }

    func testAddMealViewUsesAnInlineSaveErrorMessageState() throws {
        let source = try addMealViewSource
        XCTAssertTrue(
            source.contains("@State private var saveErrorMessage: String?"),
            "AddMealView should hold its save-error text the same way as its sibling CustomFoodEntrySheet.saveErrorMessage."
        )
        XCTAssertTrue(
            source.contains("if let saveErrorMessage {"),
            "The error text must be rendered conditionally as a Form row, not via a presented alert."
        )
    }

    /// The exact visual style (font + color) must match what `AddMealView`
    /// already uses for its own `aiErrorMessage`/`onlineSearch.errorMessage`
    /// rows, and what `CustomFoodEntrySheet` uses for its own save error —
    /// one consistent "inline error text" look across this screen family.
    func testSaveErrorRowStyleMatchesEstablishedInlineErrorStyleInThisFile() throws {
        let source = try addMealViewSource
        // Built with explicit "\n" (not a triple-quote literal) so the
        // expected indentation isn't silently reshaped by Swift's multiline
        // string dedenting -- this must match AddMealView.swift byte-for-byte.
        let errorRowBlock = "Text(saveErrorMessage)\n"
            + "                            .font(.caption)\n"
            + "                            .foregroundStyle(Color.Deltiq.textSecondary)"
        XCTAssertTrue(
            source.contains(errorRowBlock),
            "saveErrorMessage row must use the same .font(.caption) + Color.Deltiq.textSecondary style as AddMealView's own aiErrorMessage/onlineSearch.errorMessage rows."
        )
    }

    func testCustomFoodEntrySheetSiblingUsesTheSameInlineErrorStyle() throws {
        let source = try customFoodEntrySheetSource
        XCTAssertTrue(
            source.contains(".font(.caption)") && source.contains(".foregroundStyle(Color.Deltiq.textSecondary)"),
            "CustomFoodEntrySheet is the comparison sibling for this style — it must still use the same inline error text styling."
        )
        XCTAssertFalse(
            source.contains(".alert("),
            "CustomFoodEntrySheet (the established-correct sibling) must not use a blocking alert either."
        )
    }
}
#endif
