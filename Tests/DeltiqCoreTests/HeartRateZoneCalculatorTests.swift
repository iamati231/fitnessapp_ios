import XCTest
@testable import DeltiqCore

/// Running Coach - Herzfrequenz-Trainingszonen (Ticket-Testfaelle 1-7, 11).
final class HeartRateZoneCalculatorTests: XCTestCase {

    // MARK: - Testfall 1/4: gueltige HFmax -> korrekte 5 Zonen

    func testValidMaxHeartRateProducesFiveZonesWithExpectedBounds() {
        let zones = HeartRateZoneCalculator.zones(maxHeartRateBpm: 200)
        XCTAssertEqual(zones?.count, 5)
        // 200 ist durch alle Prozentschritte glatt teilbar - exakte,
        // unzweideutige Erwartungswerte.
        XCTAssertEqual(zones?[0], HeartRateZone(index: 1, lowerBoundBpm: 100, upperBoundBpm: 120))
        XCTAssertEqual(zones?[1], HeartRateZone(index: 2, lowerBoundBpm: 121, upperBoundBpm: 140))
        XCTAssertEqual(zones?[2], HeartRateZone(index: 3, lowerBoundBpm: 141, upperBoundBpm: 160))
        XCTAssertEqual(zones?[3], HeartRateZone(index: 4, lowerBoundBpm: 161, upperBoundBpm: 180))
        XCTAssertEqual(zones?[4], HeartRateZone(index: 5, lowerBoundBpm: 181, upperBoundBpm: 200))
    }

    // MARK: - Testfall 2: fehlende HFmax

    func testMissingMaxHeartRateReturnsNil() {
        XCTAssertNil(HeartRateZoneCalculator.zones(maxHeartRateBpm: nil))
    }

    // MARK: - Testfall 3: ungueltige/nicht plausible HFmax

    func testImplausiblyLowOrHighMaxHeartRateReturnsNil() {
        XCTAssertNil(HeartRateZoneCalculator.zones(maxHeartRateBpm: 30), "offensichtlicher Tippfehler, keine echte HFmax")
        XCTAssertNil(HeartRateZoneCalculator.zones(maxHeartRateBpm: 500))
        XCTAssertNil(HeartRateZoneCalculator.zones(maxHeartRateBpm: 0))
        XCTAssertNil(HeartRateZoneCalculator.zones(maxHeartRateBpm: -10))
    }

    func testPlausibilityBoundsAreInclusive() {
        XCTAssertTrue(HeartRateZoneCalculator.isPlausible(HeartRateZoneCalculator.minimumPlausibleMaxHeartRateBpm))
        XCTAssertTrue(HeartRateZoneCalculator.isPlausible(HeartRateZoneCalculator.maximumPlausibleMaxHeartRateBpm))
        XCTAssertFalse(HeartRateZoneCalculator.isPlausible(HeartRateZoneCalculator.minimumPlausibleMaxHeartRateBpm - 1))
        XCTAssertFalse(HeartRateZoneCalculator.isPlausible(HeartRateZoneCalculator.maximumPlausibleMaxHeartRateBpm + 1))
    }

    // MARK: - Testfall 5: keine Ueberlappungen oder Luecken

    func testZonesNeverOverlapOrLeaveAGapAcrossThePlausibleRange() {
        for maxHR in stride(from: HeartRateZoneCalculator.minimumPlausibleMaxHeartRateBpm,
                             through: HeartRateZoneCalculator.maximumPlausibleMaxHeartRateBpm, by: 1) {
            guard let zones = HeartRateZoneCalculator.zones(maxHeartRateBpm: maxHR) else {
                return XCTFail("jeder plausible Wert muss Zonen liefern (maxHR=\(maxHR))")
            }
            XCTAssertEqual(zones.map(\.index), [1, 2, 3, 4, 5])
            for i in 0..<(zones.count - 1) {
                XCTAssertEqual(zones[i + 1].lowerBoundBpm, zones[i].upperBoundBpm + 1,
                               "Zone \(zones[i + 1].index) muss nahtlos an Zone \(zones[i].index) anschliessen (maxHR=\(maxHR))")
            }
            for zone in zones {
                XCTAssertLessThanOrEqual(zone.lowerBoundBpm, zone.upperBoundBpm)
            }
            XCTAssertEqual(zones.last?.upperBoundBpm, maxHR, "Z5 muss exakt bei der HFmax enden")
        }
    }

