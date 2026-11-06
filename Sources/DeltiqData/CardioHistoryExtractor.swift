#if canImport(SwiftData)
import Foundation
import SwiftData
import DeltiqCore

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/
/// 2026-11-06-ai-running-coach-phase1-implementation.md, Abschnitt 3):
/// SwiftData-Glue zwischen echten `WorkoutSession`/`ExerciseLog`-Objekten und
/// dem reinen `CardioVolumeOverTimeAggregator` (DeltiqCore). Einzige Stelle,
/// die `ExerciseLog.resolvedEnduranceSportKind`/`resolvedIsCardio` fuer
/// diesen Zweck liest - liest nur, mutiert nichts.
public enum CardioHistoryExtractor {

    /// Baut die reine Input-Liste fuer `CardioVolumeOverTimeAggregator.aggregate`
    /// aus den tatsaechlichen `WorkoutSession`s eines Profils.
    ///
    /// Klassifikationsregel pro Session (Implementierungs-Ruling, siehe
    /// Abschlussbericht: der urspruengliche Plan-Wortlaut fuer
    /// `isCrossTrainingOnly` - "nur wenn mindestens ein .cycling-Log UND KEIN
    /// .running" - widersprach dem Plan-eigenen Testfall 23 ("Cross-Training-
    /// Kontext bleibt sichtbar" bei einer gemischten Lauf+Rad-Session"). Diese
    /// Implementierung loest das zugunsten der Sichtbarkeit auf: `isRunning`
    /// und `isCrossTrainingOnly` sind UNABHAENGIGE Flags, keine sich
    /// gegenseitig ausschliessenden Zustaende - "Running hat Vorrang" gilt
    /// nur fuer die Umfangs-/Pace-ZAHLEN (die ausschliesslich aus
    /// `.running`-Logs stammen), nicht fuer die Sichtbarkeit von
    /// Cross-Training in `crossTrainingSessionCount`.
    public static func loggedSessions(
        from sessions: [WorkoutSession]
    ) -> [CardioVolumeOverTimeAggregator.LoggedSession] {
        sessions
            .filter(\.isRealWorkout)
            .map { session in
                let cardioLogs = session.logs.filter(\.resolvedIsCardio)
                let runningLogs = cardioLogs.filter { $0.resolvedEnduranceSportKind == .running }
                let cyclingLogs = cardioLogs.filter { $0.resolvedEnduranceSportKind == .cycling }
                // Mehrdeutig: Cardio, aber weder .running noch .cycling
                // zugeordnet (enduranceSportKind == nil) - echte
                // Unbekanntheit, nie als Laufen angenommen.
                let ambiguousLogs = cardioLogs.filter { $0.resolvedEnduranceSportKind == nil }
                let hasStrengthActivity = session.logs.contains { !$0.resolvedIsCardio }

                let runningDistances = runningLogs.compactMap(\.distanceKm)
                let runningDurations = runningLogs.compactMap(\.durationSeconds)

                return CardioVolumeOverTimeAggregator.LoggedSession(
                    date: session.startTime,
                    runningDistanceKm: runningDistances.isEmpty ? nil : runningDistances.reduce(0, +),
                    runningDurationSeconds: runningDurations.isEmpty ? nil : runningDurations.reduce(0, +),
                    isRunning: !runningLogs.isEmpty,
                    isCrossTrainingOnly: !cyclingLogs.isEmpty,
                    hasAmbiguousCardio: !ambiguousLogs.isEmpty,
                    hasStrengthActivity: hasStrengthActivity
                )
            }
    }
}
#endif
