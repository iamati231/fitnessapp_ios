#if canImport(SwiftData)
import XCTest
@testable import FitnessAppData
import FitnessAppCore

/// Regression (Audit-Fund): `row.bool(key) ?? true` lief bei `is_active`,
/// `is_custom` und `smart_progression_enabled` nie auf den `?? true`-Zweig,
/// weil `CSVRow.bool()` eine fehlende/leere Spalte schon selbst als `false`
/// liest, nie als `nil`. Ein Backup aus der Zeit vor diesen Spalten importierte
/// dadurch still mit `false` statt dem beabsichtigten `true`. Fix: alle drei
/// Stellen nutzen jetzt `optionalSkippableBool`, das für eine fehlende Spalte
/// echtes `nil` liefert, sodass der `?? true`-Fallback tatsächlich greift.
final class DataImportLegacyColumnDefaultTests: XCTestCase {

    private func row(_ fields: [String: String]) -> CSVRow {
        CSVRow(lineNumber: 2, fields: fields)
    }

    func testMissingColumnFallsBackToIntendedDefault() {
        // Legacy-Zeile: die Spalte existiert ueberhaupt nicht im Header.
        let legacyRow = row(["name": "Testschuh"])
        XCTAssertEqual(DataImportService.optionalSkippableBool(legacyRow, "is_active") ?? true, true)
    }

    func testExplicitFalseIsStillRespected() {
        let presentRow = row(["name": "Testschuh", "is_active": "false"])
        XCTAssertEqual(DataImportService.optionalSkippableBool(presentRow, "is_active") ?? true, false)
    }

    /// Dokumentiert die Ursache des Bugs: der einfache `CSVRow.bool()`-Parser
    /// liest dieselbe fehlende Spalte als `false`, nicht `nil` — genau
    /// deshalb griff `row.bool("is_active") ?? true` nie.
    func testPlainBoolParserWouldHaveMaskedTheBug() {
        let legacyRow = row(["name": "Testschuh"])
        XCTAssertEqual(legacyRow.bool("is_active"), false)
    }
}
#endif
