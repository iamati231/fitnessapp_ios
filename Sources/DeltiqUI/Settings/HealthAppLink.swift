#if canImport(UIKit)
import UIKit

/// Oeffnet die Health-App — dort liegen die Berechtigungen einer App
/// (Profil → Apps → Deltiq). Die iOS-Einstellungen von Deltiq
/// (`UIApplication.openSettingsURLString`) haben keinen Health-Eintrag; die
/// globale Seite "Datenschutz & Sicherheit → Health" laesst sich nur ueber eine
/// nicht unterstuetzte URL oeffnen.
///
/// Reihenfolge: `x-apple-health://Sources/` (Sharing → Apps, ab iOS 16; wird der
/// Pfad nicht verstanden, oeffnet iOS die Health-App trotzdem), dann
/// `x-apple-health://`, zuletzt die Einstellungen der App (z.B. wenn Health auf
/// dem Geraet fehlt).
@MainActor
enum HealthAppLink {

    static func open() {
        let candidates = [
            "x-apple-health://Sources/",
            "x-apple-health://",
            UIApplication.openSettingsURLString,
        ]
        open(candidates.compactMap { URL(string: $0) }[...])
    }

    private static func open(_ urls: ArraySlice<URL>) {
        guard let url = urls.first else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            guard !success else { return }
            Task { @MainActor in
                open(urls.dropFirst())
            }
        }
    }
}
#endif
