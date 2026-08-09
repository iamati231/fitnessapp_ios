import XCTest
@testable import FitnessAppCore

final class CardioBaselineCalculatorTests: XCTestCase {

    // MARK: - weeklyVolumeKm

    func testEmptyDistancesYieldsNil() {
        XCTAssertNil(CardioBaselineCalculator.weeklyVolumeKm(distancesKm: []))
    }

    func testWeeklyVolumeIsSumDividedByFourWeeks() {
        // 10 + 15 + 20 + 25 = 70 km ueber 4 Wochen -> 17.5 km/Woche.
        let result = CardioBaselineCalculator.weeklyVolumeKm(distancesKm: [10, 15, 20, 25])
        XCTAssertEqual(result, 17.5, accuracy: 0.0001)
    }

    func testWeeklyVolumeCountsEveryLoggedRunRegardlessOfLength() {
        // Anders als die Referenzpace hat das Wochenvolumen KEINEN
        // Mindest-Distanz-/Dauer-Filter - auch ein kurzer Erholungslauf zaehlt.
        let result = CardioBaselineCalculator.weeklyVolumeKm(distancesKm: [0.5, 1.0])
        XCTAssertEqual(result, 0.375, accuracy: 0.0001)
    }

    // MARK: - fastestReferenceSeconds

    func testEmptyRunsYieldsNil() {
        XCTAssertNil(CardioBaselineCalculator.fastestReferenceSeconds(from: []))
    }

    func testExactFiveKReferenceRunScalesToItself() {
        // 5 km in 25:00 (1500s) -> Pace 5.0 min/km -> Referenz fuer genau
        // 5 km ist wieder 1500s.
        let run = CardioBaselineCalculator.RunSample(distanceKm: 5.0, durationSeconds: 1500)
        XCTAssertEqual(CardioBaselineCalculator.fastestReferenceSeconds(from: [run]), 1500)
    }

    func testTenKRunScalesDownToFiveKEquivalent() {
        // 10 km in 45:00 (2700s) -> Pace 4.5 min/km -> 5-km-Aequivalent:
        // 4.5 * 5 * 60 = 1350s (22:30).
        let run = CardioBaselineCalculator.RunSample(distanceKm: 10.0, durationSeconds: 2700)
        XCTAssertEqual(CardioBaselineCalculator.fastestReferenceSeconds(from: [run]), 1350)
    }

    func testPicksTheFastestOfMultipleQualifyingRuns() {
        let slower = CardioBaselineCalculator.RunSample(distanceKm: 5.0, durationSeconds: 1500)  // 5.0 min/km
        let faster = CardioBaselineCalculator.RunSample(distanceKm: 10.0, durationSeconds: 2700) // 4.5 min/km
        XCTAssertEqual(
            CardioBaselineCalculator.fastestReferenceSeconds(from: [slower, faster]),
            1350,
            "der schnellere Lauf (niedrigere Pace) muss gewinnen, unabhaengig von der Reihenfolge der Eingabe"
        )
        XCTAssertEqual(
            CardioBaselineCalculator.fastestReferenceSeconds(from: [faster, slower]),
            1350
        )
    }

    func testRunBelowMinimumDistanceIsExcluded() {
        // 2.9 km - knapp unter der 3-km-Referenz-Schwelle, egal wie schnell.
        let tooShort = CardioBaselineCalculator.RunSample(distanceKm: 2.9, durationSeconds: 600)
        XCTAssertNil(CardioBaselineCalculator.fastestReferenceSeconds(from: [tooShort]))
    }

    func testRunBelowMinimumDurationIsExcludedEvenIfDistanceQualifies() {
        // 5 km, aber nur 299s (< 5 Min) - fehlgestartete Uhr/Dateneingabefehler.
        let tooFast = CardioBaselineCalculator.RunSample(distanceKm: 5.0, durationSeconds: 299)
        XCTAssertNil(CardioBaselineCalculator.fastestReferenceSeconds(from: [tooFast]))
    }

    func testExactBoundaryDistanceAndDurationQualify() {
        // Exakt 3.0 km und exakt 300s - >= zaehlt, nicht erst > .
        let boundary = CardioBaselineCalculator.RunSample(distanceKm: 3.0, durationSeconds: 300)
        XCTAssertNotNil(CardioBaselineCalculator.fastestReferenceSeconds(from: [boundary]))
    }

    func testNonQualifyingRunsAreIgnoredAmongMixedInput() {
        let tooShort = CardioBaselineCalculator.RunSample(distanceKm: 2.0, durationSeconds: 600)
        let qualifying = CardioBaselineCalculator.RunSample(distanceKm: 5.0, durationSeconds: 1500)
        XCTAssertEqual(
            CardioBaselineCalculator.fastestReferenceSeconds(from: [tooShort, qualifying]),
            1500
        )
    }
}
