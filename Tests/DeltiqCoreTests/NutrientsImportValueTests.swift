import XCTest
@testable import DeltiqCore

/// Bugfix (Audit, Modul 14): `NutrientsImport.value` parste einen negativen
/// Naehrwert (z.B. aus einem CSV-Import) erfolgreich und gab ihn als `.known`
/// zurueck — kein Lebensmittel hat negative kcal/Protein/Kohlenhydrate/Fett.
/// Muss wie ein unbekannter Wert behandelt werden (`.unknown`), nie als
/// falscher Negativwert, der ueber `GoalProgress` (NutritionCalculations.swift)
/// zu einer unbegrenzt negativen Prozentanzeige fuehrt. Spiegelt dasselbe Gate,
/// das `CustomFoodDraft.isValid` beim manuellen Anlegen schon erzwingt
/// (`CustomFoodEntrySheet.swift`: alle vier Pflicht-Makros muessen `>= 0` sein).
final class NutrientsImportValueTests: XCTestCase {
    private func row(_ value: String) throws -> CSVRow {
        let reader = try CSVReader("kcal_per_100g\r\n\(value)\r\n")
        return try XCTUnwrap(reader.rows().first)
    }

    func testNegativeValueIsTreatedAsUnknown() throws {
        let result = NutrientsImport.value(try row("-500"), key: "kcal_per_100g", bit: 1, mask: KnownValue.allKnownMask)
        XCTAssertNil(result.value, "negative Naehrwerte duerfen nicht als .known uebernommen werden")
        XCTAssertTrue(result.isUnknown)
    }

    func testZeroValueIsStillKnown() throws {
        let result = NutrientsImport.value(try row("0"), key: "kcal_per_100g", bit: 1, mask: KnownValue.allKnownMask)
        XCTAssertEqual(result.value, 0, "0 ist ein gueltiger Naehrwert (z.B. 0 kcal Wasser)")
    }

    func testPositiveValueIsKnown() throws {
        let result = NutrientsImport.value(try row("250"), key: "kcal_per_100g", bit: 1, mask: KnownValue.allKnownMask)
        XCTAssertEqual(result.value, 250)
    }

    func testBitNotSetInMaskStaysUnknownRegardlessOfSign() throws {
        let result = NutrientsImport.value(try row("250"), key: "kcal_per_100g", bit: 1, mask: 0)
        XCTAssertTrue(result.isUnknown, "unveraendertes Bestandsverhalten: Bit nicht gesetzt -> unknown")
    }
}
