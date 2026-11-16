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
        public let sessionCount: Int
        /// Sum of running distance in km. 0 when no distance data present.
        public let totalDistanceKm: Double
        public let longestRunKm: Double?
        /// Best (lowest) average pace in min/km; nil when no pace data available.
        public let bestPaceMinPerKm: Double?

        public init(sessionCount: Int, totalDistanceKm: Double,
                    longestRunKm: Double?, bestPaceMinPerKm: Double?) {
            self.sessionCount = sessionCount
            self.totalDistanceKm = totalDistanceKm
            self.longestRunKm = longestRunKm
            self.bestPaceMinPerKm = bestPaceMinPerKm
        }
    }

    // MARK: - Public API

    /// Cardio overview for a given period.
    /// - Parameters:
    ///   - activities: All projected activities (all time). Filtered internally.
    ///   - period: The time window to aggregate.
    ///   - now: Reference date for cutoff calculation.
    public static func overviewStats(
        activities: [TrainingActivity],
        period: Period,
        now: Date = .init()
    ) -> OverviewStats {
        let cutoff = period.cutoff(now: now)
        let inPeriod = activities.filter {
            guard let c = cutoff else { return true }
            return $0.date >= c
        }
        let cardio = inPeriod.filter { $0.isRunning || $0.isCrossTrainingOnly || $0.hasAmbiguousCardio }

        let totalDist = cardio.compactMap(\.runningDistanceKm).reduce(0, +)
        let longest   = cardio.compactMap(\.runningDistanceKm).max()

        // Best pace: lowest min/km from sessions that have both distance and duration
        let bestPace: Double? = cardio
            .compactMap { a -> Double? in
                guard let dist = a.runningDistanceKm, let dur = a.runningDurationSeconds,
                      dist > 0, dur > 0 else { return nil }
                return (Double(dur) / 60.0) / dist
            }
            .min()

        return OverviewStats(
            sessionCount: cardio.count,
            totalDistanceKm: totalDist,
            longestRunKm: longest,
            bestPaceMinPerKm: bestPace
        )
    }

    /// Weekly distance/pace buckets for the given period.
    /// Delegates to `CardioVolumeOverTimeAggregator.aggregate`.
    public static func weeklyPoints(
        activities: [TrainingActivity],
        period: Period,
        now: Date = .init(),
        calendar: Calendar = .current
    ) -> [CardioVolumeOverTimePoint] {
        let windowStart = period.cutoff(now: now) ?? calendar.date(
            byAdding: .year, value: -3, to: now) ?? now
        return CardioVolumeOverTimeAggregator.aggregate(
            sessions: activities.map(\.asCardioLoggedSession),
            windowStart: windowStart,
            now: now,
            calendar: calendar
        )
    }
}
