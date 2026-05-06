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

    // MARK: formattedTwoDecimals

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
}
