import Foundation

/// Custom URL scheme shared between the main app and the widget extension.
///
/// **Registration**: the URL scheme `fitnessapp` must be declared in the main app
/// target's `Info.plist` under `CFBundleURLTypes` for `widgetURL`-taps to actually
/// open the app. See `WidgetSetup.md` for the exact plist entry.
///
/// Why a single source of truth: a typo on either side (widget writes
/// `fitnessapp://workout/active`, app handler checks `fitness-app://...`) would
/// silently break the deep link with no compile-time warning. Routing through this
/// enum makes both sides reference the same constant.
public enum FitnessAppDeepLink {

    /// The custom scheme. Reused for matching incoming URLs in `App.onOpenURL { ... }`.
    public static let scheme = "fitnessapp"

    /// `fitnessapp://workout/active` — tapping the rest-timer Live Activity should
    /// land the user on the in-progress `ActiveWorkoutView`.
    public static var activeWorkout: URL {
        URL(string: "\(scheme)://workout/active")!
    }

    /// `fitnessapp://dashboard` — reserved for future use (e.g. Home-Screen widget tap).
    public static var dashboard: URL {
        URL(string: "\(scheme)://dashboard")!
    }
}
