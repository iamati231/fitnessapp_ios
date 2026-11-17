import Foundation

/// Pure, SwiftData-free cardio/endurance progress analytics.
/// Mirror of `StrengthProgressCalculator` for the Ausdauer-Fortschritt view.
/// The view layer projects WorkoutSession → TrainingActivity before calling here.
public enum CardioProgressCalculator {

    // MARK: - Value types

    public enum Period: String, CaseIterable, Identifiable, Hashable, Sendable {
        case fourWeeks, twelveWeeks, oneYear, allTime
        public var id: String { rawValue }

        public func cutoff(now: Date = .init(), calendar: Calendar = .current) -> Date? {
            switch self {
            case .fourWeeks:   return calendar.date(byAdding: .weekOfYear, value: -4, to: now)
            case .twelveWeeks: return calendar.date(byAdding: .weekOfYear, value: -12, to: now)
            case .oneYear:     return calendar.date(byAdding: .year, value: -1, to: now)
            case .allTime:     return nil
            }
        }
    }

    public struct OverviewStats: Equatable, Sendable {
        /// Only running sessions (isRunning == true). Cross-training and ambiguous
        /// cardio are excluded because distance/pace metrics are running-only.
        public let sessionCount: Int
        /// Sum of running distance in km. 0 when no distance data present.
        public let totalDistanceKm: Double
        public let longestRunKm: Double?
        /// Best (lowest) average pace in min/km; nil when no pace data available.
        public let bestPaceMinPerKm: Double?
        /// Sessions that had cardio activity but were NOT classified as running.
        /// Includes isCrossTrainingOnly and hasAmbiguousCardio sessions.
        public let otherCardioSessionCount: Int

        public init(
            sessionCount: Int,
            totalDistanceKm: Double,
            longestRunKm: Double?,
            bestPaceMinPerKm: Double?,
            otherCardioSessionCount: Int = 0
        ) {
            self.sessionCount = sessionCount
            self.totalDistanceKm = totalDistanceKm
            self.longestRunKm = longestRunKm
            self.bestPaceMinPerKm = bestPaceMinPerKm
            self.otherCardioSessionCount = otherCardioSessionCount
        }
    }

    // MARK: - Public API

    /// Cardio overview for a given period.
    /// - Parameters:
    ///   - activities: All projected activities (all time). Filtered internally.
    ///   - period: The time window to aggregate.
    ///   - now: Reference date for cutoff calculation and future-date exclusion.
    public static func overviewStats(
        activities: [TrainingActivity],
        period: Period,
        now: Date = .init()
    ) -> OverviewStats {
        let cutoff = period.cutoff(now: now)
        // Both ends consistent: include [cutoff, now], exclude future-dated sessions.
        let inPeriod = activities.filter {
            if let c = cutoff, $0.date < c { return false }
            return $0.date <= now
        }
        let running = inPeriod.filter { $0.isRunning }
        let otherCardio = inPeriod.filter { !$0.isRunning && ($0.isCrossTrainingOnly || $0.hasAmbiguousCardio) }

        let totalDist = running.compactMap(\.runningDistanceKm).reduce(0, +)
        let longest   = running.compactMap(\.runningDistanceKm).filter { $0 > 0 }.max()

        // Best pace: lowest min/km from sessions that have both distance and duration.
        let bestPace: Double? = running
            .compactMap { a -> Double? in
                guard let dist = a.runningDistanceKm, let dur = a.runningDurationSeconds,
                      dist > 0, dur > 0 else { return nil }
                return (Double(dur) / 60.0) / dist
            }
            .min()

        return OverviewStats(
            sessionCount: running.count,
            totalDistanceKm: totalDist,
            longestRunKm: longest,
            bestPaceMinPerKm: bestPace,
            otherCardioSessionCount: otherCardio.count
        )
    }

    /// Weekly distance/pace buckets for the given period.
    /// For `.allTime`, window starts at the earliest running activity — no silent 3-year cap.
    public static func weeklyPoints(
        activities: [TrainingActivity],
        period: Period,
        now: Date = .init(),
        calendar: Calendar = .current
    ) -> [CardioVolumeOverTimePoint] {
        let windowStart: Date
        if let cutoff = period.cutoff(now: now) {
            windowStart = cutoff
        } else {
            // allTime: anchor to earliest running activity so no data is silently dropped.
            windowStart = activities
                .filter { $0.isRunning }
                .map(\.date)
                .min() ?? now
        }
        return CardioVolumeOverTimeAggregator.aggregate(
            sessions: activities.map(\.asCardioLoggedSession),
            windowStart: windowStart,
            now: now,
            calendar: calendar
        )
    }
}
