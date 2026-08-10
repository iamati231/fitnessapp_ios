import XCTest
@testable import FitnessAppCore

final class PaceZoneCalculatorTests: XCTestCase {

    // 25:00 5k -> exakt 5.0 min/km Renn-Pace (glatte Zahl fuer die Tests).
    private let referenceSecondsFor25MinuteFiveK = 1_500

    func testRacePaceMatchesSimpleDivision() throws {
        let pace = try XCTUnwrap(PaceZoneCalculator.racePaceMinutesPerKm(fiveKReferenceSeconds: referenceSecondsFor25MinuteFiveK))
        XCTAssertEqual(pace, 5.0, accuracy: 0.0001)
    }

    func testEasyPaceIsThirtyPercentSlowerThanRacePace() throws {
        let pace = try XCTUnwrap(PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: referenceSecondsFor25MinuteFiveK))
        XCTAssertEqual(pace, 6.5, accuracy: 0.0001)
    }

    func testTempoPaceIsTenPercentSlowerThanRacePace() throws {
        let pace = try XCTUnwrap(PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: referenceSecondsFor25MinuteFiveK))
        XCTAssertEqual(pace, 5.5, accuracy: 0.0001)
    }

    func testEasyPaceIsSlowerThanTempoPace() {
        // Unabhaengig von der konkreten Referenzzeit: "locker" muss immer
        // langsamer sein als "Tempo" - sonst waeren die Zonen vertauscht.
        let easy = PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: 1_800)!
        let tempo = PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: 1_800)!
        XCTAssertGreaterThan(easy, tempo)
    }

    func testZeroReferenceSecondsYieldsNilForAllZones() {
        XCTAssertNil(PaceZoneCalculator.racePaceMinutesPerKm(fiveKReferenceSeconds: 0))
        XCTAssertNil(PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: 0))
        XCTAssertNil(PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: 0))
    }

    func testNegativeReferenceSecondsYieldsNilForAllZones() {
        XCTAssertNil(PaceZoneCalculator.racePaceMinutesPerKm(fiveKReferenceSeconds: -100))
        XCTAssertNil(PaceZoneCalculator.easyPaceMinutesPerKm(fiveKReferenceSeconds: -100))
        XCTAssertNil(PaceZoneCalculator.tempoPaceMinutesPerKm(fiveKReferenceSeconds: -100))
    }
}
