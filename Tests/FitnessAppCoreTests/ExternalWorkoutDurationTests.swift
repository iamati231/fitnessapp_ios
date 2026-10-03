import XCTest
@testable import FitnessAppCore

final class ExternalWorkoutDurationTests: XCTestCase {

    private let start = Date(timeIntervalSinceReferenceDate: 700_000_000)

    private func end(_ seconds: Double) -> Date {
        start.addingTimeInterval(seconds)
    }

    private func seconds(span: Double, active: TimeInterval?) -> Int {
        ExternalWorkoutDuration.seconds(start: start, end: end(span), activeSeconds: active)
    }

    // MARK: - seconds

    /// Ohne aktive Dauer zaehlt Beginn bis Ende, ABGERUNDET: 25:56,6 sind 25:56.
    func testWithoutAnActiveDurationTheSpanIsFlooredNotRounded() {
        XCTAssertEqual(seconds(span: 25 * 60 + 56.6, active: nil), 25 * 60 + 56)
    }

    /// 25:59,6 darf nicht in die naechste Minute kippen (26:00 = 26 Min).
    func testNeverRoundsUpIntoTheNextMinute() {
        let value = seconds(span: 25 * 60 + 59.6, active: nil)
        XCTAssertEqual(value, 25 * 60 + 59)
        XCTAssertEqual(value / 60, 25)
    }

    /// Lauf mit Pausen: Beginn bis Ende 30:00, aktive Zeit der Quelle 25:56,9 —
    /// die Laufzeit ist die aktive Zeit (abgerundet).
    func testTheActiveDurationIsTheRunTimeWhenPausesAreExcluded() {
        XCTAssertEqual(seconds(span: 30 * 60, active: 25 * 60 + 56.9), 25 * 60 + 56)
    }

    func testAnActiveDurationEqualToTheSpanChangesNothing() {
        XCTAssertEqual(seconds(span: 1800, active: 1800), 1800)
    }

    /// Die Quelle rundet auf ganze Sekunden: eine aktive Dauer knapp ueber Beginn
    /// bis Ende wird auf Beginn bis Ende begrenzt.
    func testAnActiveDurationSlightlyAboveTheSpanIsClampedToTheSpan() {
        XCTAssertEqual(seconds(span: 1800, active: 1800.5), 1800)
        XCTAssertEqual(seconds(span: 1800, active: 1801), 1800)
    }

    func testImplausibleActiveDurationsFallBackToTheSpan() {
        XCTAssertEqual(seconds(span: 1800, active: 5000), 1800, "laenger als Beginn bis Ende")
        XCTAssertEqual(seconds(span: 1800, active: 0), 1800)
        XCTAssertEqual(seconds(span: 1800, active: -5), 1800)
        XCTAssertEqual(seconds(span: 1800, active: .nan), 1800)
        XCTAssertEqual(seconds(span: 1800, active: .infinity), 1800)
    }

    func testEndBeforeStartIsZero() {
        XCTAssertEqual(seconds(span: -10, active: nil), 0)
        XCTAssertEqual(seconds(span: -10, active: 600), 0)
    }

    // MARK: - legacySeconds

    func testLegacySecondsRoundToTheNearestSecond() {
        XCTAssertEqual(ExternalWorkoutDuration.legacySeconds(start: start, end: end(1556.6)), 1557)
        XCTAssertEqual(ExternalWorkoutDuration.legacySeconds(start: start, end: end(1556.4)), 1556)
        XCTAssertEqual(ExternalWorkoutDuration.legacySeconds(start: start, end: end(-3)), 0)
    }

    // MARK: - correctedSeconds (bereits importierte Einheiten)

    private func corrected(
        storedSeconds: Int,
        storedMinutes: Int,
        span: Double,
        active: TimeInterval?
    ) -> Int? {
        ExternalWorkoutDuration.correctedSeconds(
            storedSeconds: storedSeconds, storedMinutes: storedMinutes,
            start: start, end: end(span), activeSeconds: active
        )
    }

    /// Frueher mit Pause importiert: 30:00 gespeichert, die aktive Zeit ist 25:56.
    func testAnUntouchedImportWithPausesGetsTheActiveTime() {
        XCTAssertEqual(
            corrected(storedSeconds: 1800, storedMinutes: 30, span: 1800, active: 25 * 60 + 56.9),
            25 * 60 + 56
        )
    }

    /// Nur die Rundung: Beginn bis Ende 25:59,6 waren frueher 26:00 (26 Min).
    func testAnUntouchedImportThatWasRoundedUpIsFloored() {
        XCTAssertEqual(
            corrected(storedSeconds: 1560, storedMinutes: 26, span: 25 * 60 + 59.6, active: nil),
            25 * 60 + 59
        )
    }

    /// Der Nutzer hat die Dauer im Verlauf von 30 auf 25 Min gestellt: bleibt.
    func testAnEditedDurationInMinutesIsLeftAlone() {
        XCTAssertNil(corrected(storedSeconds: 1800, storedMinutes: 25, span: 1800, active: 1556.9))
    }

    /// Die Laufzeit des Satzes wurde geaendert: bleibt.
    func testAnEditedRunTimeIsLeftAlone() {
        XCTAssertNil(corrected(storedSeconds: 1700, storedMinutes: 28, span: 1800, active: 1556.9))
    }

    func testNothingToDoWhenTheCorrectValueIsAlreadyStored() {
        XCTAssertNil(corrected(storedSeconds: 1800, storedMinutes: 30, span: 1800, active: nil))
        XCTAssertNil(corrected(storedSeconds: 1800, storedMinutes: 30, span: 1800, active: 1800))
    }

    /// Nach der Korrektur (25:56 statt 30:00) greift die Pruefung nicht mehr: Der
    /// naechste Sync aendert nichts mehr.
    func testACorrectedImportIsNotCorrectedAgain() {
        XCTAssertNil(corrected(storedSeconds: 1556, storedMinutes: 25, span: 1800, active: 1556.9))
    }
}
