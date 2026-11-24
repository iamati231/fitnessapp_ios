import Foundation

/// Pure, SwiftData-free strength-progress analytics. The view layer projects
/// ExerciseLog + WorkoutSession into StrengthLog value types before calling
/// these functions so Core stays testable from the Windows toolchain.
public enum StrengthProgressCalculator {

    // MARK: - Value types

    public struct StrengthLog: Sendable {
        public let sessionStartTime: Date
        public let exerciseName: String
        public let templateID: UUID?
        public let weightKg: Double
        public let reps: Int
        public let rpe: Double
        public let rir: Float
        public let isCardio: Bool
        public let isTimeBased: Bool
        public let isPlaceholder: Bool
        /// Audit-Fix: ohne dieses Feld zaehlten Warmup-/Cooldown-Saetze in
        /// workSetCount/volumeKg, exerciseSummaries, oneRMHistory und bestSets
        /// mit - dieselbe Luecke, die `WorkoutSession.workingSetLogs` an anderer
        /// Stelle bereits schliesst. Default `true`: bestehende Call-Sites ohne
        /// Rollen-Information (z.B. Tests) behandeln jeden Satz weiter als
        /// Working Set, wie vor diesem Feld.
        public let isWorkingSet: Bool
        /// Stable-within-session identity of the source log entry — e.g. ObjectIdentifier(log) while
        /// in ModelContext. Passed through to SetDetail so its SwiftUI id is constant across re-sorts.
        public let logID: String?

        public init(sessionStartTime: Date, exerciseName: String, templateID: UUID?,
                    weightKg: Double, reps: Int, rpe: Double, rir: Float,
                    isCardio: Bool, isTimeBased: Bool, isPlaceholder: Bool,
                    isWorkingSet: Bool = true, logID: String? = nil) {
            self.sessionStartTime = sessionStartTime
            self.exerciseName = exerciseName
            self.templateID = templateID
            self.weightKg = weightKg
            self.reps = reps
            self.rpe = rpe
            self.rir = rir
            self.isCardio = isCardio
            self.isTimeBased = isTimeBased
            self.isPlaceholder = isPlaceholder
            self.isWorkingSet = isWorkingSet
            self.logID = logID
        }
    }

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
        public let workSetCount: Int
        public let volumeKg: Double
        public let prCount: Int

