import XCTest
@testable import FitnessAppCore

/// DEL-221: Absicherung der Aggregat-Formel, die vorher an fuenf Stellen von
/// Hand stand. Auf diesen Zahlen sitzen Dashboard-Wochenvolumen,
/// Coach-Schwellen, DeloadAdvisor und Muskel-Heatmap — ein Fehler hier ist
/// still und verfaelscht jede Auswertung.
final class SessionAggregatorTests: XCTestCase {

    private func set(_ weight: Double, _ reps: Int) -> SessionAggregator.LoggedSet {
        SessionAggregator.LoggedSet(weightKg: weight, reps: reps)
    }

    // MARK: Grundfaelle

    func testEmptySessionHasZeroTotals() {
        let totals = SessionAggregator.totals(for: [])
        XCTAssertEqual(totals, .zero)
        XCTAssertEqual(totals.setCount, 0)
        XCTAssertEqual(totals.volumeKg, 0)
    }

    func testSingleSetVolumeIsWeightTimesReps() {
        let totals = SessionAggregator.totals(for: [set(80, 8)])
        XCTAssertEqual(totals.setCount, 1)
        XCTAssertEqual(totals.volumeKg, 640, accuracy: 0.0001)
    }

    func testVolumeSumsAcrossSets() {
        let totals = SessionAggregator.totals(for: [set(80, 8), set(85, 6), set(90, 4)])
        XCTAssertEqual(totals.setCount, 3)
        // 640 + 510 + 360
        XCTAssertEqual(totals.volumeKg, 1510, accuracy: 0.0001)
    }

    func testDecimalWeightsAccumulateWithoutRounding() {
        // 2,5-kg-Scheiben sind der Normalfall — der Aggregator darf hier NICHT
        // runden, das macht erst die Anzeige-Schicht (truncate, 2 Stellen).
        let totals = SessionAggregator.totals(for: [set(82.5, 5), set(87.5, 5)])
        XCTAssertEqual(totals.volumeKg, 850, accuracy: 0.0001)
    }

    // MARK: Bodyweight / Cardio

    func testBodyweightSetCountsButAddsNoVolume() {
        // Klimmzuege: weight == 0, aber sehr wohl ein Satz.
        let totals = SessionAggregator.totals(for: [set(0, 12), set(0, 10)])
        XCTAssertEqual(totals.setCount, 2)
        XCTAssertEqual(totals.volumeKg, 0)
    }

    func testCardioSetCountsButAddsNoVolume() {
        // Cardio-Logs tragen weight == 0 UND reps == 0; Distanz/Dauer leben in
        // eigenen Feldern und gehen nicht ins Kraft-Volumen ein.
        let totals = SessionAggregator.totals(for: [set(0, 0)])
        XCTAssertEqual(totals.setCount, 1)
        XCTAssertEqual(totals.volumeKg, 0)
    }

    func testMixedSessionCountsAllSetsButOnlyWeightedVolume() {
        let totals = SessionAggregator.totals(for: [
            set(100, 5),   // Kraft
            set(0, 15),    // Bodyweight
            set(0, 0),     // Cardio
        ])
        XCTAssertEqual(totals.setCount, 3)
        XCTAssertEqual(totals.volumeKg, 500, accuracy: 0.0001)
    }

    // MARK: Defensive Kanten

    func testNegativeWeightDoesNotReduceVolume() {
        // Ein Datenfehler soll das Wochenvolumen nicht nach unten ziehen.
        let totals = SessionAggregator.totals(for: [set(80, 8), set(-50, 5)])
        XCTAssertEqual(totals.setCount, 2, "der fehlerhafte Satz bleibt sichtbar")
        XCTAssertEqual(totals.volumeKg, 640, accuracy: 0.0001)
    }

    func testNegativeRepsDoNotReduceVolume() {
        let totals = SessionAggregator.totals(for: [set(80, 8), set(80, -3)])
        XCTAssertEqual(totals.setCount, 2)
        XCTAssertEqual(totals.volumeKg, 640, accuracy: 0.0001)
    }

    func testLargeSessionStaysExact() {
        // 100 identische Saetze — prueft, dass sich keine Akkumulations-
        // Ueberraschung einschleicht.
        let totals = SessionAggregator.totals(for: Array(repeating: set(100, 10), count: 100))
        XCTAssertEqual(totals.setCount, 100)
        XCTAssertEqual(totals.volumeKg, 100_000, accuracy: 0.0001)
    }

    func testTotalsAreValueComparable() {
        XCTAssertEqual(
            SessionAggregator.totals(for: [set(80, 8)]),
            SessionAggregator.Totals(setCount: 1, volumeKg: 640)
        )
    }
}
