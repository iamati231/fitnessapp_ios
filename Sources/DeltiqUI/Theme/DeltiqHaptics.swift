#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// UX-204 — Zentraler Haptik-Manager.
///
/// Wrapt `UIImpactFeedbackGenerator` + `UINotificationFeedbackGenerator`
/// hinter einem plattform-konditionierten + user-preference-gated API,
/// damit die Call-Sites sich nicht mit `#if canImport(UIKit)` /
/// watchOS-Exclude / AppStorage-Lookup beschäftigen müssen. Drei
/// Surface-Methods:
///
///   * `impact(_:)`    — Press-Feedback (Button-Tap, Set-Check)
///   * `notify(_:)`    — Status-Feedback (Success/Warning/Error,
///                       z.B. Workout-Finish, PR-Detected)
///   * `selection()`   — Wert-Wechsel-Feedback (Picker, Slider-Stop)
///
/// Aufrufmuster: Generator wird pro Call neu allokiert + `prepare()`
/// einmal aufgerufen, dann emittiert. Apple-HIG empfiehlt zwar einen
/// laenger-lebenden Generator fuer perfektes Timing — bei den seltenen
/// User-Aktionen in dieser App (Set-Tap, Workout-Start/Finish) ist der
/// Init-Cost vernachlaessigbar und die simplere API gewinnt.
///
/// Master-Switch: `pref_haptics_enabled` in UserDefaults (Default `true`).
/// Wird in SettingsView nicht (noch nicht) exposed — der User kann's via
/// UserDefaults-Schluessel toggeln. Sobald jemand das nervig findet,
/// adden wir einen Settings-Toggle in einem Folge-Ticket.
public enum DeltiqHaptics {

    public enum Impact {
        case light, medium, heavy, soft, rigid

        #if canImport(UIKit) && !os(watchOS)
        fileprivate var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light:  return .light
            case .medium: return .medium
            case .heavy:  return .heavy
            case .soft:   return .soft
            case .rigid:  return .rigid
            }
        }
        #endif
    }

    public enum Notification {
        case success, warning, error

        #if canImport(UIKit) && !os(watchOS)
        fileprivate var uiType: UINotificationFeedbackGenerator.FeedbackType {
            switch self {
            case .success: return .success
            case .warning: return .warning
            case .error:   return .error
            }
        }
        #endif
    }

    /// Globaler Master-Switch. `UserDefaults.standard.object(forKey:)`
    /// statt `bool(forKey:)`, damit fehlender Eintrag != `false` ist —
    /// neue User starten mit Haptik EIN, ohne dass wir den Default explizit
    /// schreiben muessen.
    public static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "pref_haptics_enabled") as? Bool ?? true
    }

    public static func impact(_ style: Impact) {
        #if canImport(UIKit) && !os(watchOS)
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: style.uiStyle)
        gen.prepare()
        gen.impactOccurred()
        #endif
    }

    public static func notify(_ type: Notification) {
        #if canImport(UIKit) && !os(watchOS)
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type.uiType)
        #endif
    }

    public static func selection() {
        #if canImport(UIKit) && !os(watchOS)
        guard isEnabled else { return }
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
        #endif
    }
}
#endif
