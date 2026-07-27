import XCTest
@testable import FitnessAppCore

/// DEL-222: Absicherung der Kilometer-Arithmetik. An diesen Zahlen haengt die
/// "Laufschuh wechseln"-Warnung — driftet der Stand, warnt die App zu frueh
/// oder nie.
final class GearDistanceTests: XCTestCase {

    // MARK: total(of:)

    func testTotalOfEmptyIsZero() {
        XCTAssertEqual(GearDistance.total(of: []), 0)
    }

    func testTotalIgnoresNilDistances() {
        // Kraft-Logs fuehren distanceKm == nil und duerfen nicht stoeren.
        XCTAssertEqual(GearDistance.total(of: [nil, 5.0, nil, 3.2]), 8.2, accuracy: 0.0001)
    }

    func testTotalOfAllNilIsZero() {
        XCTAssertEqual(GearDistance.total(of: [nil, nil, nil]), 0)
    }

    func testTotalIgnoresNegativeOutliers() {
        // Eine kaputte Zeile darf den Kilometerstand nicht nach unten faelschen.
        XCTAssertEqual(GearDistance.total(of: [10.0, -4.0, 2.0]), 12.0, accuracy: 0.0001)
    }

    func testTotalIgnoresZero() {
        XCTAssertEqual(GearDistance.total(of: [0.0, 5.0]), 5.0, accuracy: 0.0001)
    }

    func testTotalKeepsDecimalPrecision() {
        XCTAssertEqual(GearDistance.total(of: [5.25, 3.75]), 9.0, accuracy: 0.0001)
    }

    // MARK: booked(current:delta:)

    func testBookedAddsPositiveDelta() {
        XCTAssertEqual(GearDistance.booked(current: 100, delta: 8.5), 108.5, accuracy: 0.0001)
    }

    func testBookedSubtractsNegativeDelta() {
        XCTAssertEqual(GearDistance.booked(current: 100, delta: -8.5), 91.5, accuracy: 0.0001)
    }

    func testBookedClampsAtZero() {
        // Rueckbuchung groesser als der Stand (z.B. nach manueller Korrektur
        // des Kilometerstands) darf nicht negativ werden — `Gear.progress`
        // und die Austausch-Warnung waeren sonst unsinnig.
        XCTAssertEqual(GearDistance.booked(current: 5, delta: -20), 0)
    }

    func testBookedZeroDeltaIsIdentity() {
        XCTAssertEqual(GearDistance.booked(current: 42.5, delta: 0), 42.5, accuracy: 0.0001)
    }

    /// Buchen und exakt gegenbuchen muss zum Ausgangswert zurueckfuehren —
    /// das ist die Invariante, die den fuenf frueheren Handbuchungen gefehlt
    /// hat (jede mit eigenem Clamp).
    func testBookAndUnbookRoundTrips() {
        let start = 250.0
        let credited = GearDistance.booked(current: start, delta: 12.4)
        let reverted = GearDistance.booked(current: credited, delta: -12.4)
        XCTAssertEqual(reverted, start, accuracy: 0.0001)
    }
}
