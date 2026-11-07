import XCTest
@testable import DeltiqCore

/// Running Coach - Herzfrequenz-Trainingszonen (Ticket-Testfaelle 8-10).
final class HeartRateZoneContextBuilderTests: XCTestCase {

    // MARK: - Testfall 8: keine Herzfrequenzmessungen vorhanden

    func testNoMeasuredDataWithValidMaxHeartRateYieldsZonesOnly() {
        let state = HeartRateZoneContextBuilder.make(maxHeartRateBpm: 190, measuredAverageBpm: nil)
        guard case .zonesCalculatedNoMeasuredData(let maxHR, let zones) = state else {
            return XCTFail("expected .zonesCalculatedNoMeasuredData, got \(state)")
        }
        XCTAssertEqual(maxHR, 190)
        XCTAssertEqual(zones.count, 5)
    }

    func testNeitherMaxHeartRateNorMeasuredDataYieldsNoMaxHeartRateConfigured() {
        XCTAssertEqual(
            HeartRateZoneContextBuilder.make(maxHeartRateBpm: nil, measuredAverageBpm: nil),
            .noMaxHeartRateConfigured
        )
    }

    /// Ein Messwert allein kann nie Zonen anzeigen - ohne HFmax gibt es
    /// nichts, wogegen er eingeordnet werden koennte.
    func testMeasuredDataWithoutMaxHeartRateStillYieldsNoMaxHeartRateConfigured() {
        XCTAssertEqual(
            HeartRateZoneContextBuilder.make(maxHeartRateBpm: nil, measuredAverageBpm: 150),
            .noMaxHeartRateConfigured
        )
    }

    // MARK: - Testfall 9: gueltige Trainingsmessungen vorhanden

    func testValidMeasuredDataIsClassifiedAgainstTheCalculatedZones() {
        let state = HeartRateZoneContextBuilder.make(maxHeartRateBpm: 200, measuredAverageBpm: 150)
        guard case .zonesCalculatedWithMeasuredData(let maxHR, let zones, let measured, let matchedZone) = state else {
            return XCTFail("expected .zonesCalculatedWithMeasuredData, got \(state)")
        }
        XCTAssertEqual(maxHR, 200)
        XCTAssertEqual(zones.count, 5)
        XCTAssertEqual(measured, 150)
        XCTAssertEqual(matchedZone?.index, 3)
    }

    // MARK: - Testfall 10: unvollstaendige/ungueltige Trainingsmessungen

    func testImplausibleMeasuredBpmIsTreatedAsNoMeasuredData() {
        // Ein Sensor-Artefakt (z.B. 400 bpm) darf nie als echter Messwert
        // in die Ausgabe durchgereicht werden - stattdessen wie "keine
        // Messdaten" behandelt, nicht crashen oder eine Fantasie-Zone zeigen.
        for implausible in [400, -5, 0] {
            let state = HeartRateZoneContextBuilder.make(maxHeartRateBpm: 190, measuredAverageBpm: implausible)
            guard case .zonesCalculatedNoMeasuredData(let maxHR, _) = state else {
                XCTFail("implausibler Messwert \(implausible) haette auf .zonesCalculatedNoMeasuredData fallen muessen, erhalten \(state)")
                continue
            }
            XCTAssertEqual(maxHR, 190)
        }
    }

    func testMeasuredBpmValidityBoundsAreInclusive() {
        XCTAssertTrue(HeartRateZoneContextBuilder.isValidMeasuredBpm(HeartRateZoneContextBuilder.minimumPlausibleMeasuredBpm))
        XCTAssertTrue(HeartRateZoneContextBuilder.isValidMeasuredBpm(HeartRateZoneContextBuilder.maximumPlausibleMeasuredBpm))
        XCTAssertFalse(HeartRateZoneContextBuilder.isValidMeasuredBpm(HeartRateZoneContextBuilder.minimumPlausibleMeasuredBpm - 1))
        XCTAssertFalse(HeartRateZoneContextBuilder.isValidMeasuredBpm(HeartRateZoneContextBuilder.maximumPlausibleMeasuredBpm + 1))
    }

    /// Ein gueltiger, aber ausserhalb aller 5 Zonen liegender Messwert (z.B.
    /// deutlich unter Z1) ist kein Fehler - `measuredZone` ist dann einfach
    /// `nil`, der Messwert selbst bleibt sichtbar.
    func testValidMeasuredBpmOutsideAllZonesKeepsTheMeasurementButNoMatchedZone() {
        let state = HeartRateZoneContextBuilder.make(maxHeartRateBpm: 200, measuredAverageBpm: 60)
        guard case .zonesCalculatedWithMeasuredData(_, _, let measured, let matchedZone) = state else {
            return XCTFail("expected .zonesCalculatedWithMeasuredData, got \(state)")
        }
        XCTAssertEqual(measured, 60)
        XCTAssertNil(matchedZone)
    }
}
