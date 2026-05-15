import XCTest
@testable import FitnessAppCore

/// Tests fuer DEL-058 Cardio-Pace-Berechnung + Input-Parser.
final class PaceCalculatorTests: XCTestCase {

    // MARK: - Pace-Berechnung

    /// 5 km in 25:00 → 5:00 /km.
    func testStandardPaceCalculation() {
        let pace = PaceCalculator.minutesPerKm(distanceKm: 5.0, durationSeconds: 25 * 60)
        XCTAssertEqual(pace ?? 0, 5.0, accuracy: 0.0001)
    }

    /// 10 km in 50:00 → 5:00 /km.
    func testLongerDistanceSamePace() {
        let pace = PaceCalculator.minutesPerKm(distanceKm: 10.0, durationSeconds: 50 * 60)
        XCTAssertEqual(pace ?? 0, 5.0, accuracy: 0.0001)
    }

    /// 5 km in 28:30 → 5,7 min/km → "5:42 /km".
    func testFormattingProducesMinSecPattern() {
        let pace = PaceCalculator.minutesPerKm(distanceKm: 5.0, durationSeconds: 28 * 60 + 30)
        let formatted = PaceCalculator.formatPace(pace)
        XCTAssertEqual(formatted, "5:42 /km")
    }

    /// Zero-Guard: 0 km → nil.
    func testZeroDistanceReturnsNil() {
        XCTAssertNil(PaceCalculator.minutesPerKm(distanceKm: 0, durationSeconds: 600))
    }

    /// Zero-Guard: 0 Sek → nil.
    func testZeroDurationReturnsNil() {
        XCTAssertNil(PaceCalculator.minutesPerKm(distanceKm: 5, durationSeconds: 0))
    }

    /// Nil-Pace formatiert zu Platzhalter, kein Crash.
    func testFormatNilProducesPlaceholder() {
        XCTAssertEqual(PaceCalculator.formatPace(nil), "—:—— /km")
    }

    /// Convenience-Variante akzeptiert Optionals.
    func testConvenienceWithOptionals() {
        XCTAssertEqual(
            PaceCalculator.pace(distanceKm: 5.0, durationSeconds: 25 * 60),
            "5:00 /km"
        )
        XCTAssertEqual(
            PaceCalculator.pace(distanceKm: nil, durationSeconds: 1500),
            "—:—— /km"
        )
        XCTAssertEqual(
            PaceCalculator.pace(distanceKm: 5.0, durationSeconds: nil),
            "—:—— /km"
        )
    }

    // MARK: - Duration-Parser

    /// "28:30" → 1710 Sekunden.
    func testParseMinutesSeconds() {
        XCTAssertEqual(PaceCalculator.parseDurationToSeconds("28:30"), 28 * 60 + 30)
    }

    /// "1:05:30" → 1*3600 + 5*60 + 30.
    func testParseHoursMinutesSeconds() {
        XCTAssertEqual(PaceCalculator.parseDurationToSeconds("1:05:30"), 3600 + 5 * 60 + 30)
    }

    /// "30" → 1800 (reine Minuten als Integer).
    func testParseIntegerMinutes() {
        XCTAssertEqual(PaceCalculator.parseDurationToSeconds("30"), 30 * 60)
    }

    /// "30.5" → 1830 (Dezimal-Minuten).
    func testParseDecimalMinutes() {
        XCTAssertEqual(PaceCalculator.parseDurationToSeconds("30.5"), 30 * 60 + 30)
    }

    /// "30,5" → 1830 (Komma-Variante = DE-Locale).
    func testParseGermanCommaDecimal() {
        XCTAssertEqual(PaceCalculator.parseDurationToSeconds("30,5"), 30 * 60 + 30)
    }

    /// Invalide Inputs liefern nil.
    func testParseInvalidReturnsNil() {
        XCTAssertNil(PaceCalculator.parseDurationToSeconds(""))
        XCTAssertNil(PaceCalculator.parseDurationToSeconds("abc"))
        XCTAssertNil(PaceCalculator.parseDurationToSeconds("0"))         // zero
        XCTAssertNil(PaceCalculator.parseDurationToSeconds("12:99"))     // 99 sek invalid
        XCTAssertNil(PaceCalculator.parseDurationToSeconds("1:2:99:0"))  // zu viele Teile
    }

    // MARK: - Distance-Parser

    func testParseDistanceDecimal() {
        XCTAssertEqual(PaceCalculator.parseDistanceToKm("5.5"), 5.5)
    }

    func testParseDistanceGermanComma() {
        XCTAssertEqual(PaceCalculator.parseDistanceToKm("5,5"), 5.5)
    }

    func testParseDistanceInteger() {
        XCTAssertEqual(PaceCalculator.parseDistanceToKm("10"), 10.0)
    }

    func testParseDistanceInvalidReturnsNil() {
        XCTAssertNil(PaceCalculator.parseDistanceToKm(""))
        XCTAssertNil(PaceCalculator.parseDistanceToKm("0"))
        XCTAssertNil(PaceCalculator.parseDistanceToKm("-5"))
        XCTAssertNil(PaceCalculator.parseDistanceToKm("nope"))
    }

    // MARK: - Duration-Formatter

    func testFormatDurationMinutesOnly() {
        XCTAssertEqual(PaceCalculator.formatDuration(28 * 60 + 30), "28:30")
    }

    func testFormatDurationWithHours() {
        XCTAssertEqual(PaceCalculator.formatDuration(3600 + 5 * 60 + 30), "1:05:30")
    }

    func testFormatDurationZeroProducesDash() {
        XCTAssertEqual(PaceCalculator.formatDuration(0), "—")
    }
}
