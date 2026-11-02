import XCTest
@testable import FitnessAppCore

final class CardioExerciseZoneTests: XCTestCase {

    func testEasyRunMapsToEasy() {
        XCTAssertEqual(CardioExerciseZone.forExerciseName("Easy Run"), .easy)
    }

    func testTempoRunMapsToTempo() {
        XCTAssertEqual(CardioExerciseZone.forExerciseName("Tempo Run"), .tempo)
    }

    func testLongRunMapsToEasy() {
        // "Long Run" is used for genuine aerobic long runs in hybrid templates.
        // Old coach-generated plans that stored the tempo session as "Long Run"
        // now correctly get easy pace — semantically more appropriate than tempo.
        XCTAssertEqual(CardioExerciseZone.forExerciseName("Long Run"), .easy)
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
