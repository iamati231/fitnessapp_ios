import Foundation

/// Settings-Epic Phase 4 (docs/SETTINGS_UX_AUDIT.md, Befund REM-01): die drei
/// Zustaende, die Einstellungen aus dem rohen OS-Berechtigungsstatus
/// (`PRNotificationCenter.isAuthorized: Bool?`) ableiten. Als eigener,
/// plattformneutraler Typ in Core statt als Inline-`switch` direkt in
/// `SettingsAppExperienceView`, damit die Ableitung unabhaengig von SwiftUI
/// getestet werden kann — die View bleibt reine Darstellung dieses Zustands.
public enum NotificationPermissionDisplayState: Equatable, Sendable {
    /// Erlaubt — inkl. `.provisional`/`.ephemeral`, die `PRNotificationCenter`
    /// bereits als `true` normalisiert.
    case granted
    /// Vom Nutzer (oder per Geraete-Einschraenkung) verweigert — UI bietet den
    /// Sprung in die System-Einstellungen an.
    case denied
    /// Noch nie abgefragt bzw. Status noch nicht ermittelt — niemals aus einem
    /// reinen Bildschirm-Aufruf heraus automatisch anfordern.
    case notDetermined

    public init(isAuthorized: Bool?) {
        switch isAuthorized {
        case true?: self = .granted
        case false?: self = .denied
        case nil: self = .notDetermined
        }
    }
}
