#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Singleton-style profile entity. Only one row should exist per app install —
/// caller-side responsibility (SwiftData has no manual singleton constraint).
/// Mirrors the `user_body_profile` Room table.
@Model
public final class UserBodyProfile {
    public var birthDate: Date
    public var heightCm: Double
    public var profile: BodyFormulaProfile
    /// Target body weight entered during onboarding (Fat-Loss goal). Nil if not set (F153).
    public var goalWeightKg: Double?
    /// Training location chosen in onboarding — drives plan recommendations (F154).
    public var environment: EnvironmentType

    public init(
        birthDate: Date,
        heightCm: Double,
        profile: BodyFormulaProfile,
        goalWeightKg: Double? = nil,
        environment: EnvironmentType = .gym
    ) {
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.profile = profile
        self.goalWeightKg = goalWeightKg
        self.environment = environment
    }
}
#endif
