import XCTest
@testable import DeltiqCore

final class ProgressPriorityResolverTests: XCTestCase {
    typealias Resolver = ProgressPriorityResolver
    typealias Availability = ProgressPriorityResolver.DataAvailability

    // MARK: - Full data

    func test_hypertrophy_fullData() {
        XCTAssertEqual(Resolver.resolve(goal: .hypertrophy, data: .full),
                       [.strengthVolume, .personalRecords, .workoutFrequency])
    }

    func test_strength_fullData() {
        XCTAssertEqual(Resolver.resolve(goal: .strength, data: .full),
                       [.personalRecords, .strengthVolume, .workoutFrequency])
    }

    func test_hybrid_fullData() {
        XCTAssertEqual(Resolver.resolve(goal: .hybrid, data: .full),
                       [.strengthVolume, .cardioPerformance, .bodyComposition])
    }

    func test_weightLoss_fullData() {
        XCTAssertEqual(Resolver.resolve(goal: .weightLoss, data: .full),
                       [.bodyComposition, .calorieBalance, .cardioPerformance])
    }

    func test_functional_fullData() {
        XCTAssertEqual(Resolver.resolve(goal: .functional, data: .full),
                       [.workoutFrequency, .cardioPerformance, .strengthVolume])
    }

    func test_endurance_fullData() {
        XCTAssertEqual(Resolver.resolve(goal: .endurance, data: .full),
                       [.cardioPerformance, .workoutFrequency, .bodyComposition])
    }

    // MARK: - Empty data

    func test_allGoals_emptyData_returnsEmpty() {
        for goal in TrainingGoal.allCases {
            XCTAssertTrue(Resolver.resolve(goal: goal, data: .empty).isEmpty,
                          "Goal \(goal) should return empty with no data")
        }
    }

    // MARK: - Partial data

    func test_hypertrophy_onlyStrength_allThreeMetrics() {
        // workoutFrequency requires strength OR cardio, so all 3 hypertrophy metrics resolve
        let data = Availability(hasStrengthSessions: true, hasCardioSessions: false,
                                hasBodyMeasurements: false, hasNutritionLogs: false)
        XCTAssertEqual(Resolver.resolve(goal: .hypertrophy, data: data),
                       [.strengthVolume, .personalRecords, .workoutFrequency])
    }

    func test_weightLoss_onlyCardio_returnsOnlyCardio() {
        let data = Availability(hasStrengthSessions: false, hasCardioSessions: true,
                                hasBodyMeasurements: false, hasNutritionLogs: false)
        XCTAssertEqual(Resolver.resolve(goal: .weightLoss, data: data),
                       [.cardioPerformance])
    }

    func test_endurance_onlyStrength_returnsFrequencyOnly() {
        // cardioPerformance filtered (no cardio), bodyComposition filtered (no body)
        let data = Availability(hasStrengthSessions: true, hasCardioSessions: false,
                                hasBodyMeasurements: false, hasNutritionLogs: false)
        XCTAssertEqual(Resolver.resolve(goal: .endurance, data: data), [.workoutFrequency])
    }

    // MARK: - Cap at 3

    func test_allGoals_neverExceedThree() {
        for goal in TrainingGoal.allCases {
            let count = Resolver.resolve(goal: goal, data: .full).count
            XCTAssertLessThanOrEqual(count, 3, "Goal \(goal) returned \(count) metrics")
        }
    }
}

private extension ProgressPriorityResolver.DataAvailability {
    static let full = ProgressPriorityResolver.DataAvailability(
        hasStrengthSessions: true,
        hasCardioSessions: true,
        hasBodyMeasurements: true,
        hasNutritionLogs: true
    )
}
