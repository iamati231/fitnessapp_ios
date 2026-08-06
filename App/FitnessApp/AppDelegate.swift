import Foundation
import UIKit
import UserNotifications
import FitnessAppActivities

/// Cold-Start-safe `UNUserNotificationCenterDelegate`. Setzt sich beim
/// `didFinishLaunching` und routet Notification-Taps via `NotificationRouter`
/// in die RootView.
///
/// **Warum AppDelegate statt SwiftUI-onAppear** (DEL-028-Gotcha #1):
/// Wenn die App komplett geschlossen war (Cold-Start) und der User auf eine
/// Notification tippt, feuert iOS den Delegate-Callback noch BEVOR die
/// SwiftUI-Hierarchie aufgebaut ist. Ein Delegate-Setup in `.onAppear` der
/// RootView wuerde diesen ersten Tap verpassen. Im AppDelegate's
/// `didFinishLaunching` ist die Verkabelung garantiert vor dem ersten
/// Tap-Event live.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Foreground-Notification: zeigt Banner + Sound an, statt sie zu
    /// verschlucken (Default-iOS-Verhalten waere "silent in foreground").
    ///
    /// DEL-204-Ausnahme: die Rest-Timer-Notification ist NUR fürs
    /// Background-Feedback gedacht — im Vordergrund übernimmt die
    /// RestTimerBar Sound + Haptik. Ohne die Suppression gäbe es beim
    /// Timer-Ende in der App Doppel-Feedback (Banner + In-App-Sound).
    ///
    /// README 2.9 Phase 4: gleiche Ausnahme fuer die EMOM-Minutentrigger —
    /// im Vordergrund uebernimmt TimerSoundPlayer.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let identifier = notification.request.identifier
        if ReminderScheduler.isRestTimerNotification(identifier: identifier)
            || ReminderScheduler.isEMOMNotification(identifier: identifier) {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .list])
    }

    /// Tap-Handler. Liest `userInfo["reminder_type"]` und routet via
    /// `NotificationRouter.shared`, der den State an die RootView weitergibt.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo
        guard let type = userInfo[ReminderScheduler.reminderTypeKey] as? String else {
            return
        }

        let route: NotificationRouter.Route?
        switch type {
        case ReminderScheduler.waterPayload:       route = .waterTracker
        case ReminderScheduler.measurementPayload: route = .measurement
        default:                                    route = nil
        }

        guard let route else { return }
        // NotificationRouter ist @MainActor — Hop ueber Task aus dem
        // non-isolated Delegate-Context.
        Task { @MainActor in
            NotificationRouter.shared.route(route)
        }
    }
}