    // MARK: - Testfall 6: Rundungsgrenzen

    func testRoundingIsConsistentAtAHalfBpmBoundary() {
        // 185 * 0.5 = 92.5 -> round-half-away-from-zero -> 93.
        let zones = try! XCTUnwrap(HeartRateZoneCalculator.zones(maxHeartRateBpm: 185))
        XCTAssertEqual(zones[0].lowerBoundBpm, 93)
        // 185 * 0.7 = 129.5 -> 130.
        XCTAssertEqual(zones[1].upperBoundBpm, 130)
        // 185 * 0.9 = 166.5 -> 167.
        XCTAssertEqual(zones[3].upperBoundBpm, 167)
    }

    // MARK: - Testfall 7: Aenderung der HFmax aktualisiert die Zonen

    func testChangingMaxHeartRateProducesDifferentZoneBounds() {
        let zonesA = try! XCTUnwrap(HeartRateZoneCalculator.zones(maxHeartRateBpm: 180))
        let zonesB = try! XCTUnwrap(HeartRateZoneCalculator.zones(maxHeartRateBpm: 200))
        XCTAssertNotEqual(zonesA, zonesB)
        XCTAssertEqual(zonesA.last?.upperBoundBpm, 180)
        XCTAssertEqual(zonesB.last?.upperBoundBpm, 200)
    }

    // MARK: - Messwert-Klassifikation (Teil 4)

    func testMeasuredBpmIsClassifiedIntoTheCorrectZone() {
        let zones = try! XCTUnwrap(HeartRateZoneCalculator.zones(maxHeartRateBpm: 200))
        XCTAssertEqual(HeartRateZoneCalculator.zone(forMeasuredBpm: 150, in: zones)?.index, 3)
        XCTAssertEqual(HeartRateZoneCalculator.zone(forMeasuredBpm: 100, in: zones)?.index, 1)
        XCTAssertEqual(HeartRateZoneCalculator.zone(forMeasuredBpm: 200, in: zones)?.index, 5)
    }

    func testMeasuredBpmOutsideAllZonesClassifiesAsNil() {
        let zones = try! XCTUnwrap(HeartRateZoneCalculator.zones(maxHeartRateBpm: 200))
        XCTAssertNil(HeartRateZoneCalculator.zone(forMeasuredBpm: 50, in: zones), "unterhalb Z1")
        XCTAssertNil(HeartRateZoneCalculator.zone(forMeasuredBpm: 210, in: zones), "oberhalb der HFmax")
    }

    // MARK: - Testfall 11: Profil-HFmax wird nie als gemessener Trainingspuls behandelt

    /// `HeartRateZoneContextBuilder.make` nimmt `maxHeartRateBpm` und
    /// `measuredAverageBpm` als ZWEI unabhaengige Parameter entgegen - ohne
    /// einen explizit uebergebenen Messwert gibt es strukturell keinen Weg,
    /// wie die HFmax selbst als "gemessen" im Ergebnis landen koennte.
    func testHeartRateZoneContextNeverTreatsMaxHeartRateAsAMeasuredValueWhenNoMeasurementIsGiven() {
        let state = HeartRateZoneContextBuilder.make(maxHeartRateBpm: 190, measuredAverageBpm: nil)
        guard case .zonesCalculatedNoMeasuredData(let maxHR, _) = state else {
            return XCTFail("erwartet .zonesCalculatedNoMeasuredData, erhalten \(state)")
        }
        XCTAssertEqual(maxHR, 190)
    }
}
