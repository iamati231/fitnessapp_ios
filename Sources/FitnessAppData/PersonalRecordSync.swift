#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Bridges the value-type `PRDetector` (Core) to the persistent
/// `PersonalRecordEntry` table. Two flavors:
///
///   - **`recordPRs(for:in:)`** — incremental, called from
///     `ActiveWorkoutView.finishWorkout()`. Detects PRs for a single just-
///     completed session against all earlier completed sessions and inserts
///     `PersonalRecordEntry` rows.
///
///   - **`rebuild(in:)`** — destructive, manual one-shot. Wipes all existing
///     `PersonalRecordEntry` rows and walks every completed session in
///     chronological order, re-running detection. Powers the "Aus History
///     neu berechnen" toolbar button in `PRHistoryView` and the implicit
///     first-time backfill (Trophy Room is empty + history isn't).
///
/// Both helpers DO NOT call `save()` — the caller's modelContext save policy
/// (autosave or explicit) decides when changes hit disk.
public enum PersonalRecordSync {

    // MARK: - Incremental (forward-save from finishWorkout)

    /// Detects PRs for `session` against all OTHER completed sessions in the
    /// store and inserts a `PersonalRecordEntry` per detected record. No-op if
    /// the session isn't yet marked completed (defensive — caller controls
    /// ordering, but a misuse here would silently produce nothing).
    ///
    /// History is fetched via `FetchDescriptor` so this works without a
    /// `@Query` host view (we're called from `finishWorkout`, not a body).
    ///
    /// Returns the detected PRs as value-types so callers can drive UI
    /// celebrations (notifications, live-activity headlines) without re-fetching.
    @discardableResult
    public static func recordPRs(
        for session: WorkoutSession,
        in context: ModelContext
    ) -> [PersonalRecord] {
        guard session.isCompleted else { return [] }

        let sessionLifts = liftAttempts(from: session.logs)
        let history = fetchHistoricalLifts(excluding: session, in: context)

        let prs = PRDetector.detectPRs(sessionLifts: sessionLifts, history: history)
        for record in prs {
            let entry = PersonalRecordEntry(record: record, session: session)
            context.insert(entry)
        }
        return prs
    }

    // MARK: - Full rebuild (Trophy-Room manual button + first-run backfill)

    /// Wipes every `PersonalRecordEntry` in the store and re-detects PRs for
    /// every completed session in chronological order. Each session sees only
    /// the sessions BEFORE it as history, matching the live save-hook semantics.
    ///
    /// Use this for:
    ///   - First-launch backfill when the user already has completed sessions
    ///     from before this feature shipped.
    ///   - Manual "neu berechnen" after the user deleted/edited sessions.
    ///
    /// Returns the number of PR rows produced (useful for a confirmation toast).
    @discardableResult
    public static func rebuild(in context: ModelContext) -> Int {
        // 1) Wipe existing PRE rows.
        let existing = (try? context.fetch(FetchDescriptor<PersonalRecordEntry>())) ?? []
        for row in existing { context.delete(row) }

        // 2) Pull every REAL completed session (no rest-day-markers), oldest-first.
        var sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true && $0.isRestDay == false },
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        )
        sessionDescriptor.relationshipKeyPathsForPrefetching = [\.logs]
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []

        // 3) Walk chronologically, accumulating history-as-we-go.
        var historyLifts: [LiftAttempt] = []
        var inserted = 0

        for session in sessions {
            let sessionLifts = liftAttempts(from: session.logs)
            let prs = PRDetector.detectPRs(sessionLifts: sessionLifts, history: historyLifts)
            for record in prs {
                let entry = PersonalRecordEntry(record: record, session: session)
                context.insert(entry)
                inserted += 1
            }
            // Append AFTER detection — the current session shouldn't be its
            // own history (matches the strict-greater-than contract).
            historyLifts.append(contentsOf: sessionLifts)
        }
        return inserted
    }

    // MARK: - Internals

    /// Maps `ExerciseLog` to `LiftAttempt`. Logs with no exercise (orphans
    /// from a deleted Exercise) are dropped.
    private static func liftAttempts(from logs: [ExerciseLog]) -> [LiftAttempt] {
        logs.compactMap { log -> LiftAttempt? in
            guard let exercise = log.exercise else { return nil }
            return LiftAttempt(
                exerciseName: exercise.name,
                weightKg: log.weight,
                reps: log.reps,
                date: log.date,
                isCardio: exercise.isCardio,
                isTimeBased: exercise.isTimeBased
            )
        }
    }

    /// Pulls every log from completed sessions OTHER than `session`. Equivalent
    /// to the WorkoutSummaryView's @Query+filter, but usable outside a view body.
    private static func fetchHistoricalLifts(
        excluding session: WorkoutSession,
        in context: ModelContext
    ) -> [LiftAttempt] {
        let thisID = session.persistentModelID
        let descriptor = FetchDescriptor<ExerciseLog>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.compactMap { log -> LiftAttempt? in
            guard let exercise = log.exercise,
                  let logSession = log.session,
                  logSession.isCompleted,
                  logSession.persistentModelID != thisID
            else { return nil }
            return LiftAttempt(
                exerciseName: exercise.name,
                weightKg: log.weight,
                reps: log.reps,
                date: log.date,
                isCardio: exercise.isCardio,
                isTimeBased: exercise.isTimeBased
            )
        }
    }
}
#endif
