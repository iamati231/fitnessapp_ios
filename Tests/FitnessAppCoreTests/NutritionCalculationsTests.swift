import XCTest
@testable import FitnessAppCore

final class NutritionCalculationsTests: XCTestCase {

    func testWaterTarget80kgDefaultMultiplier() {
        // 80 kg × 35 ml = 2800 ml
        XCTAssertEqual(
            NutritionCalculations.dailyWaterTargetMl(weightKg: 80),
            2800
        )
    }

    func testWaterTarget72_5kgRoundsCorrectly() {
        // 72.5 × 35 = 2537.5 → rounded to 2538
        XCTAssertEqual(
            NutritionCalculations.dailyWaterTargetMl(weightKg: 72.5),
            2538
        )
    }

    func testWaterTargetCustomAthleteMultiplier() {
        // 80 kg × 45 ml (athlete) = 3600 ml
        XCTAssertEqual(
            NutritionCalculations.dailyWaterTargetMl(weightKg: 80, multiplier: 45),
            3600
        )
    }

    func testWaterTargetZeroWeightReturnsZero() {
        XCTAssertEqual(NutritionCalculations.dailyWaterTargetMl(weightKg: 0), 0)
    }

    func testWaterTargetNegativeWeightReturnsZero() {
        // Defensive — uninitialized profile or division-by-something edge case
        XCTAssertEqual(NutritionCalculations.dailyWaterTargetMl(weightKg: -5), 0)
    }
}
