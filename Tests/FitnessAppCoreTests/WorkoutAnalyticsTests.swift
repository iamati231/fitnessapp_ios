import XCTest
@testable import FitnessAppCore

final class WorkoutAnalyticsTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 0)

    private func lift(_ w: Double, _ r: Int, cardio: Bool = false, time: Bool = false) -> LiftAttempt {
        LiftAttempt(exerciseName: "Bankdruecken", weightKg: w, reps: r, date: now,
                    isCardio: cardio, isTimeBased: time)
    }

    // MARK: bestSet

    func testBestSetReturnsHighestVolume() {
        // 80×8=640, 100×3=300, 60×12=720 → highest is 60×12
        let attempts = [lift(80, 8), lift(100, 3), lift(60, 12)]
        let best = WorkoutAnalytics.bestSet(in: attempts)
        XCTAssertEqual(best?.weightKg, 60)
        XCTAssertEqual(best?.reps, 12)
    }

    func testBestSetReturnsNilForEmptyInput() {
        XCTAssertNil(WorkoutAnalytics.bestSet(in: []))
    }

    func testBestSetReturnsSingleAttempt() {
        let attempts = [lift(75, 5)]
        XCTAssertEqual(WorkoutAnalytics.bestSet(in: attempts)?.weightKg, 75)
    }

    // MARK: totalVolume

    func testTotalVolumeSumsAllAttempts() {
        let attempts = [lift(80, 8), lift(80, 6), lift(80, 4)]
        XCTAssertEqual(WorkoutAnalytics.totalVolume(in: attempts), 80 * 18, accuracy: 1e-9)
    }

    func testTotalVolumeEmptyIsZero() {
        XCTAssertEqual(WorkoutAnalytics.totalVolume(in: []), 0)
    }

    // MARK: liftSetCount

    func testLiftSetCountExcludesCardioAndTimeBased() {
        let attempts = [
            lift(80, 8),                       // counts
            lift(80, 6),                       // counts
            lift(0, 30, cardio: true),         // excluded — cardio
            lift(0, 60, time: true),           // excluded — isometric
            lift(0, 10)                        // excluded — weight zero (bodyweight)
        ]
        XCTAssertEqual(WorkoutAnalytics.liftSetCount(in: attempts), 2)
    }

    // MARK: LiftAttempt.volume

    func testLiftAttemptVolumeProperty() {
        XCTAssertEqual(lift(80, 8).volume, 640, accuracy: 1e-9)
        XCTAssertEqual(lift(0, 0).volume, 0, accuracy: 1e-9)
        XCTAssertEqual(lift(72.5, 5).volume, 362.5, accuracy: 1e-9)
    }
}
