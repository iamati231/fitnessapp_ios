#if canImport(UIKit)
import UIKit

/// Settings-Epic Phase 4 (docs/SETTINGS_UX_AUDIT.md, Befund REM-01): oeffnet
/// die iOS-Systemeinstellungsseite dieser App (Einstellungen → Deltiq) — der
/// einzige Ort, an dem eine einmal verweigerte Benachrichtigungs-Berechtigung
/// wieder erlaubt werden kann (der In-App-Dialog erscheint pro Install nur
/// einmal). Anders als `HealthAppLink` gibt es fuer Benachrichtigungen keinen
/// tieferen Deep-Link auf eine Unterseite — die App-Einstellungsseite selbst
/// zeigt die Benachrichtigungs-Zeile bereits ganz oben, ein einzelner Sprung
/// genuegt.
@MainActor
enum AppSettingsLink {
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif
