// AI-Running-Coach Phase 1 (docs/superpowers/plans/
// 2026-11-06-ai-running-coach-phase1-implementation.md, Abschnitt 3):
// pure-function Wochen-Bucketing der Lauf-/Cardio-Historie - Cardio-Pendant
// zu `VolumeOverTimeAggregator` (dort explizit Cardio-ausschliessend).
// Reine Funktion, keine SwiftData-Abhaengigkeit - die SwiftData-Glue (echte
// `WorkoutSession`/`ExerciseLog` -> `LoggedSession`) lebt in
// `DeltiqData/CardioHistoryExtractor.swift`.

import Foundation

public enum CardioVolumeOverTimeAggregator {

    /// Bereits aus einer `WorkoutSession` extrahierte, klassifizierte
    /// Information - eine pro geloggter Trainingseinheit. Die drei
    /// Cardio-Klassifikations-Flags (`isRunning`/`isCrossTrainingOnly`/
    /// `hasAmbiguousCardio`) sind als EINGABE unabhaengig voneinander (der
    /// Aggregator re-deriviert ihre Prioritaet nicht selbst - das ist
    /// `CardioHistoryExtractor`s Aufgabe, siehe dortige "Running hat
    /// Vorrang"-Regel); dieser Typ vertraut den gelieferten Flags.
    public struct LoggedSession: Sendable {
        public let date: Date
        /// Summe der Lauf-Distanz dieser Session (nur `.running`-Logs).
        /// `nil`, wenn keine Lauf-Distanz bekannt ist (nicht dasselbe wie 0).
        public let runningDistanceKm: Double?
        public let runningDurationSeconds: Int?
        public let isRunning: Bool
        public let isCrossTrainingOnly: Bool
        public let hasAmbiguousCardio: Bool
        public let hasStrengthActivity: Bool

        public init(
            date: Date,
            runningDistanceKm: Double?,
            runningDurationSeconds: Int?,
            isRunning: Bool,
            isCrossTrainingOnly: Bool,
            hasAmbiguousCardio: Bool,
            hasStrengthActivity: Bool
        ) {
            self.date = date
            self.runningDistanceKm = runningDistanceKm
            self.runningDurationSeconds = runningDurationSeconds
            self.isRunning = isRunning
            self.isCrossTrainingOnly = isCrossTrainingOnly
            self.hasAmbiguousCardio = hasAmbiguousCardio
            self.hasStrengthActivity = hasStrengthActivity
        }
    }

    /// Aggregiert die Sessions in Wochen-Buckets innerhalb von
    /// `windowStart...now`. Liefert ein lueckenloses Array - jede Woche im
    /// Fenster bekommt einen Eintrag, auch wenn alles 0/`nil` ist (ehrliche
    /// Luecken-Darstellung, identisches Prinzip wie `VolumeOverTimeAggregator`).
    public static func aggregate(
        sessions: [LoggedSession],
        windowStart: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CardioVolumeOverTimePoint] {
        struct Bucket {
            var runningDistanceKm = 0.0
            var runningSessionCount = 0
            var longestRunKm: Double?
            var paceWeightedDurationSeconds = 0
            var paceWeightedDistanceKm = 0.0
            var crossTrainingSessionCount = 0
            var ambiguousCardioSessionCount = 0
            var strengthSessionCount = 0
        }

        var buckets: [Date: Bucket] = [:]
        for session in sessions {
            guard session.date >= windowStart, session.date <= now else { continue }
            let weekStart = weekStartFor(session.date, calendar: calendar)
            var bucket = buckets[weekStart] ?? Bucket()

            if session.isRunning {
                bucket.runningSessionCount += 1
                if let km = session.runningDistanceKm {
                    bucket.runningDistanceKm += km
                    bucket.longestRunKm = max(bucket.longestRunKm ?? 0, km)
                    if let seconds = session.runningDurationSeconds {
                        bucket.paceWeightedDurationSeconds += seconds
                        bucket.paceWeightedDistanceKm += km
                    }
                }
            }
            if session.isCrossTrainingOnly { bucket.crossTrainingSessionCount += 1 }
            if session.hasAmbiguousCardio { bucket.ambiguousCardioSessionCount += 1 }
            if session.hasStrengthActivity { bucket.strengthSessionCount += 1 }

            buckets[weekStart] = bucket
        }

        var result: [CardioVolumeOverTimePoint] = []
        var cursor = weekStartFor(windowStart, calendar: calendar)
        let upper = weekStartFor(now, calendar: calendar)
        while cursor <= upper {
            let bucket = buckets[cursor] ?? Bucket()
            let pace = bucket.paceWeightedDistanceKm > 0
                ? (Double(bucket.paceWeightedDurationSeconds) / 60.0) / bucket.paceWeightedDistanceKm
                : nil
            result.append(CardioVolumeOverTimePoint(
                weekStart: cursor,
                runningDistanceKm: bucket.runningDistanceKm,
                runningSessionCount: bucket.runningSessionCount,
                longestRunKm: bucket.longestRunKm,
                averagePaceMinutesPerKm: pace,
                averageHeartRateBpm: nil,
                crossTrainingSessionCount: bucket.crossTrainingSessionCount,
                ambiguousCardioSessionCount: bucket.ambiguousCardioSessionCount,
                strengthSessionCount: bucket.strengthSessionCount
            ))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private static func weekStartFor(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
}
