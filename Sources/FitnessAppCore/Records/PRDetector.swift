import Foundation

/// Detects personal records inside a workout session against historical attempts.
///
/// **Algorithm contract:**
///   1. Strict greater-than only — ties don't count as PRs (avoids spamming on
///      consistent lifters who hit the same numbers session after session).
///   2. At most one PR per (exercise, kind) per session — the BEST attempt
///      is the one credited (e.g., three new heaviest sets in a row → one PR).
///   3. **Per-exercise categorization** — each exercise is classified once based
///      on the union of session + history attempts:
///        - `.timeBased` if ANY attempt has `isTimeBased == true` (a "weighted plank"
///          still counts as time-based, weight is ignored)
///        - `.weighted` if ANY attempt has `weightKg > 0`
///        - `.bodyweight` if all attempts have `weightKg == 0` and reps > 0
///      The detected PR kinds are limited to those valid for the category, so a
///      weighted-pullup session falls back to weighted PRs (heaviestWeight/bestSet/
///      1RM) rather than maxReps.
///   4. Cardio (`isCardio == true`) is filtered out at the top — different
///      metric domain (pace/distance/heart-rate) belongs in a separate detector.
///   5. An exercise with no historical attempts in `history` produces no PRs
///      (first session establishes a baseline; you can't beat nothing).
public enum PRDetector {

    /// Returns the personal records achieved by `sessionLifts` against `history`.
    /// Sorted by exercise name, then by display priority within an exercise.
    public static func detectPRs(
        sessionLifts: [LiftAttempt],
        history: [LiftAttempt]
    ) -> [PersonalRecord] {
        // Cardio out of the picture entirely.
        let validSession = sessionLifts.filter { !$0.isCardio }
        let validHistory = history.filter { !$0.isCardio }

        let bySessionExercise = Dictionary(grouping: validSession, by: \.exerciseName)
        var records: [PersonalRecord] = []

        for (exerciseName, sessionAttempts) in bySessionExercise {
            let exerciseHistory = validHistory.filter { $0.exerciseName == exerciseName }
            guard !exerciseHistory.isEmpty else { continue }    // Need a baseline.

            // Categorize the exercise using session AND history together — a single
            // weighted attempt anywhere flips the category to weighted, so a user
            // adding belt-weight to pullups for the first time gets weighted PRs.
            let category = categorize(attempts: sessionAttempts + exerciseHistory)

            switch category {
            case .weighted:
                records.append(contentsOf: detectWeightedPRs(
                    sessionAttempts: sessionAttempts,
                    exerciseHistory: exerciseHistory,
                    exerciseName: exerciseName
                ))

            case .bodyweight:
                if let pr = maxRepsPR(
                    in: sessionAttempts,
                    history: exerciseHistory,
                    exerciseName: exerciseName
                ) {
                    records.append(pr)
                }

            case .timeBased:
                if let pr = maxHoldSecondsPR(
                    in: sessionAttempts,
                    history: exerciseHistory,
                    exerciseName: exerciseName
                ) {
                    records.append(pr)
                }

            case .invalid:
                continue
            }
        }

        return records.sorted { lhs, rhs in
            if lhs.exerciseName != rhs.exerciseName {
                return lhs.exerciseName < rhs.exerciseName
            }
            return kindOrder(lhs.kind) < kindOrder(rhs.kind)
        }
    }

    // MARK: Categorization

    private enum ExerciseCategory {
        case weighted
        case bodyweight
        case timeBased
        case invalid
    }

    /// Order of priority: timeBased → weighted → bodyweight → invalid.
    /// timeBased takes precedence so a "weighted plank" still uses hold-time PRs.
    private static func categorize(attempts: [LiftAttempt]) -> ExerciseCategory {
        if attempts.isEmpty { return .invalid }
        if attempts.contains(where: { $0.isTimeBased }) { return .timeBased }
        if attempts.contains(where: { $0.weightKg > 0 }) { return .weighted }
        if attempts.contains(where: { $0.reps > 0 }) { return .bodyweight }
        return .invalid
    }

    // MARK: Weighted (3 kinds)

    private static func detectWeightedPRs(
        sessionAttempts: [LiftAttempt],
        exerciseHistory: [LiftAttempt],
        exerciseName: String
    ) -> [PersonalRecord] {
        let weighted = sessionAttempts.filter {
            $0.weightKg > 0 && $0.reps > 0 && !$0.isTimeBased
        }
        let weightedHistory = exerciseHistory.filter {
            $0.weightKg > 0 && $0.reps > 0 && !$0.isTimeBased
        }
        guard !weighted.isEmpty else { return [] }

        var records: [PersonalRecord] = []
        if let pr = heaviestWeightPR(in: weighted, history: weightedHistory, exerciseName: exerciseName) {
            records.append(pr)
        }
        if let pr = bestSetPR(in: weighted, history: weightedHistory, exerciseName: exerciseName) {
            records.append(pr)
        }
        if let pr = estimated1RMPR(in: weighted, history: weightedHistory, exerciseName: exerciseName) {
            records.append(pr)
        }
        return records
    }

