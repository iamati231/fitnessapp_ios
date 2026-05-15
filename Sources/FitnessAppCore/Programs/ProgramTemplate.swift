import Foundation

/// Pure-data spec for a complete training program (e.g., Push-Pull-Legs, 5×5).
/// Materialized into a `TrainingPlan` + `TrainingDay`s + `Exercise`s by
/// `ProgramInstantiator` in `FitnessAppData`.
public struct ProgramTemplate: Sendable, Hashable, Identifiable {
    /// Stable string identifier — persisted on `TrainingPlan.programType` so we can
    /// detect "user's plan was originally a PPL template" later for re-recommendations.
    public let id: String
    public let name: String
    public let tagline: String
    public let descriptionText: String
    public let focus: String
    public let daysPerWeek: Int
    /// DEL-088: `days` enthaelt jetzt NUR Trainings-Tage, sortiert nach
    /// `sequenceIndex` (1...daysPerWeek). Rest-Tage werden beim Instanziieren
    /// vom `ProgramInstantiator` automatisch in die restlichen Wochentage
    /// gefuellt — der User waehlt seine Wochentage erst beim Adopt.
    public let days: [DaySpec]
    public let targetEnvironment: EnvironmentType
    /// SF Symbol name displayed as the program tile icon. Picked per program;
    /// can be replaced with a real custom-asset on the iOS side later.
    public let iconSystemName: String

    /// DEL-090: Quiz-Matchmaker-Tags. Mehrwertig, damit ein Plan auf mehrere
    /// Antwortkombinationen passen kann (z.B. PPL ist sowohl Hypertrophie als
    /// auch Kraft; Hybrid passt Beginner UND Intermediate).
    public let targetExperience: [ExperienceLevel]
    public let targetGoals: [GoalType]

    public init(
        id: String,
        name: String,
        tagline: String,
        descriptionText: String,
        focus: String,
        daysPerWeek: Int,
        days: [DaySpec],
        targetEnvironment: EnvironmentType = .gym,
        iconSystemName: String = "figure.strengthtraining.traditional",
        targetExperience: [ExperienceLevel] = [.intermediate],
        targetGoals: [GoalType] = [.hypertrophy]
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.descriptionText = descriptionText
        self.focus = focus
        self.daysPerWeek = daysPerWeek
        self.days = days
        self.targetEnvironment = targetEnvironment
        self.iconSystemName = iconSystemName
        self.targetExperience = targetExperience
        self.targetGoals = targetGoals
    }
}
