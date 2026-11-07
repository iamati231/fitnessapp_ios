import Foundation

/// Phase 3 WP-A: Primaere Coaching-Empfehlung, die der integrierte Advisor
/// zurueckgibt. Reine Werttypen, keine SwiftData-/UI-Abhaengigkeit.
public enum CoachingAction: Sendable, Equatable {
    case maintainCurrent
    case reduceLoadThisWeek
    case increaseWeeklyVolume(targetPercent: Double)
    case reassessGoal
    case planAdjustmentAvailable
    case buildRunningBase
    case insufficientData
}

public enum CoachingRationale: Sendable, Equatable {
    case positiveProgressHighLoad
    case positiveProgressStableLoad
    case plateauNearRace(weeksToRace: Int)
    case goalLikelyUnreachable
    case recentGapDetected
    case recoveryNeeded
    case noRunningData
    case crossTrainingOnly
    case shortHistory
    case planJustAdjusted
}

public enum DataQualityIssue: Sendable, Equatable {
    case runningDistanceMissing(weekCount: Int)
    case ambiguousActivitiesPresent(weekCount: Int)
    case durationDataUnavailable
    case historyTooShort(weeksAvailable: Int, weeksNeeded: Int)
}

public struct IntegratedCoachingOutcome: Sendable, Equatable {
    public let primaryAction: CoachingAction
    public let rationale: CoachingRationale
    public let dataQualityIssues: [DataQualityIssue]

    public init(
        primaryAction: CoachingAction,
        rationale: CoachingRationale,
        dataQualityIssues: [DataQualityIssue]
    ) {
        self.primaryAction = primaryAction
        self.rationale = rationale
        self.dataQualityIssues = dataQualityIssues
    }
}
