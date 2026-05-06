import Foundation

/// Marker protocol — anything that exposes a Calendar weekday (1=Sun, 2=Mon, ..., 7=Sat).
/// `TrainingDay` (in FitnessAppData) conforms via an empty extension; the protocol
/// keeps `PlanNavigator` decoupled from the SwiftData @Model layer so widgets
/// and watch surfaces can reuse it without dragging FitnessAppData in.
public protocol WeekdayProvider {
    /// Calendar convention: 1 = Sunday, 2 = Monday, ..., 7 = Saturday.
    var weekday: Int { get }
}

/// Pure-function helpers for picking "what's the next training day" inside a
/// program rotation. Sequential rotation only — completed-sessions-count
/// modulo day-count, NOT today's-weekday-based. Works for users who don't
/// always train on the same calendar weekdays.
public enum PlanNavigator {

    /// European display order: Mon=0, Tue=1, ..., Sun=6.
    /// Calendar weekday 1 (Sunday) maps to 6, others to weekday-2.
    public static func europeanWeekdayOrder(_ weekday: Int) -> Int {
        weekday == 1 ? 6 : weekday - 2
    }

    /// Sorts a list of days by weekday with Monday first (European convention).
    /// Stable for ties.
    public static func sortByWeekdayMondayFirst<Day: WeekdayProvider>(_ days: [Day]) -> [Day] {
        days.enumerated()
            .sorted { lhs, rhs in
                let lo = europeanWeekdayOrder(lhs.element.weekday)
                let ro = europeanWeekdayOrder(rhs.element.weekday)
                if lo != ro { return lo < ro }
                return lhs.offset < rhs.offset                  // stable for ties
            }
            .map(\.element)
    }

    /// Sequential rotation pick: the next day's index into a `dayCount`-long
    /// list is `completedSessions % dayCount`. Returns nil for empty inputs.
    /// Negative `completedSessions` clamped to 0.
    public static func nextScheduledIndex(
        dayCount: Int,
        completedSessions: Int
    ) -> Int? {
        guard dayCount > 0 else { return nil }
        return max(0, completedSessions) % dayCount
    }
}
