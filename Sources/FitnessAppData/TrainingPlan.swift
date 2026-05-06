#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

@Model
public final class TrainingPlan {
    public var name: String
    public var programType: String
    public var descriptionText: String
    public var weeks: Int
    public var isActive: Bool
    /// Environment this plan is designed for — used to filter recommendations (F154).
    public var targetEnvironment: EnvironmentType

    @Relationship(deleteRule: .cascade, inverse: \TrainingDay.plan)
    public var days: [TrainingDay] = []

    public init(
        name: String = "",
        programType: String = "",
        descriptionText: String = "",
        weeks: Int = 12,
        isActive: Bool = false,
        targetEnvironment: EnvironmentType = .gym
    ) {
        self.name = name
        self.programType = programType
        self.descriptionText = descriptionText
        self.weeks = weeks
        self.isActive = isActive
        self.targetEnvironment = targetEnvironment
    }
}
#endif
