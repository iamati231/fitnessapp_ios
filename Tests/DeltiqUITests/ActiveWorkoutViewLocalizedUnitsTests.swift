import XCTest

/// Audit-Fund (Modul 19, ActiveWorkoutView). `formatTotalDistance`,
/// `FinishWorkoutSheet.gearPickerSection` und `FinishWorkoutSheet.summarySection`
/// buken die Mengeneinheit ("kg"/"km") hartcodiert per String-Interpolation
/// ein, waehrend jede andere Stelle im selben Screen (z.B. `activeContextRow`)
/// die Einheit uebersetzbar aus dem Catalog zieht.
///
/// Kein ViewInspector/XCUITest-Harness vorhanden - folgt dem etablierten
/// Source-Inspection-Muster (siehe RootViewAppTourTimingTests).
final class ActiveWorkoutViewLocalizedUnitsTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/ActiveWorkoutView.swift"),
                encoding: .utf8
            )
        }
    }

    private func body(of signature: String, in text: String) throws -> Substring {
        guard let start = text.range(of: signature) else {
            XCTFail("\(signature) not found at the expected signature")
            return Substring("")
        }
        guard let end = text.range(of: "\n    }", range: start.upperBound..<text.endIndex) else {
            XCTFail("end of \(signature) not found")
            return Substring("")
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testFormatTotalDistanceUsesLocalizedUnit() throws {
        let text = try source
        let b = try body(of: "private func formatTotalDistance(stripUnit: Bool = false) -> String {", in: text)
        XCTAssertTrue(b.contains("active.finish.valueWithKm"),
                      "formatTotalDistance must localize its 'km' suffix via the catalog")
        XCTAssertFalse(b.contains("\"\\(valueStr) km\""),
                       "formatTotalDistance must not hardcode the 'km' unit inline anymore")
    }

    func testGearPickerSectionUsesLocalizedUnit() throws {
        let text = try source
        let b = try body(of: "private var gearPickerSection: some View {", in: text)
        XCTAssertTrue(b.contains("active.finish.valueWithKm"),
                      "gearPickerSection must localize its 'km' suffix via the catalog")
        XCTAssertFalse(b.contains(".formattedWholeOrTwoDecimals) km\")"),
                       "gearPickerSection must not hardcode the 'km' unit inline anymore")
    }

    func testSummarySectionUsesLocalizedUnit() throws {
        let text = try source
        let b = try body(of: "private var summarySection: some View {", in: text)
        let occurrences = b.components(separatedBy: "active.finish.valueWithKg").count - 1
        XCTAssertEqual(occurrences, 2,
                        "both volumeText branches (.mixed and .pureStrength) must localize the 'kg' suffix via the catalog")
        XCTAssertFalse(b.contains("\"\\(volumeText) kg\""),
                       "summarySection must not hardcode the 'kg' unit inline anymore")
    }

    func testCatalogHasNewUnitKeys() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/DeltiqUI/Resources/Localizable.xcstrings")
        let catalog = try String(contentsOf: catalogURL, encoding: .utf8)
        XCTAssertTrue(catalog.contains("\"active.finish.valueWithKg\""))
        XCTAssertTrue(catalog.contains("\"active.finish.valueWithKm\""))
    }
}
