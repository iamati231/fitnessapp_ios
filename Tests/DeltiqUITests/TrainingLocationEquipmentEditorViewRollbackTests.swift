import XCTest

/// Audit-Fund (Modul 11, Settings): drei der vier Plan-Mutations-Closures
/// in `TrainingLocationEquipmentEditorView` (Equipment-Anpassung, Env-Swap,
/// Env-Restore-Re-Swap) mutierten Plaene/Uebungen und speicherten dann ohne
/// jeden Rollback — schlug der Save fehl, blieben archivierte Uebungen und
/// frische Ersatz-Uebungen im geteilten Context haengen. Quelltext-Pruefung,
/// weil `save()` keinen Test-Seam fuer einen echten Fehlschlag hat.
final class TrainingLocationEquipmentEditorViewRollbackTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Settings/TrainingLocationEquipmentEditorView.swift"),
                encoding: .utf8
            )
        }
    }

    func testRollbackHelperRestoresFieldsAndDeletesFreshInserts() throws {
        let text = try source
        guard let start = text.range(of: "private func saveOrRollbackPlanMutation(_ mutate: () -> Void) -> Bool {") else {
            return XCTFail("saveOrRollbackPlanMutation not found at the expected signature")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of saveOrRollbackPlanMutation not found")
        }
        let body = text[start.upperBound..<end.lowerBound]

        XCTAssertTrue(body.contains("exercise.isArchived = snap.isArchived"))
        XCTAssertTrue(body.contains("exercise.archivedByEnvironmentChange = snap.archivedByEnvironmentChange"))
        XCTAssertTrue(body.contains("exercise.orderIndex = snap.orderIndex"))
        XCTAssertTrue(body.contains("plan.targetEnvironment = oldEnv"))
        XCTAssertTrue(body.contains("modelContext.delete(exercise)"),
                      "must delete exercises freshly inserted by the failed mutate() — they have no snapshot to restore")
        XCTAssertTrue(body.contains("return false"))
        XCTAssertTrue(body.contains("return true"))
    }

    func testEquipmentAdaptationAndEnvSwapClosuresUseTheRollbackHelper() throws {
        let text = try source

        XCTAssertEqual(text.components(separatedBy: "saveOrRollbackPlanMutation {").count - 1, 3,
                       "equipment-adaptation onConfirm, envSwap onConfirm, and envRestore onSecondary must all route through the rollback helper")
    }

    func testEnvRestoreOnConfirmDeliberatelyDoesNotUseTheRollbackHelper() throws {
        let text = try source
        guard let start = text.range(of: "mode: .restore,") else {
            return XCTFail("restore EnvChangePreviewSheet not found")
        }
        guard let onConfirmStart = text.range(of: "onConfirm: {", range: start.upperBound..<text.endIndex) else {
            return XCTFail("restore onConfirm not found")
        }
        guard let onSecondaryStart = text.range(of: "onSecondary: {", range: onConfirmStart.upperBound..<text.endIndex) else {
            return XCTFail("restore onSecondary not found")
        }
        let restoreOnConfirmBody = text[onConfirmStart.upperBound..<onSecondaryStart.lowerBound]

        XCTAssertTrue(restoreOnConfirmBody.contains("applyEnvironmentRestoreToAllPlans"))
        XCTAssertFalse(restoreOnConfirmBody.contains("saveOrRollbackPlanMutation {"),
                        "restoreOriginals() hard-deletes pre-existing exercises — rolling that back needs context.rollback(), which this codebase forbids project-wide; this path intentionally keeps the plain do/catch")
    }
}
