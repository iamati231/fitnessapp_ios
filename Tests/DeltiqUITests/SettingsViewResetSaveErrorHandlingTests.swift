import XCTest

/// Audit-Fund (Modul 11, Settings): `resetApp()`s finaler Delete-Save
/// setzte `isResetting` IMMER zurueck auf false, auch wenn `save()` warf —
/// SettingsView ist zu dem Zeitpunkt aber schon durch
/// `RootView.resettingPlaceholder` ersetzt, die Fehlermeldung ging also
/// spurlos verloren, UND die bereits gequeueten Deletes blieben im
/// geteilten Context haengen, bereit fuer einen spaeteren, unabhaengigen
/// Save. Quelltext-Pruefung, weil `save()` keinen Test-Seam fuer einen
/// echten Fehlschlag hat. Gegenstueck: RootViewResetRetryTests.
final class SettingsViewResetSaveErrorHandlingTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Settings/SettingsView.swift"),
                encoding: .utf8
            )
        }
    }

    func testFinalSaveFailureDoesNotClearTheResetGate() throws {
        let text = try source

        guard let saveRange = text.range(of: "try self.modelContext.save()\n            } catch {") else {
            return XCTFail("expected save()+catch at the known indentation — did resetApp() change shape?")
        }
        guard let catchEndRange = text.range(of: "\n            }", range: saveRange.upperBound..<text.endIndex) else {
            return XCTFail("end of catch block not found")
        }
        let catchBody = text[saveRange.upperBound..<catchEndRange.lowerBound]

        XCTAssertTrue(catchBody.contains("resetSaveFailureMessage = error.localizedDescription"),
                      "a failed delete-save must surface via the AppStorage flag RootView actually observes")
        XCTAssertFalse(catchBody.contains("isResetting"),
                        "must NOT clear isResetting here — SettingsView is already unmounted, and doing so would silently resume normal app use with the already-queued deletes still pending")

        let afterCatch = text[catchEndRange.upperBound...]
        let isResettingFalseCount = afterCatch.components(separatedBy: "self.isResetting = false").count - 1
        XCTAssertEqual(isResettingFalseCount, 1,
                       "the success path must still clear isResetting exactly once, after the reseed step")
    }
}
