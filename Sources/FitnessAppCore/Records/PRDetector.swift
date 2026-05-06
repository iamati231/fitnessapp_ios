import Foundation

/// Detects personal records inside a workout session against historical attempts.
///
/// **Algorithm contract:**
///   1. Strict greater-than only — ties don't count as PRs (avoids spamming on
///      consistent lifters who hit the same numbers session after session).
///   2. At most one PR per (exercise, kind) per session — the BEST attempt
///      is the one credited (e.g., three new heaviest sets in a row → one PR).
///   3. Cardio (`isCardio == true`), time-based (`isTimeBased == true`), and
///      weight-zero attempts (bodyweight pull-ups, Plank, etc.) are filtered
///      out. Their PR semantics differ — handled in a future iteration.
///   4. An exercise with no historical attempts in `history` produces NO PRs
///      (first session establishes a baseline; you can't "beat" nothing).
public enum PRDetector {

    /// Returns the personal records achieved by `sessionLifts` against `history`.
    /// Sorted by exercise name for deterministic UI ordering.
    public static func detectPRs(
        sessionLifts: [LiftAttempt],
        history: [LiftAttempt]
    ) -> [PersonalRecord] {
        let validSession = sessionLifts.filter(isWeightedLift)
        let validHistory = history.filter(isWeightedLift)

        let bySessionExercise = Dictionary(grouping: validSession, by: \.exerciseName)
        var records: [PersonalRecord] = []

        for (exerciseName, attempts) in bySessionExercise {
            let exerciseHistory = validHistory.filter { $0.exerciseName == exerciseName }
            // No history → first time training this exercise → skip.
            guard !exerciseHistory.isEmpty else { continue }

            // 1) Heaviest weight
            if let pr = heaviestWeightPR(in: attempts, history: exerciseHistory,
                                          exerciseName: exerciseName) {
                records.append(pr)
            }

            // 2) Best set (volume)
            if let pr = bestSetPR(in: attempts, history: exerciseHistory,
                                   exerciseName: exerciseName) {
                records.append(pr)
            }

            // 3) Estimated 1RM (Epley/Brzycki average)
            if let pr = estimated1RMPR(in: attempts, history: exerciseHistory,
                                        exerciseName: exerciseName) {
                records.append(pr)
            }
        }

        return records.sorted { lhs, rhs in
            if lhs.exerciseName != rhs.exerciseName {
                return lhs.exerciseName < rhs.exerciseName
            }
            // Within an exercise: 1RM first, then weight, then volume — gives
            // the user the "biggest deal" PR first when multiple kinds fired.
            return kindOrder(lhs.kind) < kindOrder(rhs.kind)
        }
    }

    // MARK: Per-kind detection

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
        let prevBest = history.map(volume).max() ?? 0
        guard let bestNow = attempts.max(by: { volume($0) < volume($1) }) else { return nil }
        let nowVolume = volume(bestNow)
        guard nowVolume > prevBest else { return nil }
        return PersonalRecord(
            kind: .bestSet,
            exerciseName: exerciseName,
            weightKg: bestNow.weightKg,
            reps: bestNow.reps,
            previousValue: prevBest,
            newValue: nowVolume,
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

    // MARK: Helpers

    private static func isWeightedLift(_ lift: LiftAttempt) -> Bool {
        !lift.isCardio && !lift.isTimeBased && lift.weightKg > 0 && lift.reps > 0
    }

    private static func volume(_ lift: LiftAttempt) -> Double {
        lift.weightKg * Double(lift.reps)
    }

    private static func estimated1RM(_ lift: LiftAttempt) -> Double? {
        ExerciseCalculations.estimate1RMAverage(weightKg: lift.weightKg, reps: lift.reps)
    }

    /// Display-priority within an exercise: 1RM (most "wow"), weight, volume.
    private static func kindOrder(_ kind: PersonalRecord.Kind) -> Int {
        switch kind {
        case .estimated1RM:    return 0
        case .heaviestWeight:  return 1
        case .bestSet:         return 2
        }
    }
}
