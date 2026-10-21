#if canImport(SwiftData)
import XCTest
import SwiftData
@testable import FitnessAppData
import FitnessAppCore

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class UserBodyProfileNutritionGoalsTests: XCTestCase {
    func testGoalsDefaultToNilForExistingProfiles() throws {
        let schema = Schema(AppSchema.types)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let profile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        container.mainContext.insert(profile)
        try container.mainContext.save()

        XCTAssertNil(profile.dailyCalorieGoalKcal)
        XCTAssertNil(profile.dailyProteinGoalG)
        XCTAssertNil(profile.dailyCarbGoalG)
        XCTAssertNil(profile.dailyFatGoalG)
    }

    func testGoalsAreIndependentlySettable() {
        let profile = UserBodyProfile(birthDate: Date(), heightCm: 180, profile: .male)
        profile.dailyCalorieGoalKcal = 2200
        XCTAssertEqual(profile.dailyCalorieGoalKcal, 2200)
        XCTAssertNil(profile.dailyProteinGoalG, "Setzen eines Ziels darf andere nicht beeinflussen")
    }
}
#endif
