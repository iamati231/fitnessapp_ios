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

    /// DEL-100: Persoenlicher Coaching-Stil. Persistiert als String, sodass
    /// pre-DEL-100-Bestand via Default-Wert lightweight migriert wird.
    public var coachingToneRaw: String = CoachingTone.analytical.rawValue

    /// DEL-100: Langfristiges Trainings-Hauptziel. Steuert zusammen mit
    /// `coachingTone` die Matrix-Lookup-Keys der Coaching-Engine.
    public var trainingGoalRaw: String = TrainingGoal.hybrid.rawValue

    /// Convenience-Accessor mit Default-Fallback, falls jemand einen
    /// invaliden String reinschreibt.
    public var coachingTone: CoachingTone {
        get { CoachingTone(rawValue: coachingToneRaw) ?? .analytical }
        set { coachingToneRaw = newValue.rawValue }
    }

    public var trainingGoal: TrainingGoal {
        get { TrainingGoal(rawValue: trainingGoalRaw) ?? .hybrid }
        set { trainingGoalRaw = newValue.rawValue }
    }

    public init(
        birthDate: Date,
        heightCm: Double,
        profile: BodyFormulaProfile,
        goalWeightKg: Double? = nil,
        environment: EnvironmentType = .gym,
        coachingTone: CoachingTone = .analytical,
        trainingGoal: TrainingGoal = .hybrid
    ) {
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.profile = profile
        self.goalWeightKg = goalWeightKg
        self.environment = environment
        self.coachingToneRaw = coachingTone.rawValue
        self.trainingGoalRaw = trainingGoal.rawValue
    }
}
#endif
