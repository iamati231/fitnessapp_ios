#if canImport(SwiftData)
import Foundation
import SwiftData
import DeltiqCore

/// SwiftData-Glue zwischen echten `WorkoutSession`/`ExerciseLog`-Objekten
/// und dem reinen `TrainingLoadAggregator` (DeltiqCore).
///
/// Krafttrainings-Kennzahlen via `SessionAggregator.totals` nur auf den
/// Kraft-Anteil (`loggedSets.filter { !$0.resolvedIsCardio }`) —
/// `session.totalVolumeKg`/`totalSets` zaehlen Cardio-Saetze mit (DEL-223).
public enum TrainingActivityExtractor {

    public static func extract(from sessions: [WorkoutSession]) -> [TrainingActivity] {
        sessions.filter(\.isRealWorkout).map { session in
            let cardioLogs = session.logs.filter(\.resolvedIsCardio)
            let runningLogs = cardioLogs.filter { $0.resolvedEnduranceSportKind == .running }
            let cyclingLogs = cardioLogs.filter { $0.resolvedEnduranceSportKind == .cycling }
            let ambiguousLogs = cardioLogs.filter { $0.resolvedEnduranceSportKind == nil }

            let runningDistances = runningLogs.compactMap(\.distanceKm)
            let runningDurations = runningLogs.compactMap(\.durationSeconds)

            let strengthSets = session.loggedSets
                .filter { !$0.resolvedIsCardio }
                .map { SessionAggregator.LoggedSet(weightKg: $0.weight, reps: $0.reps) }
            let strengthTotals = SessionAggregator.totals(for: strengthSets)

            return TrainingActivity(
                date: session.startTime,
                runningDistanceKm: runningDistances.isEmpty ? nil : runningDistances.reduce(0, +),
                runningDurationSeconds: runningDurations.isEmpty ? nil : runningDurations.reduce(0, +),
                isRunning: !runningLogs.isEmpty,
                isCrossTrainingOnly: !cyclingLogs.isEmpty,
                hasAmbiguousCardio: !ambiguousLogs.isEmpty,
                hasStrengthActivity: session.containsStrengthWork,
                strengthSetCount: strengthTotals.setCount,
                strengthVolumeKg: strengthTotals.volumeKg
            )
        }
    }
}
#endif
