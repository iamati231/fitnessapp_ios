#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

@Model
public final class TrainingDay {
    public var name: String
    public var weekday: Int
    public var type: DayType
    public var nextIntensity: DayIntensity

    public var plan: TrainingPlan?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.day)
    public var exercises: [Exercise] = []

    public init(
        name: String,
        weekday: Int,
        type: DayType = .custom,
        nextIntensity: DayIntensity = .normal,
        plan: TrainingPlan? = nil
    ) {
        self.name = name
        self.weekday = weekday
        self.type = type
        self.nextIntensity = nextIntensity
        self.plan = plan
    }
}
#endif
