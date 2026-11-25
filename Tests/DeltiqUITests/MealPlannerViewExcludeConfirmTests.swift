import XCTest

/// Audit-Fund (Modul 17, MealPlanner-UI). Der Kontextmenue-Eintrag
/// "Ausschliessen" loeste bei einem einzigen Tap zwei dauerhafte Effekte aus
/// (globale Ausschluss-Praeferenz UND Entfernen der heutigen Zuweisung) - ohne
/// `role: .destructive` und ohne Bestaetigungsdialog, direkt neben dem
/// "Austauschen"-Button im selben Menue (Mistap-Risiko). An anderer Stelle der
/// App existiert fuer vergleichbare destruktive Aktionen durchgaengig ein
/// Bestaetigungsmuster (z.B. `BackupListView.pendingDelete` +
/// `.confirmationDialog`).
///
/// Fix: der Tap setzt jetzt nur noch `pendingExcludeAssignment`; die
/// eigentliche Aktion laeuft erst ueber einen `.destructive`-Dialog-Button.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe EquipmentProfileEditorBodyweightOnlyConfirmTests).
final class MealPlannerViewExcludeConfirmTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Nutrition/MealPlannerView.swift"),
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

    func testExcludeButtonOnlyRequestsConfirmation() throws {
        let cleaned = Self.stripLineComments(try source)
        guard let labelRange = cleaned.range(of: "mealPlanner.action.exclude\", bundle: .module), systemImage: \"nosign\")") else {
            return XCTFail("exclude button label not found")
        }
        guard let buttonStart = cleaned.range(of: "Button {", options: .backwards, range: cleaned.startIndex..<labelRange.lowerBound) else {
            return XCTFail("exclude button start not found")
        }
        let action = cleaned[buttonStart.upperBound..<labelRange.lowerBound]

        XCTAssertTrue(action.contains("pendingExcludeAssignment = assignment"),
                      "tap must only request confirmation, not mutate directly")
        XCTAssertFalse(action.contains("mealPlanExcludedRecipeIDsRaw.append"),
                       "tap action must not mutate the exclusion list directly anymore")
        XCTAssertFalse(action.contains("removeAssignment(assignment)"),
                       "tap action must not remove the assignment directly anymore")
    }

    func testConfirmationDialogExistsWithDestructiveRole() throws {
        let cleaned = Self.stripLineComments(try source)
        XCTAssertTrue(cleaned.contains("@State private var pendingExcludeAssignment: PlannedMealAssignment? = nil"),
                      "must own a pending-confirmation state")
        XCTAssertTrue(cleaned.contains("mealPlanner.action.exclude.confirmTitle"),
                      "must use a dedicated confirm-title catalog key")
        guard let dialogStart = cleaned.range(of: "mealPlanner.action.exclude.confirmTitle") else {
            return XCTFail("confirmation dialog not found")
        }
        guard let dialogEnd = cleaned.range(of: "mealPlanner.action.exclude.confirmMessage", range: dialogStart.upperBound..<cleaned.endIndex) else {
            return XCTFail("confirmation dialog message not found")
        }
        let dialog = cleaned[dialogStart.lowerBound..<dialogEnd.upperBound]
        XCTAssertTrue(dialog.contains("role: .destructive"),
                      "the actual exclude action must run behind a destructive dialog button")
        XCTAssertTrue(dialog.contains("mealPlanExcludedRecipeIDsRaw.append") && dialog.contains("removeAssignment"),
                      "the destructive button must perform both effects the old direct tap did")
    }
}
