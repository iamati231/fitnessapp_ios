import XCTest

/// Audit-Fund (Modul 19, Workout-UI). `PlatePopoverContent` bekam
/// `targetWeight`/`barWeight` immer in kg (SetRows kanonische
/// Speicher-Einheit), rechnete/zeigte sie aber direkt in der gewaehlten
/// Anzeige-Einheit (`unitRaw`, kann "lbs" sein) ohne Konvertierung —
/// `PlateCalculator.calculate(unit:)` erwartet target/bar aber bereits in
/// der Einheit von `unit`. Im lbs-Modus blieb der Zahlenwert kg, nur das
/// Label wechselte zu "lbs": falsche Scheiben-Aufladung, die eigene
/// Diskrepanz-Warnung schlug dabei nicht an (beide Zahlen blieben im selben
/// falschen Zahlenraum zueinander konsistent).
///
/// `PlatePopoverContent` ist `private` (dateiweit, auch via `@testable`
/// unsichtbar) — folgt daher dem etablierten Source-Inspection-Muster
/// (siehe `MealPlannerViewOptimizeFailureFeedbackTests`).
final class SetRowPlateCalculatorUnitTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqUI/Workout/SetRow.swift"),
                encoding: .utf8
            )
        }
    }

    private func platePopoverContentBody() throws -> Substring {
        let text = try source
        guard let start = text.range(of: "private struct PlatePopoverContent: View {") else {
            XCTFail("PlatePopoverContent not found at the expected declaration")
            return text[text.startIndex..<text.startIndex]
        }
        guard let end = text.range(of: "\n}", range: start.upperBound..<text.endIndex) else {
            XCTFail("end of PlatePopoverContent not found")
            return text[text.startIndex..<text.startIndex]
        }
        return text[start.upperBound..<end.lowerBound]
    }

    func testPopoverConvertsCanonicalKgToTheDisplayUnitBeforeCalculating() throws {
        let body = try platePopoverContentBody()

        XCTAssertTrue(body.contains("private var displayUnit: WeightUnit"),
                      "a WeightUnit-based kg->display-unit conversion must exist")
        XCTAssertTrue(body.contains("displayUnit.fromKg(targetWeight)"),
                      "targetWeight (canonical kg) must be converted to the display unit")
        XCTAssertTrue(body.contains("displayUnit.fromKg(effectiveBarWeight)"),
                      "effectiveBarWeight (canonical kg) must be converted to the display unit")

        XCTAssertTrue(
            body.contains("PlateCalculator.calculate(target: targetWeightDisplay, bar: effectiveBarWeightDisplay, unit: unit)"),
            "calculate(unit:) must receive values already converted to that same unit, not the raw kg values"
        )
        XCTAssertFalse(
            body.contains("PlateCalculator.calculate(target: targetWeight, bar: effectiveBarWeight, unit: unit)"),
            "must not regress to passing the raw canonical-kg values straight into calculate(unit:)"
        )
    }

    func testHeaderDisplaysTheConvertedTargetWeight() throws {
        let body = try platePopoverContentBody()
        XCTAssertTrue(body.contains("\\(targetWeightDisplay.formattedWholeOrTwoDecimals) \\(unit.rawValue)"),
                      "the header must show the target weight converted to the selected unit, not the raw kg value")
    }
}
