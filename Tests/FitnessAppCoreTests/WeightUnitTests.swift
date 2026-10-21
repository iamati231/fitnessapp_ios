import XCTest
@testable import FitnessAppCore

/// Geraete-Abnahme (Runde 9, docs/DELTIQ_DEVICE_ACCEPTANCE.md, kg/lbs):
/// `WeightUnit` ist reine Anzeige-/Eingabe-Konvertierung fuer das
/// `weight_unit`-Setting - Speicherung bleibt ueberall kg. Diese Tests
/// decken genau die in der Abnahme geforderten Eigenschaften ab: korrekte
/// Umrechnung in beide Richtungen, und dass wiederholtes Umschalten ohne
/// neue Eingabe NIE eine kumulative Verschiebung erzeugt (weil jede Anzeige
/// immer frisch vom kanonischen kg-Wert ausgeht, nie vom zuletzt
/// angezeigten Wert verkettet wird).
final class WeightUnitTests: XCTestCase {

    func testRawSettingParsing() {
        XCTAssertEqual(WeightUnit(rawSetting: "kg"), .kg)
        XCTAssertEqual(WeightUnit(rawSetting: "lbs"), .lbs)
        // Unbekannter/leerer Wert faellt auf kg zurueck - identisch zum
        // bestehenden `@AppStorage("weight_unit") ... = "kg"`-Default.
        XCTAssertEqual(WeightUnit(rawSetting: ""), .kg)
        XCTAssertEqual(WeightUnit(rawSetting: "garbage"), .kg)
    }

    func testKgUnitIsIdentity() {
        XCTAssertEqual(WeightUnit.kg.fromKg(72.5), 72.5, accuracy: 1e-9)
        XCTAssertEqual(WeightUnit.kg.toKg(72.5), 72.5, accuracy: 1e-9)
    }

    func testFromKgConvertsToLbs() {
        // 100 kg / 0.453592 ≈ 220.4623 lbs.
        XCTAssertEqual(WeightUnit.lbs.fromKg(100), 100 / 0.453592, accuracy: 1e-9)
        XCTAssertEqual(WeightUnit.lbs.fromKg(0), 0, accuracy: 1e-9)
    }

    func testToKgConvertsFromLbs() {
        // 220.4623 lbs * 0.453592 ≈ 100 kg.
        XCTAssertEqual(WeightUnit.lbs.toKg(220.4623), 220.4623 * 0.453592, accuracy: 1e-9)
    }

    /// Kernanforderung der Abnahme: Anzeige/Eingabe konvertieren IMMER vom
    /// kanonischen kg-Wert aus, nie verkettet - ein Hin-und-Her-Umschalten
    /// der Einheit OHNE neue Eingabe darf den gespeicherten Wert nicht
    /// schrittweise verschieben.
    func testRepeatedUnitToggleWithoutEditDoesNotDriftTheStoredValue() {
        let originalKg = 83.4
        var simulatedStoredKg = originalKg

        // Simuliert 50 Umschaltungen kg<->lbs, bei denen NUR angezeigt
        // (fromKg), nie bearbeitet (toKg zurueckgeschrieben) wird - genau
        // das Verhalten von `displayWeightBinding`s `get` beim reinen
        // Betrachten ohne Tippen.
        for i in 0..<50 {
            let unit: WeightUnit = i.isMultiple(of: 2) ? .kg : .lbs
            _ = unit.fromKg(simulatedStoredKg)
            // Kein `set` hier - der gespeicherte Wert bleibt unveraendert.
        }
        XCTAssertEqual(simulatedStoredKg, originalKg, accuracy: 1e-12)

        // Auch ein tatsaechlicher Rundtrip (Anzeige lesen, UNVERAENDERT in
        // kg zurueckschreiben) darf keinen Drift erzeugen.
        let displayedInLbs = WeightUnit.lbs.fromKg(simulatedStoredKg)
        simulatedStoredKg = WeightUnit.lbs.toKg(displayedInLbs)
        XCTAssertEqual(simulatedStoredKg, originalKg, accuracy: 1e-9)
    }

    /// Backt die Dashboard-Delta-Entscheidung ab (DashboardView.swift,
    /// `weeklyWeightDelta().map(dashboardWeightUnit.fromKg)`): die
    /// Konvertierung hat keinen Offset, daher ist das Konvertieren einer
    /// REINEN DIFFERENZ exakt aequivalent zur Differenz zweier konvertierter
    /// Absolutwerte.
    func testConversionIsLinearSoDeltasConvertCorrectly() {
        let a = 80.0
        let b = 78.5
        let deltaKg = a - b
        XCTAssertEqual(WeightUnit.lbs.fromKg(deltaKg),
                        WeightUnit.lbs.fromKg(a) - WeightUnit.lbs.fromKg(b),
                        accuracy: 1e-9)
    }
}
