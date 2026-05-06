import XCTest
@testable import FitnessAppCore

final class ExerciseCalculationsTests: XCTestCase {

    // MARK: Epley

    func testEpleyOneRepReturnsWeight() {
        XCTAssertEqual(ExerciseCalculations.estimate1RM(weightKg: 100, reps: 1)!, 100, accuracy: 1e-12)
    }

    func testEpleyFiveReps() {
        // 100 * (1 + 5/30) = 100 * 35/30 = 116.6666...
        XCTAssertEqual(ExerciseCalculations.estimate1RM(weightKg: 100, reps: 5)!,
                       100.0 * 35.0 / 30.0, accuracy: 1e-12)
    }

    func testEpleyOutOfRangeReturnsNil() {
        XCTAssertNil(ExerciseCalculations.estimate1RM(weightKg: 100, reps: 0))
        XCTAssertNil(ExerciseCalculations.estimate1RM(weightKg: 100, reps: 37))
        XCTAssertNil(ExerciseCalculations.estimate1RM(weightKg: 0, reps: 5))
        XCTAssertNil(ExerciseCalculations.estimate1RM(weightKg: -1, reps: 5))
    }

    // MARK: Brzycki

    func testBrzyckiFiveReps() {
        // 100 * 36 / (37 - 5) = 3600 / 32 = 112.5
        XCTAssertEqual(ExerciseCalculations.estimate1RMBrzycki(weightKg: 100, reps: 5)!,
                       112.5, accuracy: 1e-12)
    }

    func testBrzyckiOutOfRangeReturnsNil() {
        XCTAssertNil(ExerciseCalculations.estimate1RMBrzycki(weightKg: 100, reps: 0))
        XCTAssertNil(ExerciseCalculations.estimate1RMBrzycki(weightKg: 100, reps: 37))
    }

    // MARK: Average

    func testAverageOfBothFormulas() {
        let e = ExerciseCalculations.estimate1RM(weightKg: 100, reps: 5)!
        let b = ExerciseCalculations.estimate1RMBrzycki(weightKg: 100, reps: 5)!
        XCTAssertEqual(ExerciseCalculations.estimate1RMAverage(weightKg: 100, reps: 5)!,
                       (e + b) / 2.0, accuracy: 1e-12)
    }

    // MARK: suggestWeightForReps

    func testSuggestWeightForRepsRoundsDownToBarIncrement() {
        // 100 / (1 + 5/30) = 100 * 30/35 = 85.714... -> floor to 2.5 -> 85.0
        XCTAssertEqual(ExerciseCalculations.suggestWeightForReps(current1RM: 100, targetReps: 5),
                       85.0, accuracy: 1e-12)
    }

    func testSuggestWeightForRepsAtOneRepReturnsCurrent1RM() {
        // raw = current1RM, then floor to 2.5: 100 / 2.5 = 40, *2.5 = 100
        XCTAssertEqual(ExerciseCalculations.suggestWeightForReps(current1RM: 100, targetReps: 1),
                       100.0, accuracy: 1e-12)
    }

    func testSuggestWeightForRepsRespectsCustomIncrement() {
        // bar increment 5 kg: floor(85.714 / 5) * 5 = 17 * 5 = 85.0
        XCTAssertEqual(ExerciseCalculations.suggestWeightForReps(current1RM: 100, targetReps: 5, barIncrement: 5),
                       85.0, accuracy: 1e-12)
    }
}
