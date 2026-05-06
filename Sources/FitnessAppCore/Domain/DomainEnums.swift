import Foundation

/// Equipment categories used to classify exercises and filter the library.
public enum Equipment: String, Codable, Sendable, CaseIterable {
    case barbell
    case dumbbell
    case bodyweight
    case machine
    case cable
    case kettlebell
    /// Resistance bands — typical for home/bodyweight training (F154).
    case band
}

/// Where the user trains. Drives plan recommendations and the equipment filter
/// for the "swap exercise" feature. Hierarchy: gym ⊇ homeGym ⊇ noEquipment.
public enum EnvironmentType: String, Codable, Sendable, CaseIterable {
    case gym
    case homeGym
    case noEquipment

    /// Equipment types available in this environment.
    public var allowedEquipment: [Equipment] {
        switch self {
        case .gym:         return Equipment.allCases
        case .homeGym:     return [.barbell, .dumbbell, .bodyweight, .kettlebell, .band]
        case .noEquipment: return [.bodyweight, .band]
        }
    }

    /// True when a user training in `self` can physically execute a plan
    /// designed for `planEnv`. Mirrors Android's `canExecutePlan`.
    public func canExecute(planEnvironment planEnv: EnvironmentType) -> Bool {
        switch self {
        case .gym:         return true
        case .homeGym:     return planEnv == .homeGym || planEnv == .noEquipment
        case .noEquipment: return planEnv == .noEquipment
        }
    }
}

public enum MuscleGroup: String, Codable, Sendable, CaseIterable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case quads
    case hamstrings
    case glutes
    case calves
    case core
}

public enum DayType: String, Codable, Sendable, CaseIterable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case push
    case pull
    case upper
    case lower
    case fullBody
    case rest
    case custom
}

public enum DayIntensity: String, Codable, Sendable, CaseIterable {
    case normal
    case light
    case heavy
}

/// Difficulty classification for exercise templates — used by the library filter (F99).
public enum DifficultyLevel: String, Codable, Sendable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}
