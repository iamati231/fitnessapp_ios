import XCTest

/// Audit-Fund (Modul 11, Settings): `SettingsDataConnectionsView` zeigt
/// `healthKit.authorizationStatus` prominent an, aktualisierte ihn aber
/// nirgends selbst — einziger Refresh war der einmalige App-Start-Call in
/// `RootView`. Aendert der Nutzer die Health-Berechtigung in den
/// iOS-Einstellungen und kehrt ohne App-Neustart zurueck, zeigte dieser
/// Screen einen veralteten Status. Quelltext-Pruefung, da ein echter
/// HealthKit-Berechtigungswechsel im Unit-Test-Harness nicht simulierbar
/// ist.
final class SettingsDataConnectionsViewHealthStatusRefreshTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Settings/SettingsDataConnectionsView.swift"),
                encoding: .utf8
            )
        }
    }

    func testRefreshesAuthorizationStatusOnAppearAndOnForeground() throws {
        let text = try source

        XCTAssertTrue(text.contains("@Environment(\\.scenePhase) private var scenePhase"),
                      "needs scenePhase to detect returning to the foreground")
        XCTAssertEqual(text.components(separatedBy: "await healthKit.refreshAuthorizationStatus()").count - 1, 2,
                       "must refresh both on first appear (.task) and when returning to .active")
        XCTAssertTrue(text.contains(".onChange(of: scenePhase)"))
    }
}
