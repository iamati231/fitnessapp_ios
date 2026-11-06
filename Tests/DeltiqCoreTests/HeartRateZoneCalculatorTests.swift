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

    // MARK: - Verifikations-Nachfrage Punkt 1: jeder ganzzahlige bpm-Wert
    // innerhalb des Zonenbereichs gehoert zu GENAU einer Zone.

    func testEveryIntegerBpmWithinTheZoneRangeMatchesExactlyOneZone() {
        for maxHR in [100, 150, 185, 200, 220, 230] {
            let zones = try! XCTUnwrap(HeartRateZoneCalculator.zones(maxHeartRateBpm: maxHR))
            let lowest = zones.first!.lowerBoundBpm
            let highest = zones.last!.upperBoundBpm
            for bpm in lowest...highest {
                let matches = zones.filter { ($0.lowerBoundBpm...$0.upperBoundBpm).contains(bpm) }
                XCTAssertEqual(matches.count, 1,
                               "bpm=\(bpm) bei maxHR=\(maxHR) muss genau einer Zone zugeordnet sein, traf auf \(matches.count) zu")
            }
        }
    }

    // MARK: - Verifikations-Nachfrage Punkt 3: zentrale Plausibilitaet,
    // keine altersbasierte Schaetzung, keine automatische Ueberschreibung.

    /// Die Plausibilitaetsgrenzen sind EINMAL als Konstanten definiert und
    /// werden von `isPlausible`/`zones` ausschliesslich darueber gelesen -
    /// kein zweiter, abweichender Grenzwert irgendwo sonst im Typ.
    func testPlausibilityBoundsAreTheSingleSourceOfTruthForZoneGeneration() {
        XCTAssertNil(HeartRateZoneCalculator.zones(maxHeartRateBpm: HeartRateZoneCalculator.minimumPlausibleMaxHeartRateBpm - 1))
        XCTAssertNotNil(HeartRateZoneCalculator.zones(maxHeartRateBpm: HeartRateZoneCalculator.minimumPlausibleMaxHeartRateBpm))
        XCTAssertNotNil(HeartRateZoneCalculator.zones(maxHeartRateBpm: HeartRateZoneCalculator.maximumPlausibleMaxHeartRateBpm))
        XCTAssertNil(HeartRateZoneCalculator.zones(maxHeartRateBpm: HeartRateZoneCalculator.maximumPlausibleMaxHeartRateBpm + 1))
    }

    /// `zones(maxHeartRateBpm:)` nimmt NUR den einen expliziten Parameter
    /// entgegen - es gibt keinen Code-Pfad, der je Alter, Geburtsdatum oder
    /// einen anderen Profilwert zur Schaetzung heranzieht oder den
    /// eingegebenen Wert stillschweigend ersetzt. Strukturelle Pruefung per
    /// Quelltext-Scan, gleiches Prinzip wie `RaceProgressPhase1Structural-
    /// GuardTests`.
    func testCalculatorSourceNeverEstimatesFromAgeOrOverwritesTheManualValue() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // this file
            .deletingLastPathComponent() // DeltiqCoreTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/DeltiqCore/Analytics/HeartRateZoneCalculator.swift")
        let source = try String(contentsOf: path, encoding: .utf8)
        for forbidden in ["birthDate", "age ", "Age(", ".age", "220 -", "220-"] {
            XCTAssertFalse(source.contains(forbidden), "HeartRateZoneCalculator darf '\(forbidden)' nicht enthalten - keine altersbasierte HFmax-Schaetzung")
        }
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
