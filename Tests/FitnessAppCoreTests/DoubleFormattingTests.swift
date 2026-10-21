import XCTest
@testable import FitnessAppCore

final class DoubleFormattingTests: XCTestCase {

    // MARK: truncated(to:)

    func testTruncatedToTwoDecimalsFloors() {
        // The whole point of truncated(to:) is that it floors — 15.86789 must NOT round up.
        XCTAssertEqual((15.86789).truncated(to: 2), 15.86, accuracy: 1e-12)
        XCTAssertEqual((15.86999).truncated(to: 2), 15.86, accuracy: 1e-12)
    }

    func testTruncatedKeepsTrailingZeros() {
        XCTAssertEqual((80.0).truncated(to: 2), 80.0, accuracy: 1e-12)
        XCTAssertEqual((80.005).truncated(to: 2), 80.00, accuracy: 1e-12)
    }

    func testTruncatedToZeroDecimals() {
        XCTAssertEqual((15.86).truncated(to: 0), 15.0, accuracy: 1e-12)
        XCTAssertEqual((15.99).truncated(to: 0), 15.0, accuracy: 1e-12)
    }

    func testTruncatedToOneDecimal() {
        XCTAssertEqual((15.86).truncated(to: 1), 15.8, accuracy: 1e-12)
    }

    /// Bugfix (Audit): flooring a negative value grows its MAGNITUDE
    /// (-2.34 -> -2.4), which overstates rather than avoids overstating -
    /// the opposite of this function's purpose. Must round toward zero.
    func testTruncatedRoundsNegativeValuesTowardZeroNotAwayFromIt() {
        XCTAssertEqual((-2.34).truncated(to: 1), -2.3, accuracy: 1e-12)
        XCTAssertEqual((-0.3).truncated(to: 0), 0.0, accuracy: 1e-12)
    }

    /// Bugfix (Zehntelwerte): `64.1 * 100` ergibt in Gleitkomma 6409.999999999999
    /// und wurde frueher zu 64.09 abgeschnitten, obwohl genau 64.1 gemeint ist.
    func testTruncatedKeepsDecimalValuesThatAreInexactInBinary() {
        XCTAssertEqual((64.1).truncated(to: 2), 64.1, accuracy: 1e-12)
        XCTAssertEqual((64.6).truncated(to: 2), 64.6, accuracy: 1e-12)
        XCTAssertEqual((65.1).truncated(to: 2), 65.1, accuracy: 1e-12)
    }

    func testTruncatedIsExactForEveryTenthInTheBodyWeightRange() {
        for tenths in 500...1500 {
            let value = Double(tenths) / 10.0
            XCTAssertEqual(value.truncated(to: 2), value, accuracy: 1e-9, "\(value)")
        }
    }

    func testTruncatedIsExactForEveryHundredthInTheTypicalRange() {
        for hundredths in 0...30_000 {
            let value = Double(hundredths) / 100.0
            XCTAssertEqual(value.truncated(to: 2), value, accuracy: 1e-9, "\(value)")
        }
    }

    /// Die Korrektur darf nur Rundungsrauschen heilen: echte Ueberschuss-
    /// Stellen werden weiterhin abgeschnitten, nie aufgerundet.
    func testTruncatedStillCutsRealExcessDigits() {
        XCTAssertEqual((15.869).truncated(to: 2), 15.86, accuracy: 1e-12)
        XCTAssertEqual((99.999).truncated(to: 2), 99.99, accuracy: 1e-12)
        XCTAssertEqual((0.999).truncated(to: 2), 0.99, accuracy: 1e-12)
        XCTAssertEqual((-1.999).truncated(to: 2), -1.99, accuracy: 1e-12)
        XCTAssertEqual((2.675).truncated(to: 2), 2.67, accuracy: 1e-12)
        // Zehn Nachkommastellen mit Neunerkette sind KEIN Rundungsrauschen.
        XCTAssertEqual((15.8599999999).truncated(to: 2), 15.85, accuracy: 1e-12)
    }

    /// Berechnete Werte mit Rundungsrauschen (0.7 + 0.1 = 0.7999999999999999)
    /// duerfen nicht um eine ganze letzte Stelle zu klein angezeigt werden.
    func testTruncatedHealsFloatingPointNoiseFromArithmetic() {
        XCTAssertEqual((0.7 + 0.1).truncated(to: 1), 0.8, accuracy: 1e-12)
        XCTAssertEqual((4.35 * 100.0).truncated(to: 0), 435.0, accuracy: 1e-12)
    }

    func testTruncatedHandlesNonFiniteValuesWithoutTrapping() {
        XCTAssertTrue(Double.infinity.truncated(to: 2).isInfinite)
        XCTAssertTrue(Double.nan.truncated(to: 2).isNaN)
    }

    // MARK: rounded(toDecimals:) — Fix "70,050003"-Bug

    /// Anders als `truncated(to:)` rundet dies ECHT zur naechsten Stelle,
    /// nicht Richtung Null.
    func testRoundedToDecimalsRoundsUpWhenCloserToTheNextValue() {
        XCTAssertEqual((70.049999).rounded(toDecimals: 2), 70.05, accuracy: 1e-9)
        XCTAssertEqual((15.866).rounded(toDecimals: 2), 15.87, accuracy: 1e-9)
    }

    func testRoundedToDecimalsRoundsDownWhenCloserToThePreviousValue() {
        XCTAssertEqual((70.041).rounded(toDecimals: 2), 70.04, accuracy: 1e-9)
    }

