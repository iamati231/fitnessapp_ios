import XCTest
@testable import FitnessAppCore

final class CardioRunProfileTests: XCTestCase {

    func testCardioRunProfileRoundTripsThroughJSON() throws {
        let profile = CardioRunProfile(goal: .tenK, current5kReferenceSeconds: 1500, weeklyBaseVolumeKm: 20)
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(CardioRunProfile.self, from: data)
        XCTAssertEqual(decoded, profile)
    }

    func testCardioRunProfileDecodesWithMissingOptionalFieldsFromOlderJSON() throws {
        let json = Data(#"{"goal":"fiveK"}"#.utf8)
        let decoded = try JSONDecoder().decode(CardioRunProfile.self, from: json)
        XCTAssertEqual(decoded.goal, .fiveK)
        XCTAssertNil(decoded.current5kReferenceSeconds)
        XCTAssertNil(decoded.weeklyBaseVolumeKm)
    }
}
