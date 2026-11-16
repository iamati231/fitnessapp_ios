import Foundation

public enum ProgressMetric: String, Sendable, CaseIterable {
    case strengthVolume
    case personalRecords
    case cardioPerformance
    case bodyComposition
    case workoutFrequency
    case calorieBalance
}

public enum ProgressPriorityResolver {
    public struct DataAvailability: Sendable {
        public let hasStrengthSessions: Bool
        public let hasCardioSessions: Bool
        public let hasBodyMeasurements: Bool
        public let hasNutritionLogs: Bool

        public init(
            hasStrengthSessions: Bool,
            hasCardioSessions: Bool,
            hasBodyMeasurements: Bool,
            hasNutritionLogs: Bool
        ) {
            self.hasStrengthSessions = hasStrengthSessions
            self.hasCardioSessions = hasCardioSessions
            self.hasBodyMeasurements = hasBodyMeasurements
            self.hasNutritionLogs = hasNutritionLogs
        }

        public static let empty = DataAvailability(
            hasStrengthSessions: false,
            hasCardioSessions: false,
            hasBodyMeasurements: false,
            hasNutritionLogs: false
        )
    }

    public static func resolve(goal: TrainingGoal, data: DataAvailability) -> [ProgressMetric] {
        let priority: [ProgressMetric]
        switch goal {
        case .hypertrophy: priority = [.strengthVolume, .personalRecords, .workoutFrequency]
        case .strength:    priority = [.personalRecords, .strengthVolume, .workoutFrequency]
        case .hybrid:      priority = [.strengthVolume, .cardioPerformance, .bodyComposition]
        case .weightLoss:  priority = [.bodyComposition, .calorieBalance, .cardioPerformance]
        case .functional:  priority = [.workoutFrequency, .cardioPerformance, .strengthVolume]
        case .endurance:   priority = [.cardioPerformance, .workoutFrequency, .bodyComposition]
        }
        return Array(priority.filter { isAvailable($0, data: data) }.prefix(3))
    }

    private static func isAvailable(_ metric: ProgressMetric, data: DataAvailability) -> Bool {
        switch metric {
        case .strengthVolume, .personalRecords:
            return data.hasStrengthSessions
        case .cardioPerformance:
            return data.hasCardioSessions
        case .bodyComposition:
            return data.hasBodyMeasurements
        case .workoutFrequency:
            return data.hasStrengthSessions || data.hasCardioSessions
        case .calorieBalance:
            return data.hasNutritionLogs
        }
    }
}