    func testRoundedToDecimalsHealsTheReportedFloatArtifact() {
        // Der gemeldete Bug: ein Health-Gewicht kommt als 70.050003 statt 70.05 an.
        XCTAssertEqual((70.050003).rounded(toDecimals: 2), 70.05, accuracy: 1e-9)
    }

    func testRoundedToDecimalsKeepsWholeAndOneDecimalValuesUnchanged() {
        XCTAssertEqual((70.0).rounded(toDecimals: 2), 70.0, accuracy: 1e-9)
        XCTAssertEqual((70.5).rounded(toDecimals: 2), 70.5, accuracy: 1e-9)
    }

    // MARK: formattedWeightInput — Fix "70,050003"-Bug

    private let de = Locale(identifier: "de_DE")
    private let en = Locale(identifier: "en_US")

    /// Die vier vom Bugfix geforderten Faelle, je einmal pro Locale.
    func testFormattedWeightInputMatchesTheRequiredCasesInGerman() {
        XCTAssertEqual((70.05).formattedWeightInput(locale: de), "70,05")
        XCTAssertEqual((70.0).formattedWeightInput(locale: de), "70")
        XCTAssertEqual((70.5).formattedWeightInput(locale: de), "70,5")
        // Float-Roundtrip-Artefakt: rundet weiterhin korrekt auf 70,05, nicht 70,04.
        XCTAssertEqual((70.049999).formattedWeightInput(locale: de), "70,05")
    }

    func testFormattedWeightInputMatchesTheRequiredCasesInEnglish() {
        XCTAssertEqual((70.05).formattedWeightInput(locale: en), "70.05")
        XCTAssertEqual((70.0).formattedWeightInput(locale: en), "70")
        XCTAssertEqual((70.5).formattedWeightInput(locale: en), "70.5")
        XCTAssertEqual((70.049999).formattedWeightInput(locale: en), "70.05")
    }

    /// Der urspruenglich gemeldete Bug, woertlich: 70,050003 -> 70,05.
    func testFormattedWeightInputHealsTheReportedHealthKitArtifact() {
        XCTAssertEqual((70.050003).formattedWeightInput(locale: de), "70,05")
        XCTAssertEqual((70.050003).formattedWeightInput(locale: en), "70.05")
    }

    /// Nie mehr als 2 Nachkommastellen, auch bei staerkerem Praezisions-Rauschen.
    func testFormattedWeightInputNeverShowsMoreThanTwoDecimals() {
        XCTAssertEqual((70.199999).formattedWeightInput(locale: en), "70.2")
        XCTAssertEqual((99.995).formattedWeightInput(locale: en), "100")
    }

    // MARK: formattedTwoDecimals

    func testEnteredTenthIsDisplayedUnchangedAfterTruncateAndFormat() {
        let s = (64.1).truncated(to: 2).formattedTwoDecimals
        XCTAssertTrue(s == "64.10" || s == "64,10", "got \(s)")
    }

    func testFormattedTwoDecimalsForcesTrailingZeros() {
        // Locale-dependent separator — accept either dot or comma.
        let s = (80.0).formattedTwoDecimals
        XCTAssertTrue(s == "80.00" || s == "80,00", "got \(s)")
    }

    func testTruncateBeforeFormatPreventsCosmeticRoundUp() {
        // 15.866 with raw %.2f formatting would render "15.87" (printf rounds).
        // Truncation must happen BEFORE formatting to keep the floor semantics.
        let truncatedFirst = (15.866).truncated(to: 2).formattedTwoDecimals
        XCTAssertTrue(truncatedFirst == "15.86" || truncatedFirst == "15,86",
                      "got \(truncatedFirst) — truncation didn't floor before format")
    }

    // MARK: formattedOneDecimal / formattedNoDecimals / formatted(decimals:)

    func testFormattedOneDecimal() {
        let s = (70.36).truncated(to: 1).formattedOneDecimal
        XCTAssertTrue(s == "70.3" || s == "70,3", "got \(s)")
    }

    func testFormattedNoDecimalsHasNoFraction() {
        let s = (1250.0).formattedNoDecimals
        XCTAssertEqual(s, "1250")
    }

    func testFormattedDecimalsMatchesNamedVariants() {
        XCTAssertEqual((42.0).formatted(decimals: 0), (42.0).formattedNoDecimals)
        XCTAssertEqual((42.5).formatted(decimals: 1), (42.5).formattedOneDecimal)
        XCTAssertEqual((42.5).formatted(decimals: 2), (42.5).formattedTwoDecimals)
    }

    // MARK: Float.formattedRIR

    func testFormattedRIRWholeNumberHasNoFraction() {
        XCTAssertEqual(Float(2).formattedRIR, "2")
    }

    func testFormattedRIRIsLocaleAware() {
        // Regression: the old `String(format: "%.1f", rir)` had no locale and
        // always rendered a dot, even next to a comma-formatted weight.
        let s = Float(2.5).formattedRIR
        XCTAssertTrue(s == "2.5" || s == "2,5", "got \(s)")
    }

    /// Bugfix (Audit): `Int(value)` traps for non-finite/too-large values.
    /// `.infinity.rounded() == .infinity` is true, so without a guard this
    /// took the `Int(value)` branch and crashed.
    func testFormattedRIRDoesNotCrashOnNonFiniteValues() {
        XCTAssertFalse(Float.infinity.formattedRIR.isEmpty)
        XCTAssertFalse(Float.nan.formattedRIR.isEmpty)
        XCTAssertFalse(Float(1e30).formattedRIR.isEmpty)
    }
}
