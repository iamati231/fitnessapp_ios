import XCTest
@testable import FitnessAppCore

final class CardioExerciseZoneTests: XCTestCase {

    func testEasyRunMapsToEasy() {
        XCTAssertEqual(CardioExerciseZone.forExerciseName("Easy Run"), .easy)
    }

    func testLongRunMapsToTempo() {
        XCTAssertEqual(CardioExerciseZone.forExerciseName("Long Run"), .tempo)
    }

    func testUnrelatedNameMapsToOther() {
        XCTAssertEqual(CardioExerciseZone.forExerciseName("Bank Press"), .other)
    }

    func testIntervalZoneNameMapsToOther() {
        // "Intervalle" is RunZone's own interval exercise name - it must NOT
        // get its own case, per the corrected brief (nothing downstream
        // needs to distinguish interval days from any other non-match here).
        XCTAssertEqual(CardioExerciseZone.forExerciseName("Intervalle"), .other)
    }
}
