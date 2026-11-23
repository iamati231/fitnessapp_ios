import XCTest

/// Modul-8-Audit (Workout-Ausfuehrung): `weightInput`'s `.onChange(of: weight)`
/// clampte bisher nur nach OBEN (500-kg-Cap gegen Vertipper/versehentliche
/// Riesenwerte) - ein eingetipptes oder eingefuegtes NEGATIVES Gewicht hatte
/// keine Absicherung. `canLog` gated nur `reps > 0`, nie das Gewicht; ein
/// negativer Wert floss ungeprueft in `totalVolumeKg`/e1RM/PR-History und
/// korrumpierte diese dauerhaft. Quelltext-Pruefung (kein Test-Seam fuer
/// echte SwiftUI-Texteingabe in diesem View), gleiches Muster wie
/// `SetRowWeightFieldScalesDownInsteadOfTruncatingTests`.
final class SetRowWeightLowerBoundClampTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent() // this file
                    .deletingLastPathComponent() // DeltiqUITests
                    .deletingLastPathComponent() // Tests
                    .appendingPathComponent("Sources/DeltiqUI/Workout/SetRow.swift"),
                encoding: .utf8
            )
        }
    }

    func testOnChangeOfWeightClampsNegativeValuesToZero() throws {
        let text = try source
        guard let onChangeStart = text.range(of: ".onChange(of: weight) { _, newValue in") else {
            return XCTFail("weightInput's .onChange(of: weight) not found at the expected signature")
        }
        guard let onChangeEnd = text.range(of: "\n            }", range: onChangeStart.upperBound..<text.endIndex) else {
            return XCTFail(".onChange(of: weight)'s end not found")
        }
        let body = text[onChangeStart.upperBound..<onChangeEnd.lowerBound]

        XCTAssertTrue(body.contains("w > PlateCalculator.maxTargetKg"),
                     "the existing upper-bound cap must still be present")
        XCTAssertTrue(body.contains("w < 0"),
                     "a lower-bound check for negative weight must be present")
        XCTAssertTrue(body.contains("weight = 0"),
                     "a negative weight must be clamped to 0, matching the upper-bound cap's clamp-not-reject style")
    }
}
