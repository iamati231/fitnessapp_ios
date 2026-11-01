import Foundation

/// Status-Verwaltung fuer die optionale App-Einführungstour.
/// Reiner Value-Type ohne SwiftUI-Abhaengigkeit — testbar unabhaengig von der UI.
///
/// Zwei Statuswerte:
/// - `hasHandledInitialAppTour` (AppStorage/UserDefaults): ob die initiale
///   Einladung nach dem Onboarding schon gezeigt oder übersprungen wurde.
/// - Die laufende Tour (transient in `AppNavigation.showingTour`) — kein
///   persistierter Zustand noetig, da Tour beim naechsten Start NIE automatisch
///   fortgesetzt wird (Spec: "kein automatischer Neustart nach App-Schliessung").
public struct AppTourStatus {

    /// UserDefaults-Key fuer die initiale Einladungs-Behandlung.
    /// Wird beim App-Reset geloescht (kein normales App-Update).
    public static let initialInvitationHandledKey = "hasHandledInitialAppTour"

    /// true, wenn die initiale Post-Onboarding-Einladung bereits
    /// gezeigt oder vom Nutzer übersprungen wurde.
    public let hasHandledInitialInvitation: Bool

    public init(hasHandledInitialInvitation: Bool = false) {
        self.hasHandledInitialInvitation = hasHandledInitialInvitation
    }

    /// Laedt den aktuellen Status aus UserDefaults.
    public static func load(from defaults: UserDefaults = .standard) -> AppTourStatus {
        AppTourStatus(
            hasHandledInitialInvitation: defaults.bool(forKey: initialInvitationHandledKey)
        )
    }

    /// Ob die Post-Onboarding-Einladung jetzt angezeigt werden soll.
    /// Setzt voraus, dass das Onboarding abgeschlossen ist (Profil vorhanden).
    public func shouldShowInvitation(hasCompletedOnboarding: Bool) -> Bool {
        hasCompletedOnboarding && !hasHandledInitialInvitation
    }

    /// Markiert die Einladung als behandelt (nach „Tour starten" ODER „Vielleicht später").
    /// Verhindert automatische Wiederholung bei späteren App-Starts.
    public static func markInvitationHandled(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: initialInvitationHandledKey)
    }

    /// Setzt den Status beim vollständigen App-Reset zurück.
    /// NICHT aufrufen bei normalen App-Updates — AppStorage überlebt Updates von Haus aus.
    public static func resetForAppWipe(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: initialInvitationHandledKey)
    }
}
