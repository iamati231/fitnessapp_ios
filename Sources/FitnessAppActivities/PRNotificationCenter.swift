import Foundation
import Observation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Thin facade over `UNUserNotificationCenter` for one-shot PR-celebration
/// notifications. Two responsibilities:
///   1. Request authorization (alerts + sounds) — gracefully at onboarding-finish
///      and lazily on first celebration for upgrade-path users.
///   2. Schedule a near-immediate notification with title + body strings built
///      by `PRCelebration` (Core).
///
/// **No-op outside Apple platforms** — Windows test runs and Linux CI compile
/// against an empty implementation so call sites don't need their own gates.
@MainActor
@Observable
public final class PRNotificationCenter {

    /// `nil` until the first authorization check. After that: `true` granted,
    /// `false` denied (or provisional declined). UI can read this to hide
    /// celebration toggles in Settings if the user opted out at the OS level.
    public private(set) var isAuthorized: Bool? = nil

    public init() {}

    /// Asks the OS for permission. Idempotent — iOS shows the system prompt at
    /// most once per app install; subsequent calls just return the cached
    /// decision. Caller should hide celebration UI when this returns false.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            return granted
        } catch {
            // Authorization can throw if the bundle isn't notification-eligible
            // (e.g. command-line tests). Treat as denied — never crash.
            self.isAuthorized = false
            return false
        }
        #else
        self.isAuthorized = false
        return false
        #endif
    }

    /// Refreshes `isAuthorized` from the current OS settings without prompting.
    /// Cheap; safe to call on view appearance to keep the UI in sync after the
    /// user toggles permission in Settings.app.
    public func refreshAuthorizationStatus() async {
        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            self.isAuthorized = true
        case .denied:
            self.isAuthorized = false
        case .notDetermined:
            self.isAuthorized = nil
        @unknown default:
            self.isAuthorized = false
        }
        #else
        self.isAuthorized = false
        #endif
    }

    /// Schedules a single PR-celebration notification firing ~1s from now. The
    /// short delay is intentional: it lets the workout-summary screen render
    /// first, then the banner drops in for that "ding!" moment.
    ///
    /// **Lazy authorization** — if the user hasn't been asked yet (`.notDetermined`),
    /// we request before scheduling. Already-denied users get a silent no-op
    /// (no spammy second prompt).
    public func scheduleCelebration(title: String, body: String) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()

        // Sync our cache with reality + handle never-prompted users.
        await refreshAuthorizationStatus()
        if isAuthorized == nil {
            _ = await requestAuthorization()
        }
        guard isAuthorized == true else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .active

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pr-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            // Silent failure — a missed banner shouldn't block the post-workout
            // flow. Notification failures usually mean the user revoked perms
            // mid-flight, in which case there's nothing actionable to show.
        }
        #else
        _ = (title, body)
        #endif
    }
}
