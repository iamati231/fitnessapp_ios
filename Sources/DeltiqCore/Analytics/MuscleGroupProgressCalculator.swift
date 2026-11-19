import Foundation

/// DEL-Progress-02C: Pure, SwiftData-free muscle-group volume analytics.
/// Mirror of `CardioProgressCalculator` for the Trainingsvolumen-Fortschritt view.
/// The view layer projects WorkoutSession → [MuscleLoggedSet] before calling here.
public enum MuscleGroupProgressCalculator {

    // MARK: - Input type

    /// One already-extracted, SwiftData-free logged working set.
    /// Cardio flag must be pre-resolved (snapshot-first, same as ExerciseLog.resolvedIsCardio).
    public struct MuscleLoggedSet: Sendable {
        public let date: Date
        /// Name of the executed exercise (snapshot-first from ExerciseLog).
        public let exerciseName: String
        /// Primary muscle group — nil when neither snapshot nor live-ref carries the data.
        public let muscleGroup: MuscleGroup?
        public let isCardio: Bool
        /// startTime of the WorkoutSession this set belongs to — used for session counting
        /// (two workouts on the same calendar day remain distinct sessions).
        public let sessionTimestamp: Date

        public init(date: Date, exerciseName: String, muscleGroup: MuscleGroup?, isCardio: Bool, sessionTimestamp: Date) {
            self.date = date
            self.exerciseName = exerciseName
            self.muscleGroup = muscleGroup
            self.isCardio = isCardio
            self.sessionTimestamp = sessionTimestamp
        }
    }

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

    /// Sets per muscle group aggregated over one calendar week.
    public struct WeeklyMusclePoint: Identifiable, Equatable, Sendable {
        public let weekStart: Date
        /// Working-set count per muscle group for this week.
        public let setsByMuscle: [MuscleGroup: Int]
        /// Sets whose exercise had no muscle assigned this week.
        public let unassignedSets: Int

        public var id: Date { weekStart }
        /// Total working sets (assigned + unassigned) this week.
        public var totalSets: Int { setsByMuscle.values.reduce(0, +) + unassignedSets }

        public init(weekStart: Date, setsByMuscle: [MuscleGroup: Int], unassignedSets: Int = 0) {
            self.weekStart = weekStart
            self.setsByMuscle = setsByMuscle
            self.unassignedSets = unassignedSets
        }
    }

    /// High-level stats for the overview card.
    public struct OverviewStats: Equatable, Sendable {
        public let totalWorkingSets: Int
        /// Sets in the period whose exercise had no muscle assigned.
        public let unassignedSetCount: Int
        public let mostTrainedMuscle: MuscleGroup?
        public let mostTrainedMuscleSets: Int
        /// weekStart of the highest-volume week; nil when no sets logged.
        public let busiestWeekStart: Date?
        public let busiestWeekSets: Int
        public let sessionCount: Int

        public init(
            totalWorkingSets: Int,
            unassignedSetCount: Int,
            mostTrainedMuscle: MuscleGroup?,
            mostTrainedMuscleSets: Int,
            busiestWeekStart: Date?,
            busiestWeekSets: Int,
            sessionCount: Int
        ) {
            self.totalWorkingSets = totalWorkingSets
            self.unassignedSetCount = unassignedSetCount
            self.mostTrainedMuscle = mostTrainedMuscle
            self.mostTrainedMuscleSets = mostTrainedMuscleSets
            self.busiestWeekStart = busiestWeekStart
            self.busiestWeekSets = busiestWeekSets
            self.sessionCount = sessionCount
        }
    }

    // MARK: - Public API