    private static func heaviestWeightPR(
        in attempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String
    ) -> PersonalRecord? {
        let prevBest = history.map(\.weightKg).max() ?? 0
        guard let bestNow = attempts.max(by: { $0.weightKg < $1.weightKg }) else { return nil }
        guard bestNow.weightKg > prevBest else { return nil }
        return PersonalRecord(
            kind: .heaviestWeight,
            exerciseName: exerciseName,
            weightKg: bestNow.weightKg,
            reps: bestNow.reps,
            previousValue: prevBest,
            newValue: bestNow.weightKg,
            achievedAt: bestNow.date
        )
    }

    private static func bestSetPR(
        in attempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String
    ) -> PersonalRecord? {
        let prevBest = history.map(\.volume).max() ?? 0
        guard let bestNow = attempts.max(by: { $0.volume < $1.volume }) else { return nil }
        guard bestNow.volume > prevBest else { return nil }
        return PersonalRecord(
            kind: .bestSet,
            exerciseName: exerciseName,
            weightKg: bestNow.weightKg,
            reps: bestNow.reps,
            previousValue: prevBest,
            newValue: bestNow.volume,
            achievedAt: bestNow.date
        )
    }

    private static func estimated1RMPR(
        in attempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String
    ) -> PersonalRecord? {
        let prevBest = history.compactMap(estimated1RM).max() ?? 0
        let nowCandidates = attempts.compactMap { lift -> (LiftAttempt, Double)? in
            guard let oneRM = estimated1RM(lift) else { return nil }
            return (lift, oneRM)
        }
        guard let bestNow = nowCandidates.max(by: { $0.1 < $1.1 }) else { return nil }
        guard bestNow.1 > prevBest else { return nil }
        return PersonalRecord(
            kind: .estimated1RM,
            exerciseName: exerciseName,
            weightKg: bestNow.0.weightKg,
            reps: bestNow.0.reps,
            previousValue: prevBest,
            newValue: bestNow.1,
            achievedAt: bestNow.0.date
        )
    }

    // MARK: Bodyweight (max-reps)

    private static func maxRepsPR(
        in sessionAttempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String
    ) -> PersonalRecord? {
        let valid = sessionAttempts.filter {
            $0.weightKg == 0 && $0.reps > 0 && !$0.isTimeBased
        }
        let validHistory = history.filter {
            $0.weightKg == 0 && $0.reps > 0 && !$0.isTimeBased
        }
        guard !valid.isEmpty, !validHistory.isEmpty else { return nil }

        let prevBestReps = validHistory.map(\.reps).max() ?? 0
        guard let bestNow = valid.max(by: { $0.reps < $1.reps }) else { return nil }
        guard bestNow.reps > prevBestReps else { return nil }
        return PersonalRecord(
            kind: .maxReps,
            exerciseName: exerciseName,
            weightKg: 0,
            reps: bestNow.reps,
            previousValue: Double(prevBestReps),
            newValue: Double(bestNow.reps),
            achievedAt: bestNow.date
        )
    }

    // MARK: Time-based (max-hold-seconds)

    private static func maxHoldSecondsPR(
        in sessionAttempts: [LiftAttempt],
        history: [LiftAttempt],
        exerciseName: String
    ) -> PersonalRecord? {
        // For time-based: `reps` carries seconds. Weight is ignored even if > 0.
        let valid = sessionAttempts.filter { $0.isTimeBased && $0.reps > 0 }
        let validHistory = history.filter { $0.isTimeBased && $0.reps > 0 }
        guard !valid.isEmpty, !validHistory.isEmpty else { return nil }

        let prevBestSeconds = validHistory.map(\.reps).max() ?? 0
        guard let bestNow = valid.max(by: { $0.reps < $1.reps }) else { return nil }
        guard bestNow.reps > prevBestSeconds else { return nil }
        return PersonalRecord(
            kind: .maxHoldSeconds,
            exerciseName: exerciseName,
            weightKg: bestNow.weightKg,        // preserved for display, not for PR-math
            reps: bestNow.reps,
            previousValue: Double(prevBestSeconds),
            newValue: Double(bestNow.reps),
            achievedAt: bestNow.date
        )
    }

    // MARK: Helpers

    private static func estimated1RM(_ lift: LiftAttempt) -> Double? {
        ExerciseCalculations.estimate1RMAverage(weightKg: lift.weightKg, reps: lift.reps)
    }

    /// Display-priority within an exercise. 1RM is the most "wow" weighted PR;
    /// time + reps PRs come last because they're typically standalone categories
    /// (a time-based exercise can't also produce 1RM).
    private static func kindOrder(_ kind: PersonalRecord.Kind) -> Int {
        switch kind {
        case .estimated1RM:    return 0
        case .heaviestWeight:  return 1
        case .bestSet:         return 2
        case .maxReps:         return 3
        case .maxHoldSeconds:  return 4
        }
    }
}
