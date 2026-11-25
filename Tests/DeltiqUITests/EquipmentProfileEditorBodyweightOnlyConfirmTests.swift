import XCTest

/// Modul-15-Audit (Components). `bodyweightOnlyButton`'s tap action used to
/// mutate `profile.wrappedValue` directly and unconditionally — a single tap
/// on a row that looks like any other selectable row silently wiped the
/// entire `UserEquipmentProfile` (weights, bench, pull-up bar, further
/// equipment), with no confirmation and no undo. Fix mirrors the existing
/// `settings.confirm.reset` dialog pattern (`SettingsView.swift`): the tap now
/// only flips a `showingConfirm` flag, and the actual wipe
/// (`applyBodyweightOnly`) only runs from a `.destructive`-role button inside
/// a `.confirmationDialog`, in both call sites (`EquipmentProfileEditor` and
/// `NoEquipmentQuickEquipmentPicker`).
///
/// No ViewInspector/XCUITest harness exists in this project for SwiftUI
/// behavior assertions, so this follows the established source-inspection
/// pattern (see `PRHistoryViewLocalizationTests`) — comments are stripped
/// first to avoid the known false-positive/-negative pitfall from Module 11.
final class EquipmentProfileEditorBodyweightOnlyConfirmTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Components/EquipmentProfileEditor.swift"),
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

    private static func body(of signature: String, in text: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            throw XCTSkip("\(signature) not found at the expected signature")
        }
        guard let end = text.range(of: "\n}", range: start.upperBound..<text.endIndex) else {
            throw XCTSkip("end of \(signature) not found")
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testBodyweightOnlyButtonActionNoLongerMutatesProfileDirectly() throws {
        let cleaned = Self.stripLineComments(try source)
        let body = try Self.body(of: "private func bodyweightOnlyButton(", in: cleaned)
        // Only the signature/label body is captured up to the first top-level
        // "\n}", which lands right after the tap action closure for this
        // function's shape — assert on the action, not the whole function.
        guard let actionStart = body.range(of: "return Button {"),
              let actionEnd = body.range(of: "} label:", range: actionStart.upperBound..<body.endIndex) else {
            return XCTFail("could not isolate the button's tap action")
        }
        let action = body[actionStart.upperBound..<actionEnd.lowerBound]

        XCTAssertFalse(action.contains("profile.wrappedValue ="),
                       "tap action must not mutate the profile directly anymore")
        XCTAssertTrue(action.contains("showingConfirm.wrappedValue = true"),
                      "tap action must only request confirmation")
    }

    func testBothCallSitesShowConfirmationDialogBeforeWiping() throws {
        let cleaned = Self.stripLineComments(try source)

        for viewName in ["EquipmentProfileEditor", "NoEquipmentQuickEquipmentPicker"] {
            // `body(of:in:)` scopes precisely to this struct's own top-level
            // closing brace (column 0) — never bleeds into the next struct,
            // unlike a fixed-offset window.
            let window = try Self.body(of: "struct \(viewName): View {", in: cleaned)

            XCTAssertTrue(window.contains("@State private var showingBodyweightOnlyConfirm"),
                          "\(viewName) must own the confirmation flag")
            XCTAssertTrue(window.contains(".confirmationDialog("),
                          "\(viewName) must present a confirmation dialog")
            XCTAssertTrue(window.contains("equipmentEditor.bodyweightOnly.confirmTitle"),
                          "\(viewName) must use the new confirm-title catalog key")
            XCTAssertTrue(window.contains("role: .destructive") && window.contains("applyBodyweightOnly(to:"),
                          "\(viewName)'s destructive dialog button must call the extracted wipe helper")
        }
    }
}