    /// Overview stats for a given period.
    /// - Parameters:
    ///   - sets: All projected working sets (all time). Filtered internally.
    ///   - period: The time window to aggregate.
    ///   - now: Reference date; also excludes future-dated sets.
    public static func overviewStats(
        sets: [MuscleLoggedSet],
        period: Period,
        now: Date = .init()
    ) -> OverviewStats {
        let inPeriod = filtered(sets: sets, period: period, now: now)

        var totalByMuscle: [MuscleGroup: Int] = [:]
        var sessionTimestamps: Set<Date> = []
        var unassigned = 0
        for s in inPeriod {
            // All non-cardio sets count for session tracking.
            sessionTimestamps.insert(s.sessionTimestamp)
            guard let m = s.muscleGroup else { unassigned += 1; continue }
            totalByMuscle[m, default: 0] += 1
        }

        let assigned = totalByMuscle.values.reduce(0, +)
        let total = assigned + unassigned
        let top = totalByMuscle.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key.rawValue > $1.key.rawValue) })

        // Busiest week — same total definition as chart bars (assigned + unassigned).
        var weekTotals: [Date: Int] = [:]
        for s in inPeriod {
            let ws = weekStart(for: s.date, calendar: .current)
            weekTotals[ws, default: 0] += 1
        }
        let busiest = weekTotals.max(by: { $0.value < $1.value })

        return OverviewStats(
            totalWorkingSets: total,
            unassignedSetCount: unassigned,
            mostTrainedMuscle: top?.key,
            mostTrainedMuscleSets: top?.value ?? 0,
            busiestWeekStart: busiest?.key,
            busiestWeekSets: busiest?.value ?? 0,
            sessionCount: sessionTimestamps.count
        )
    }

    /// Weekly set-volume per muscle group for the given period.
    /// Returns a gap-free array — every week in the window gets an entry,
    /// even when `totalSets == 0`.
    /// For `.allTime`, window starts at the earliest qualifying set.
    public static func weeklyPoints(
        sets: [MuscleLoggedSet],
        period: Period,
        now: Date = .init(),
        calendar: Calendar = .current
    ) -> [WeeklyMusclePoint] {
        let inPeriod = filtered(sets: sets, period: period, now: now)

        var buckets: [Date: [MuscleGroup: Int]] = [:]
        var unassignedBuckets: [Date: Int] = [:]
        for s in inPeriod {
            let ws = weekStart(for: s.date, calendar: calendar)
            if let m = s.muscleGroup {
                buckets[ws, default: [:]][m, default: 0] += 1
            } else {
                unassignedBuckets[ws, default: 0] += 1
            }
        }

        let windowStart: Date
        if let cutoff = period.cutoff(now: now) {
            windowStart = cutoff
        } else {
            // allTime: anchor at earliest qualifying set so no data is silently dropped.
            windowStart = inPeriod.map(\.date).min() ?? now
        }

        var result: [WeeklyMusclePoint] = []
        var cursor = weekStart(for: windowStart, calendar: calendar)
        let upper = weekStart(for: now, calendar: calendar)
        while cursor <= upper {
            result.append(WeeklyMusclePoint(
                weekStart: cursor,
                setsByMuscle: buckets[cursor] ?? [:],
                unassignedSets: unassignedBuckets[cursor] ?? 0
            ))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Per-muscle totals over the period — sorted descending by set count.
    /// Used for the muscle-group list in `MuscleVolumeProgressView`.
    public static func muscleRanking(
        sets: [MuscleLoggedSet],
        period: Period,
        now: Date = .init()
    ) -> [(muscle: MuscleGroup, totalSets: Int)] {
        let inPeriod = filtered(sets: sets, period: period, now: now)
        var totals: [MuscleGroup: Int] = [:]
        for s in inPeriod {
            guard let m = s.muscleGroup else { continue }
            totals[m, default: 0] += 1
        }
        return MuscleGroup.allCases
            .map { (muscle: $0, totalSets: totals[$0] ?? 0) }
            .sorted { $0.totalSets > $1.totalSets }
    }

    /// Weekly set history for a single muscle group.
    /// Used by `MuscleGroupDetailView`.
    public static func weeklyPointsForMuscle(
        _ muscle: MuscleGroup,
        sets: [MuscleLoggedSet],
        period: Period,
        now: Date = .init(),
        calendar: Calendar = .current
    ) -> [(weekStart: Date, sets: Int)] {
        weeklyPoints(sets: sets, period: period, now: now, calendar: calendar)
            .map { (weekStart: $0.weekStart, sets: $0.setsByMuscle[muscle] ?? 0) }
    }

    // MARK: - Private helpers

    private static func filtered(
        sets: [MuscleLoggedSet],
        period: Period,
        now: Date
    ) -> [MuscleLoggedSet] {
        let cutoff = period.cutoff(now: now)
        return sets.filter { s in
            guard !s.isCardio else { return false }
            if let c = cutoff, s.date < c { return false }
            return s.date <= now
        }
    }

    private static func weekStart(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
}
