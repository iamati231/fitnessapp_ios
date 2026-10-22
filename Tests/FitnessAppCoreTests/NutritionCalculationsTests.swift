import XCTest
@testable import FitnessAppCore

final class NutritionCalculationsTests: XCTestCase {

    let chicken = FoodCatalogItem(
        id: "test_chicken", nameKey: "x", category: .meat,
        kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6,
        defaultServingGrams: nil, servingNameKey: nil,
        pieceWeightGrams: nil, densityGramsPerMl: nil
    )
    let milk = FoodCatalogItem(
        id: "test_milk", nameKey: "x", category: .dairy,
        kcalPer100g: 64, proteinPer100g: 3.3, carbsPer100g: 4.8, fatPer100g: 3.6,
        defaultServingGrams: nil, servingNameKey: nil,
        pieceWeightGrams: nil, densityGramsPerMl: 1.03
    )
    let egg = FoodCatalogItem(
        id: "test_egg", nameKey: "x", category: .egg,
        kcalPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11,
        defaultServingGrams: nil, servingNameKey: nil,
        pieceWeightGrams: 60, densityGramsPerMl: nil
    )

    func testGramScalesLinearly() {
        let result = NutritionCalculations.nutrients(for: chicken, quantity: 200, unit: .gram)
        XCTAssertEqual(result?.kcal, 330)
        XCTAssertEqual(result?.proteinG, 62)
    }

    func testMillilitersUsesExplicitDensityNotOneToOne() throws {
        // 100 ml Milch wiegt 103 g, nicht 100 g — Spec 4.2
        let result = NutritionCalculations.nutrients(for: milk, quantity: 100, unit: .milliliter)
        XCTAssertEqual(try XCTUnwrap(result).kcal, 64 * 1.03, accuracy: 0.0001)
    }

    func testMillilitersWithoutDensityReturnsNil() {
        XCTAssertNil(NutritionCalculations.nutrients(for: chicken, quantity: 100, unit: .milliliter))
    }

    func testPieceWithoutPieceWeightReturnsNil() {
        XCTAssertNil(NutritionCalculations.nutrients(for: chicken, quantity: 1, unit: .piece))
    }

    func testPieceUsesPieceWeight() throws {
        let result = NutritionCalculations.nutrients(for: egg, quantity: 2, unit: .piece)
        XCTAssertEqual(try XCTUnwrap(result).kcal, 155 * 1.2, accuracy: 0.0001) // 2 × 60g = 120g
    }

    func testNonPositiveQuantityReturnsNil() {
        XCTAssertNil(NutritionCalculations.nutrients(for: chicken, quantity: 0, unit: .gram))
        XCTAssertNil(NutritionCalculations.nutrients(for: chicken, quantity: -5, unit: .gram))
    }

    func testSumAddsAllFields() {
        let a = NutrientValues(kcal: 100, proteinG: 10, carbsG: 5, fatG: 2)
        let b = NutrientValues(kcal: 50, proteinG: 2, carbsG: 8, fatG: 1)
        let total = NutrientValues.sum([a, b])
        XCTAssertEqual(total.kcal, 150)
        XCTAssertEqual(total.carbsG, 13)
    }

    func testSupportsReflectsAvailableUnitsOnly() {
        XCTAssertTrue(chicken.supports(.gram))
        XCTAssertFalse(chicken.supports(.piece))
        XCTAssertFalse(chicken.supports(.milliliter))
        XCTAssertTrue(milk.supports(.milliliter))
        XCTAssertTrue(egg.supports(.piece))
    }

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

    // MARK: GoalProgress — shared by the progress-bar UI and the AI insight prompt

    /// The reported bug's exact numbers: 40g of a 150g protein goal is
    /// 26.7% / 110g remaining, not the "super"/near-complete progress the AI
    /// insight previously implied by never being told the percentage at all.
    func testGoalProgress_40Of150_isRoughly27PercentWith110Remaining() throws {
        let progress = try XCTUnwrap(NutritionCalculations.goalProgress(current: 40, goal: 150))
        XCTAssertEqual(progress.percent, 27) // 26.666...% rounded
        XCTAssertEqual(progress.remaining, 110, accuracy: 0.0001)
        XCTAssertEqual(progress.fraction, 40.0 / 150.0, accuracy: 0.0001)
    }

    func testGoalProgress_goalExceeded_remainingFlooredAtZero_percentNotCappedAt100() throws {
        let progress = try XCTUnwrap(NutritionCalculations.goalProgress(current: 160, goal: 150))
        XCTAssertEqual(progress.percent, 107) // 106.66...% rounded, stated plainly past 100
        XCTAssertEqual(progress.remaining, 0)
        XCTAssertEqual(progress.fraction, 1.0) // capped, for the progress bar
    }

    func testGoalProgress_zeroOrNegativeGoal_returnsNil() {
        XCTAssertNil(NutritionCalculations.goalProgress(current: 40, goal: 0))
        XCTAssertNil(NutritionCalculations.goalProgress(current: 40, goal: -10))
    }
}
