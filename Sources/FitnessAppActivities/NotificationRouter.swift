import Foundation
import Observation

/// Bridge zwischen dem AppDelegate's `UNUserNotificationCenterDelegate` (lebt
/// AUSSERHALB der SwiftUI-Hierarchie und kann keine View-States direkt aendern)
/// und der RootView, die `AppNavigation` mutiert.
///
/// **Lifecycle**:
///   1. AppDelegate setzt sich beim App-Start als UNUC-Delegate.
///   2. Tap auf Notification → didReceive-response → AppDelegate liest
///      `userInfo["reminder_type"]` und ruft `NotificationRouter.shared.route(_:)`.
///   3. RootView observed `NotificationRouter.shared.pendingRoute` und wendet
///      die Route beim naechsten Body-Re-Render an (Tab-Switch, ggf. Sheet).
///   4. Route wird nach Verarbeitung auf nil gesetzt, damit sie nicht ein
///      zweites Mal feuert.
///
/// **Cold-Start-Compatible**: Wenn die App komplett tot war, persistiert
/// `pendingRoute` durch die @Observable-Mechanik bis RootView's onAppear
/// die Route auswertet — keine verlorenen Taps.
@MainActor
@Observable
public final class NotificationRouter {

    public static let shared = NotificationRouter()

    /// Aktuell ausstehende Route, gesetzt vom AppDelegate beim Notification-Tap.
    /// RootView liest + nullt diesen Wert beim Verarbeiten.
    public var pendingRoute: Route?

    public enum Route: Equatable, Sendable {
        case waterTracker
        case measurement
    }

    private init() {}

    /// Aufgerufen aus dem AppDelegate's UNUC-Delegate. Setzt die pendingRoute,
    /// die RootView beim naechsten Render auswertet.
    public func route(_ route: Route) {
        pendingRoute = route
    }

    /// Konsumiert die aktuelle Route (liefert + nullt). RootView ruft das beim
    /// Verarbeiten, damit die Route nicht zweimal feuert.
    public func consumePendingRoute() -> Route? {
        let route = pendingRoute
        pendingRoute = nil
        return route
    }
}
