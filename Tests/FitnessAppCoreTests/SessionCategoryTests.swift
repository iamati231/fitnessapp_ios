import XCTest
@testable import FitnessAppCore

/// DEL-081: Tests fuer die Drei-State-Kategorisierung einer Workout-Session.
final class SessionCategoryTests: XCTestCase {

    func testPureStrengthSession() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: false, distanceKm: nil),
            (isCardio: false, distanceKm: nil),
            (isCardio: false, distanceKm: nil)
        ])
        XCTAssertEqual(category, .pureStrength)
    }

    func testPureCardioSession() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: true, distanceKm: 5.0)
        ])
        XCTAssertEqual(category, .pureCardio)
    }

    func testMixedSession() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: false, distanceKm: nil),    // Bench-Set
            (isCardio: false, distanceKm: nil),    // Bench-Set
            (isCardio: true,  distanceKm: 3.0)     // Run
        ])
        XCTAssertEqual(category, .mixed)
    }

    /// DEL-081: Cardio-Log ohne Distanz (z.B. User hat nur die Dauer
    /// eingetragen oder einen Lauf abgebrochen) zaehlt NICHT als "Cardio
    /// absolviert" — sonst kippt ein Plan-Mixed-State falsch zu .mixed.
    func testCardioWithoutDistanceCountsAsPureStrength() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: false, distanceKm: nil),
            (isCardio: true,  distanceKm: nil)
        ])
        XCTAssertEqual(category, .pureStrength)
    }

    /// Cardio-Log mit 0 km zaehlt ebenfalls nicht — `> 0`-Guard im evaluator.
    func testCardioWithZeroDistanceCountsAsPureStrength() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: false, distanceKm: nil),
            (isCardio: true,  distanceKm: 0.0)
        ])
        XCTAssertEqual(category, .pureStrength)
    }

    /// Empty-Logs → defensiv pureStrength (UI rendert sich dann nicht
    /// als "Lauf, aber leer").
    func testEmptyLogsReturnsPureStrength() {
        let category = SessionCategory.evaluate(logs: [])
        XCTAssertEqual(category, .pureStrength)
    }
}
