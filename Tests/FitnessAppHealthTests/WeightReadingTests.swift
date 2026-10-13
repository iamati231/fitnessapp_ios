import XCTest
@testable import FitnessAppHealth

/// Fix "70,050003"-Bug: `WeightReading` ist der einzige Konstruktionsort
/// fuer HealthKit-Gewichtswerte im App-Modell — die Rundung muss HIER
/// greifen, damit jeder Konsument (Messung-Autofill, Onboarding-Snapshot)
/// automatisch einen sauberen Wert bekommt.
final class WeightReadingTests: XCTestCase {

    func testInitRoundsTheReportedFloatArtifact() {
        let reading = WeightReading(weightKg: 70.050003, date: Date(), sourceName: "Test")
        XCTAssertEqual(reading.weightKg, 70.05, accuracy: 1e-9)
    }

    func testInitRoundsUpWhenCloserToTheNextHundredth() {
        let reading = WeightReading(weightKg: 70.049999, date: Date(), sourceName: "Test")
        XCTAssertEqual(reading.weightKg, 70.05, accuracy: 1e-9)
    }

    func testInitLeavesAlreadyCleanValuesUnchanged() {
        XCTAssertEqual(WeightReading(weightKg: 70.0, date: Date(), sourceName: "Test").weightKg, 70.0, accuracy: 1e-9)
        XCTAssertEqual(WeightReading(weightKg: 70.5, date: Date(), sourceName: "Test").weightKg, 70.5, accuracy: 1e-9)
        XCTAssertEqual(WeightReading(weightKg: 70.05, date: Date(), sourceName: "Test").weightKg, 70.05, accuracy: 1e-9)
    }
}
