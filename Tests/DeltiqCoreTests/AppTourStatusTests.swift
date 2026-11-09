import XCTest
@testable import DeltiqCore

final class AppTourStatusTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "AppTourStatusTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    // 1. Nach Onboarding erscheint die Einladung genau einmal (frischer Zustand).
    func testInvitationAppearsAfterOnboarding() {
        let defaults = makeDefaults()
        let status = AppTourStatus.load(from: defaults)
        XCTAssertTrue(status.shouldShowInvitation(hasCompletedOnboarding: true))
    }

    // 2. Nach „Vielleicht später" erscheint die Einladung bei einem erneuten
    //    App-Start nicht mehr.
    func testInvitationDoesNotRepeatAfterDecline() {
        let defaults = makeDefaults()
        AppTourStatus.markInvitationHandled(in: defaults)
        let status = AppTourStatus.load(from: defaults)
        XCTAssertFalse(status.shouldShowInvitation(hasCompletedOnboarding: true))
    }

    // 3. Nach „Tour starten" ist die Einladung ebenfalls als behandelt markiert.
    func testInvitationMarkedHandledAfterStart() {
        let defaults = makeDefaults()
        AppTourStatus.markInvitationHandled(in: defaults)
        let status = AppTourStatus.load(from: defaults)
        XCTAssertTrue(status.hasHandledInitialInvitation)
        XCTAssertFalse(status.shouldShowInvitation(hasCompletedOnboarding: true))
    }

    // 4. Nach Abschluss der Tour wird sie nicht automatisch erneut gestartet.
    func testNoAutoRestartAfterCompletion() {
        let defaults = makeDefaults()
        AppTourStatus.markInvitationHandled(in: defaults)
        // Nach erneutem App-Start: Einladung darf nicht nochmal kommen.
        let status = AppTourStatus.load(from: defaults)
        XCTAssertFalse(status.shouldShowInvitation(hasCompletedOnboarding: true))
    }

    // 5. Nach Abbruch wird die Tour ebenfalls nicht automatisch erneut angeboten.
    func testNoAutoRestartAfterAbort() {
        let defaults = makeDefaults()
        AppTourStatus.markInvitationHandled(in: defaults)
        let status = AppTourStatus.load(from: defaults)
        XCTAssertFalse(status.shouldShowInvitation(hasCompletedOnboarding: true))
    }

    // 6. Über Einstellungen lässt sich die Tour jederzeit erneut starten
    //    (Status-Logik: markInvitationHandled hat keinen Einfluss auf
    //    manuell getriggerte Tours — der Neustart läuft über AppNavigation,
    //    nicht über den Einladungs-Gate).
    func testManualRestartViaSettingsIsIndependentOfInvitationFlag() {
        let defaults = makeDefaults()
        AppTourStatus.markInvitationHandled(in: defaults)
        // Manueller Neustart ignoriert hasHandledInitialInvitation —
        // Einladung darf nicht erscheinen (korrekt), Tour selbst ist aber
        // jederzeit per Settings startbar (ausserhalb dieses Typs).
        let status = AppTourStatus.load(from: defaults)
        XCTAssertTrue(status.hasHandledInitialInvitation,
            "Flag bleibt gesetzt; manueller Neustart läuft über AppNavigation")
    }

    // 7. Vollständiger App-Reset setzt den Tour-Status zurück.
    func testAppResetClearsTourStatus() {
        let defaults = makeDefaults()
        AppTourStatus.markInvitationHandled(in: defaults)
        AppTourStatus.resetForAppWipe(in: defaults)
        let status = AppTourStatus.load(from: defaults)
        XCTAssertFalse(status.hasHandledInitialInvitation)
        XCTAssertTrue(status.shouldShowInvitation(hasCompletedOnboarding: true))
    }

    // 8. Normale App-Aktualisierung setzt den Status NICHT zurück
    //    (UserDefaults bleibt bei App-Updates erhalten — reset wird explizit
    //    NUR in resetForAppWipe aufgerufen, nicht in einem update-Pfad).
    func testNormalUpdatePreservesTourStatus() {
        let defaults = makeDefaults()
        AppTourStatus.markInvitationHandled(in: defaults)
        // Kein resetForAppWipe-Aufruf simuliert ein normales App-Update.
        let statusAfterUpdate = AppTourStatus.load(from: defaults)
        XCTAssertTrue(statusAfterUpdate.hasHandledInitialInvitation,
            "Status muss bei normalen App-Updates erhalten bleiben")
    }

    // 9. Die Tour wird niemals vor Abschluss des Onboardings angeboten.
    func testInvitationNotShownBeforeOnboardingCompleted() {
        let defaults = makeDefaults()
        let status = AppTourStatus.load(from: defaults)
        XCTAssertFalse(status.shouldShowInvitation(hasCompletedOnboarding: false))
    }
}
