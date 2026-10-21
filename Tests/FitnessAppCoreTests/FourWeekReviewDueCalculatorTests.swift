import XCTest
@testable import FitnessAppCore

/// P7.3/P8 Stufe 3 — reine Fälligkeits-Logik des AKTUELL offenen Blocks.
/// Vergangene Abschlüsse sind seit P8 Stufe 3 NICHT mehr Teil dieses Typs
/// (siehe Typ-Dokumentation) — dafür ist `FourWeekReviewDueStatus.history`
/// (FitnessAppData) zuständig, dort auch die zugehörigen Tests.
final class FourWeekReviewDueCalculatorTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let reference = Date(timeIntervalSince1970: 1_700_000_000) // fixer Anker, unabhängig vom Testlauf-Datum

    func testNotYetDueBeforeTheIntervalElapses() {
        let blockStart = reference
        let now = calendar.date(byAdding: .day, value: 27, to: blockStart)!
        let state = FourWeekReviewDueCalculator.state(
            blockStart: blockStart,
            intervalDays: FourWeekReviewDueCalculator.dueIntervalDays,
            now: now,
            calendar: calendar
        )
        guard case .notYetDue(let dueAt) = state else {
            return XCTFail("Erwartet .notYetDue, bekommen \(state)")
        }
        XCTAssertEqual(dueAt, calendar.date(byAdding: .day, value: 28, to: blockStart))
    }

    func testExactlyDueWhenTheIntervalHasElapsed() {
        let blockStart = reference
        let now = calendar.date(byAdding: .day, value: 28, to: blockStart)!
        let state = FourWeekReviewDueCalculator.state(
            blockStart: blockStart,
            intervalDays: FourWeekReviewDueCalculator.dueIntervalDays,
            now: now,
            calendar: calendar
        )
        guard case .due(let since) = state else {
            return XCTFail("Erwartet .due, bekommen \(state)")
        }
        XCTAssertEqual(since, now)
    }

    func testOverdueStaysDue() {
        let blockStart = reference
        let now = calendar.date(byAdding: .day, value: 60, to: blockStart)!
        let state = FourWeekReviewDueCalculator.state(
            blockStart: blockStart,
            intervalDays: FourWeekReviewDueCalculator.dueIntervalDays,
            now: now,
            calendar: calendar
        )
        guard case .due = state else {
            return XCTFail("Erwartet .due, bekommen \(state)")
        }
    }

    /// P8 Stufe 3, ausdrückliche Produktregel: Folgeblöcke nutzen 42 statt
    /// 28 Tage. Dieser Test verlangt dieselbe Eingabe wie
    /// `testExactlyDueWhenTheIntervalHasElapsed`, aber erst 14 Tage später
    /// (42 statt 28) wird fällig — ein Aufrufer, der versehentlich weiterhin
    /// `dueIntervalDays` für einen Folgeblock nutzt, würde hier zu früh
    /// `.due` melden.
    func testSubsequentBlockUsesFortyTwoDaysNotTwentyEight() {
        let blockStart = reference
        let after28Days = calendar.date(byAdding: .day, value: 28, to: blockStart)!
        let notYetDueState = FourWeekReviewDueCalculator.state(
            blockStart: blockStart,
            intervalDays: FourWeekReviewDueCalculator.subsequentBlockIntervalDays,
            now: after28Days,
            calendar: calendar
        )
        guard case .notYetDue(let dueAt) = notYetDueState else {
            return XCTFail("Ein Folgeblock darf nach 28 Tagen noch nicht fällig sein, bekommen \(notYetDueState)")
        }
        XCTAssertEqual(dueAt, calendar.date(byAdding: .day, value: 42, to: blockStart))

        let after42Days = calendar.date(byAdding: .day, value: 42, to: blockStart)!
        let dueState = FourWeekReviewDueCalculator.state(
            blockStart: blockStart,
            intervalDays: FourWeekReviewDueCalculator.subsequentBlockIntervalDays,
            now: after42Days,
            calendar: calendar
        )
        guard case .due = dueState else {
            return XCTFail("Erwartet .due nach 42 Tagen, bekommen \(dueState)")
        }
    }

    func testUnknownWhenNoBlockStartExists() {
        let state = FourWeekReviewDueCalculator.state(
            blockStart: nil,
            intervalDays: FourWeekReviewDueCalculator.dueIntervalDays,
            now: reference,
            calendar: calendar
        )
        XCTAssertEqual(state, .unknown)
    }
}
