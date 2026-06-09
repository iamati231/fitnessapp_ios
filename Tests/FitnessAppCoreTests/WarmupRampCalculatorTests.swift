import XCTest
@testable import FitnessAppCore

final class WarmupRampCalculatorTests: XCTestCase {

    // MARK: Edge cases

    func testEmptyWhenWorkingWeightAtBar() {
        XCTAssertEqual(WarmupRampCalculator.ramp(workingWeightKg: 20), [])
    }

    func testEmptyWhenWorkingWeightBarelyAboveBar() {
        // 22.5 = Stange + 1 Increment → keine sinnvolle Rampe
        XCTAssertEqual(WarmupRampCalculator.ramp(workingWeightKg: 22.5), [])
    }

    // MARK: Standard ramps

    func testModerateWeightSixtyKg() {
        // 60 kg: Bar ×10, 55% = 33 → 32.5 ×5, 75% = 45 ×3. Kein 90% (< 100 kg).
        let ramp = WarmupRampCalculator.ramp(workingWeightKg: 60)
        XCTAssertEqual(ramp, [
            WarmupStep(weightKg: 20, reps: 10, isBarOnly: true),
            WarmupStep(weightKg: 32.5, reps: 5),
            WarmupStep(weightKg: 45, reps: 3),
        ])
    }

    func testHeavyWeightGetsNinetyPercentSingle() {
        // 140 kg: Bar, 77 → 77.5 ×5, 105 ×3, 126 → 125 ×1.
        let ramp = WarmupRampCalculator.ramp(workingWeightKg: 140)
        XCTAssertEqual(ramp, [
            WarmupStep(weightKg: 20, reps: 10, isBarOnly: true),
            WarmupStep(weightKg: 77.5, reps: 5),
            WarmupStep(weightKg: 105, reps: 3),
            WarmupStep(weightKg: 125, reps: 1),
        ])
    }

    func testJustBelowHeavyThresholdHasNoSingle() {
        let ramp = WarmupRampCalculator.ramp(workingWeightKg: 99)
        XCTAssertFalse(ramp.contains { $0.reps == 1 })
    }

    func testLightWeightSkipsStagesBelowBar() {
        // 30 kg: 55% = 16.5 → unter Stange → skip. 75% = 22.5 → 22.5 ≤ 30-2.5 ✓
        let ramp = WarmupRampCalculator.ramp(workingWeightKg: 30)
        XCTAssertEqual(ramp, [
            WarmupStep(weightKg: 20, reps: 10, isBarOnly: true),
            WarmupStep(weightKg: 22.5, reps: 3),
        ])
    }

    func testStepsNeverReachWorkingWeight() {
        for weight in stride(from: 25.0, through: 250.0, by: 5.0) {
            let ramp = WarmupRampCalculator.ramp(workingWeightKg: weight)
            for step in ramp where !step.isBarOnly {
                XCTAssertLessThanOrEqual(
                    step.weightKg, weight - 2.5,
                    "Step \(step.weightKg) too close to working \(weight)"
                )
            }
        }
    }

    func testStepsAreStrictlyAscending() {
        let ramp = WarmupRampCalculator.ramp(workingWeightKg: 180)
        let weights = ramp.map(\.weightKg)
        XCTAssertEqual(weights, weights.sorted())
        XCTAssertEqual(Set(weights).count, weights.count, "no duplicate steps")
    }

    func testAllStepsPlateRounded() {
        let ramp = WarmupRampCalculator.ramp(workingWeightKg: 117.5)
        for step in ramp {
            let remainder = step.weightKg.truncatingRemainder(dividingBy: 2.5)
            XCTAssertEqual(remainder, 0, accuracy: 0.001)
        }
    }

    func testCustomBarWeight() {
        // 30-kg-Bar (Heavy-Duty): Schritte unter 30 kg fliegen raus.
        let ramp = WarmupRampCalculator.ramp(workingWeightKg: 60, barWeightKg: 30)
        XCTAssertEqual(ramp.first, WarmupStep(weightKg: 30, reps: 10, isBarOnly: true))
        XCTAssertTrue(ramp.dropFirst().allSatisfy { $0.weightKg > 30 })
    }
}
