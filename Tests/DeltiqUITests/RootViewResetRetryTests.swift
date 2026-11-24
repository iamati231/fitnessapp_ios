import XCTest

/// Audit-Fund (Modul 11, Settings) — Gegenstueck zu
/// SettingsViewResetSaveErrorHandlingTests: RootView ist die Stelle, die
/// einen gescheiterten Reset-Save tatsaechlich sichtbar machen und einen
/// sicheren Retry anbieten muss, weil SettingsView zu dem Zeitpunkt schon
/// unmounted ist (siehe `resettingPlaceholder`-Doc-Kommentar).
final class RootViewResetRetryTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/RootView.swift"),
                encoding: .utf8
            )
        }
    }

    func testPlaceholderShowsRetryOnFailure() throws {
        let text = try source
        XCTAssertTrue(text.contains("resetSaveFailureMessage.isEmpty"),
                      "resettingPlaceholder must branch on the failure flag instead of always showing the spinner")
        XCTAssertTrue(text.contains("retryFailedReset()"),
                      "the failure branch must offer a way to retry the save")
    }

    func testRetryAttemptsSaveWithoutReDeleting() throws {
        let text = try source
        guard let start = text.range(of: "private func retryFailedReset() {") else {
            return XCTFail("retryFailedReset() not found")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of retryFailedReset() not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        XCTAssertTrue(body.contains("modelContext.save()"),
                      "retry must re-attempt the save — the deletes are already queued from the first attempt")
        XCTAssertFalse(body.contains("UserDataWipe"),
                        "retry must not re-issue the deletes — only the save should be retried")
    }

    func testRelaunchRecoveryAlsoClearsFailureMessage() throws {
        let text = try source
        guard let start = text.range(of: "if isResetting {\n                isResetting = false") else {
            return XCTFail("DEL-134 relaunch-recovery block not found at the expected shape")
        }
        guard let end = text.range(of: "\n            }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of relaunch-recovery block not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        XCTAssertTrue(body.contains("resetSaveFailureMessage = \"\""),
                      "a stuck failure message from a previous run must not survive past a relaunch")
    }
}
