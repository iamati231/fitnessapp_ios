import XCTest
@testable import FitnessAppCore

final class PlateCalculatorTests: XCTestCase {

    // MARK: Empty / edge cases

    func testEmptyWhenTargetEqualsBar() {
        let result = PlateCalculator.calculate(target: 20, bar: 20, unit: .kg)
        XCTAssertEqual(result, [])
    }

    func testEmptyWhenTargetBelowBar() {
        let result = PlateCalculator.calculate(target: 15, bar: 20, unit: .kg)
        XCTAssertEqual(result, [])
    }

    func testRoundedAwayLeftoverDoesNotAddPlate() {
        // target 20.5 -> per-side 0.25 < smallest 1.25 -> no plates
        let result = PlateCalculator.calculate(target: 20.5, bar: 20, unit: .kg)
        XCTAssertEqual(result, [])
    }

    // MARK: Standard cases (kg)

    func testTargetHundredWithDefaultInventory() {
        // per-side = 40 kg -> 1x25 + 1x15
        let result = PlateCalculator.calculate(target: 100, bar: 20, unit: .kg)
        XCTAssertEqual(result, [PlateConfig(weight: 25, count: 1), PlateConfig(weight: 15, count: 1)])
    }

    func testTargetTwoHundredWithDefaultInventory() {
        // per-side = 90 kg -> 3x25 + 1x15
        let result = PlateCalculator.calculate(target: 200, bar: 20, unit: .kg)
        XCTAssertEqual(result, [PlateConfig(weight: 25, count: 3), PlateConfig(weight: 15, count: 1)])
    }

    func testTargetSmallestPossibleAddsOneSmallPlate() {
        // 22.5 - 20 = 2.5 -> per-side 1.25 -> 1x1.25
        let result = PlateCalculator.calculate(target: 22.5, bar: 20, unit: .kg)
        XCTAssertEqual(result, [PlateConfig(weight: 1.25, count: 1)])
    }

    // MARK: Inventory cap forces spillover

    func testInventoryCapZeroSkipsPlate() {
        // No 25-kg plates in inventory -> 40 kg per side becomes 2x20
        var inv = PlateCalculator.defaultInventoryKg
        inv[25.0] = 0
        let result = PlateCalculator.calculate(target: 100, bar: 20, unit: .kg, inventory: inv)
        XCTAssertEqual(result, [PlateConfig(weight: 20, count: 2)])
    }

    func testInventoryCapForcesSpillToSmallerPlates() {
        // Cap 25-kg at 2 plates per side. Per-side 90 kg can no longer be 3x25 + 1x15 —
        // the algo must spill into 20-kg plates: 2x25 + 2x20 = 90.
        var inv = PlateCalculator.defaultInventoryKg
        inv[25.0] = 2
        let result = PlateCalculator.calculate(target: 200, bar: 20, unit: .kg, inventory: inv)
        XCTAssertEqual(result, [PlateConfig(weight: 25, count: 2), PlateConfig(weight: 20, count: 2)])
    }

    // MARK: lbs unit

    func testLbsTargetHundredFortyFiveWithDefaultInventory() {
        // 145 lbs total, 45 lbs bar -> per-side 50 -> 1x45 + 1x5
        let result = PlateCalculator.calculate(target: 145, bar: 45, unit: .lbs)
        XCTAssertEqual(result, [PlateConfig(weight: 45, count: 1), PlateConfig(weight: 5, count: 1)])
    }

    // MARK: Invariants

    func testHeavyLifterDefaultInventoryReachesMaxKgTotal() {
        // 500 kg total, 20 kg bar, default inventory -> per-side = 240 -> achievable.
        let result = PlateCalculator.calculate(target: 500, bar: 20, unit: .kg)
        let perSideKg = result.reduce(0.0) { $0 + Double($1.count) * $1.weight }
        XCTAssertEqual(perSideKg, 240.0, accuracy: 1e-9)
    }

    func testHeavyLifterDefaultInventoryReachesMaxLbsTotal() {
        // 1100 lbs total, 45 lbs bar -> per-side = 527.5
        let result = PlateCalculator.calculate(target: 1100, bar: 45, unit: .lbs)
        let perSide = result.reduce(0.0) { $0 + Double($1.count) * $1.weight }
        XCTAssertEqual(perSide, 527.5, accuracy: 1e-9)
    }

    func testResultIsHeaviestFirst() {
        let result = PlateCalculator.calculate(target: 200, bar: 20, unit: .kg)
        let weights = result.map(\.weight)
        XCTAssertEqual(weights, weights.sorted(by: >))
    }
}
