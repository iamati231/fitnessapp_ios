import XCTest
@testable import FitnessAppCore

/// Settings-Epic Phase 4 (Befund REM-01): die Ableitung von
/// `PRNotificationCenter.isAuthorized: Bool?` auf den dreistufigen
/// UI-Zustand, den `SettingsAppExperienceView.reminderPermissionStatusRow`
/// anzeigt. Das eigentliche Rendering bleibt Apple-seitig zu verifizieren —
/// diese Zuordnung ist der vollstaendige, plattformneutrale Kern dahinter.
final class NotificationPermissionDisplayStateTests: XCTestCase {

    func testGrantedWhenAuthorized() {
        XCTAssertEqual(NotificationPermissionDisplayState(isAuthorized: true), .granted)
    }

    func testDeniedWhenExplicitlyDenied() {
        XCTAssertEqual(NotificationPermissionDisplayState(isAuthorized: false), .denied)
    }

    /// Nie abgefragt bzw. Status (noch) unbekannt — niemals mit "verweigert"
    /// verwechseln, sonst wuerde die UI faelschlich zu den System-Einstellungen
    /// schicken, obwohl ein normaler Berechtigungs-Dialog noch moeglich waere.
    func testNotDeterminedWhenNil() {
        XCTAssertEqual(NotificationPermissionDisplayState(isAuthorized: nil), .notDetermined)
    }
}
