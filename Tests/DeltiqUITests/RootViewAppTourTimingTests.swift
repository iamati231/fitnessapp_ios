import XCTest

/// Audit-Fund (Modul 16, AppTour/Coaching): `MainTabView` markierte die
/// Post-Onboarding-Einladung schon in `.onAppear` als behandelt — bevor der
/// Nutzer das Sheet ueberhaupt gesehen oder beantwortet hat. Bei einem
/// App-Kill/Crash in diesem schmalen Fenster verlor der Nutzer die Einladung
/// permanent, ohne sie je gesehen zu haben — ein Widerspruch zum eigenen
/// (ungenutzten) Vertrag von `AppTourStatus.markInvitationHandled` ("nach
/// Tour starten ODER Vielleicht spaeter"). Fix: der Flag wird jetzt erst im
/// `.sheet`-`onDismiss` gesetzt, das bei JEDER Art von Dismiss feuert
/// (Buttons UND interaktives Wegwischen) — nicht mehr proaktiv beim Anzeigen.
final class RootViewAppTourTimingTests: XCTestCase {
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

    func testOnAppearNoLongerMarksTheInvitationHandled() throws {
        let text = try source
        guard let start = text.range(of: ".onAppear {") else {
            return XCTFail(".onAppear block not found")
        }
        guard let end = text.range(of: "\n        }", range: start.upperBound..<text.endIndex) else {
            return XCTFail("end of .onAppear block not found")
        }
        let body = text[start.upperBound..<end.lowerBound]
        XCTAssertFalse(body.contains("hasHandledInitialAppTour = true"),
                       "merely appearing must not persist the flag — only an actual response to the invitation may")
    }

    func testSheetDismissalMarksTheInvitationHandled() throws {
        let text = try source
        guard let sheetStart = text.range(of: ".sheet(isPresented: Binding(") else {
            return XCTFail(".sheet(isPresented:) call not found")
        }
        guard let contentStart = text.range(of: "AppTourSheet(showInvitation:", range: sheetStart.upperBound..<text.endIndex) else {
            return XCTFail("AppTourSheet(...) call site not found")
        }
        let onDismissWindow = text[sheetStart.upperBound..<contentStart.lowerBound]
        XCTAssertTrue(onDismissWindow.contains("onDismiss:"),
                      "must use .sheet's onDismiss parameter so it fires for an interactive swipe too, not just the explicit buttons")
        XCTAssertTrue(onDismissWindow.contains("hasHandledInitialAppTour = true"),
                      "the flag must be persisted once the sheet is actually dismissed")
    }
}