        public init(sessionCount: Int, workSetCount: Int, volumeKg: Double, prCount: Int) {
            self.sessionCount = sessionCount
            self.workSetCount = workSetCount
            self.volumeKg = volumeKg
            self.prCount = prCount
        }
    }

    public struct ExerciseSummary: Identifiable, Equatable, Sendable {
        public let name: String
        public let templateID: UUID?
        public let best1RMKg: Double?
        public let sessionCount: Int

        public var id: String { templateID?.uuidString ?? name }

        public init(name: String, templateID: UUID?, best1RMKg: Double?, sessionCount: Int) {
            self.name = name
            self.templateID = templateID
            self.best1RMKg = best1RMKg
            self.sessionCount = sessionCount
        }
    }

    public struct OneRMPoint: Identifiable, Equatable, Sendable {
        public let date: Date
        public let estimatedKg: Double
        public let weightKg: Double
        public let reps: Int
        public let rpe: Double
        public let rir: Float

        // Stable ID: one point per session date, so date alone is unique.
        public var id: TimeInterval { date.timeIntervalSince1970 }

        public init(date: Date, estimatedKg: Double,
                    weightKg: Double, reps: Int, rpe: Double, rir: Float) {
            self.date = date
            self.estimatedKg = estimatedKg
            self.weightKg = weightKg
            self.reps = reps
            self.rpe = rpe
            self.rir = rir
        }
    }

    public struct SetDetail: Identifiable, Equatable, Sendable {
        public let sessionDate: Date
        public let weightKg: Double
        public let reps: Int
        public let rpe: Double
        public let rir: Float
        public let isTimeBased: Bool
        /// 1-based position in the bestSets result; used only as tie-breaker when logID is nil.
        public let rank: Int
        /// Opaque identity of the source log entry — e.g. `String(UInt(bitPattern: ObjectIdentifier(log)))`.
        /// Guarantee: stable for the lifetime of the ModelContext (SwiftData keeps the same object
        /// instance while @Query holds it). That is sufficient for SwiftUI ForEach identity: prevents
        /// flicker/state-loss when a heavier set is added and changes the volume-sort rank.
        /// Not persistent across app restarts — not needed for this use case.
        /// If a persistent cross-launch identity is ever required, encode PersistentIdentifier via Codable.
        public let logID: String?

        /// Prefer logID (stable across re-sorts) — fall back to composite only when absent.
        public var id: String { logID ?? "\(sessionDate.timeIntervalSince1970)_\(weightKg)_\(reps)_\(rank)" }

        public init(sessionDate: Date, weightKg: Double,
                    reps: Int, rpe: Double, rir: Float, isTimeBased: Bool, rank: Int,
                    logID: String? = nil) {
            self.sessionDate = sessionDate
            self.weightKg = weightKg
            self.reps = reps
            self.rpe = rpe
            self.rir = rir
            self.isTimeBased = isTimeBased
            self.rank = rank
            self.logID = logID
        }
    }

    // MARK: - Private helpers

    private static func strengthSets(from logs: [StrengthLog]) -> [StrengthLog] {
        logs.filter { !$0.isCardio && !$0.isPlaceholder && $0.isWorkingSet }
    }

    private static func exerciseKey(_ log: StrengthLog) -> String {
        log.templateID?.uuidString ?? log.exerciseName
    }

    // MARK: - Public API

    /// Returns true when `rawKind` maps to a strength or WOD PR kind.
    /// Used by the view to filter `PersonalRecordEntry` rows before passing
    /// `prDates` here — unknown / cardio raw values return `false` (conservative).
    public static func isStrengthPRKind(_ rawKind: String) -> Bool {
        guard let kind = PersonalRecord.Kind(rawValue: rawKind) else { return false }
        switch kind {
        case .heaviestWeight, .bestSet, .estimated1RM,
             .maxReps, .maxHoldSeconds, .mostRounds, .fastestTime:
            return true
        case .longestDistance, .fastestPace:
            return false
        }
    }

    /// Training overview for a given period.
    ///
    /// - Parameters:
    ///   - logs: All projected logs (all time). The function filters by period internally.
    ///   - strengthSessionDates: Dates of sessions that contain at least one strength set.
    ///   - prDates: Dates of non-cardio PRs (filtered by caller).
    ///   - period: The time window to aggregate.
    public static func overviewStats(
        logs: [StrengthLog],
        strengthSessionDates: [Date],
        prDates: [Date],
        period: Period,
        now: Date = .init()
    ) -> OverviewStats {
        let cutoff = period.cutoff(now: now)
        let inPeriod: (Date) -> Bool = {
            guard let cutoff else { return true }
            return $0 >= cutoff
        }

        let sets = strengthSets(from: logs).filter { inPeriod($0.sessionStartTime) }
        let sessions = strengthSessionDates.filter(inPeriod)
        let prs = prDates.filter(inPeriod)

        let volume = sets.reduce(0.0) { sum, log in
            guard log.weightKg > 0, log.reps > 0 else { return sum }
            return sum + log.weightKg * Double(log.reps)
        }

        return OverviewStats(
            sessionCount: sessions.count,
            workSetCount: sets.count,
            volumeKg: volume,
            prCount: prs.count
        )
    }

    /// Unique exercises sorted by session count descending.
    /// Groups by templateID when available, falls back to exerciseName for
    /// deleted/renamed exercises that only carry a snapshot name.
    public static func exerciseSummaries(logs: [StrengthLog]) -> [ExerciseSummary] {
        let sets = strengthSets(from: logs)

        var groups: [String: (name: String, templateID: UUID?, logs: [StrengthLog])] = [:]
        for log in sets {
            let key = exerciseKey(log)
            if var g = groups[key] {
                g.logs.append(log)
                groups[key] = g
            } else {
                groups[key] = (log.exerciseName, log.templateID, [log])
            }
        }

        return groups.values.map { group in
            let sessions = Set(group.logs.map(\.sessionStartTime)).count
            let best1RM: Double? = group.logs
                .filter { !$0.isTimeBased && $0.reps > 0 && $0.weightKg > 0 }
                .compactMap { ExerciseCalculations.estimate1RMAverage(weightKg: $0.weightKg, reps: $0.reps) }
                .max()
            return ExerciseSummary(
                name: group.name,
                templateID: group.templateID,
                best1RMKg: best1RM,
                sessionCount: sessions
            )
        }
        // Gleiche nicht-deterministische Dictionary-Iterationsreihenfolge-Falle wie
        // bei MuscleGroupProgressCalculator (Commit 069fa3a, PR #58) - Tie-Breaker
        // ueber den Namen ergaenzt, sonst flackert die Reihenfolge bei echtem
        // sessionCount-Gleichstand zwischen zwei Uebungen je nach Dictionary-Iteration.
        .sorted { $0.sessionCount != $1.sessionCount ? $0.sessionCount > $1.sessionCount : $0.name < $1.name }
    }

    /// Best estimated 1RM per session for one exercise, chronologically sorted.
    /// Returns one point per session that had a strength set for this exercise.
    public static func oneRMHistory(
        logs: [StrengthLog],
        exerciseName: String,
        templateID: UUID?
    ) -> [OneRMPoint] {
        let targetKey = templateID?.uuidString ?? exerciseName
        let sets = strengthSets(from: logs).filter {
            !$0.isTimeBased
                && exerciseKey($0) == targetKey
                && $0.reps > 0 && $0.weightKg > 0
        }

        var bestPerSession: [Date: (est: Double, log: StrengthLog)] = [:]
        for log in sets {
            guard let est = ExerciseCalculations.estimate1RMAverage(
                weightKg: log.weightKg, reps: log.reps) else { continue }
            if let prev = bestPerSession[log.sessionStartTime], est <= prev.est { continue }
            bestPerSession[log.sessionStartTime] = (est, log)
        }

        return bestPerSession.sorted { $0.key < $1.key }.map { date, pair in
            OneRMPoint(date: date, estimatedKg: pair.est,
                       weightKg: pair.log.weightKg, reps: pair.log.reps,
                       rpe: pair.log.rpe, rir: pair.log.rir)
        }
    }

    /// Top `limit` sets by volume (weight × reps) for one exercise.
    /// Time-based exercises sort by duration (reps = seconds) descending.
    public static func bestSets(
        logs: [StrengthLog],
        exerciseName: String,
        templateID: UUID?,
        limit: Int = 5
    ) -> [SetDetail] {
        let targetKey = templateID?.uuidString ?? exerciseName
        let sets = strengthSets(from: logs).filter { exerciseKey($0) == targetKey }

        return sets
            .sorted {
                let va = $0.isTimeBased ? Double($0.reps) : $0.weightKg * Double($0.reps)
                let vb = $1.isTimeBased ? Double($1.reps) : $1.weightKg * Double($1.reps)
                return va > vb
            }
            .prefix(limit)
            .enumerated()
            .map { (i, log) in
                SetDetail(sessionDate: log.sessionStartTime, weightKg: log.weightKg,
                          reps: log.reps, rpe: log.rpe, rir: log.rir,
                          isTimeBased: log.isTimeBased, rank: i + 1, logID: log.logID)
            }
    }
}
