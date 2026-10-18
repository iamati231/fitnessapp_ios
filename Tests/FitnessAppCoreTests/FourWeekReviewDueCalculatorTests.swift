import XCTest
@testable import FitnessAppCore

/// P7.3 — reine Fälligkeits-/Abschluss-Logik. Deckt die vom Nutzer
/// ausdrücklich festgelegten Grenzfälle ab: vor Fälligkeit, genau fällig,
/// überfällig, abgeschlossen, fehlender Zeitanker (`.unknown`, kein
/// erfundenes Datum) — kein Snooze in dieser Stufe (ausdrückliche
/// Produktentscheidung, siehe Typ-Dokumentation).
final class FourWeekReviewDueCalculatorTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let reference = Date(timeIntervalSince1970: 1_700_000_000) // fixer Anker, unabhängig vom Testlauf-Datum

    func testNotYetDueBeforeTheTwentyEighthDay() {
        let activatedAt = reference
        let now = calendar.date(byAdding: .day, value: 27, to: activatedAt)!
        let state = FourWeekReviewDueCalculator.state(
            activatedAt: activatedAt,
            reviewObservationStartedAt: nil,
            reviewCompletedAt: nil,
            reviewDecision: nil,
            now: now,
            calendar: calendar
        )
        guard case .notYetDue(let dueAt) = state else {
            return XCTFail("Erwartet .notYetDue, bekommen \(state)")
        }
        XCTAssertEqual(dueAt, calendar.date(byAdding: .day, value: 28, to: activatedAt))
    }

    func testExactlyDueOnTheTwentyEighthDay() {
        let activatedAt = reference
        let now = calendar.date(byAdding: .day, value: 28, to: activatedAt)!
        let state = FourWeekReviewDueCalculator.state(
            activatedAt: activatedAt,
            reviewObservationStartedAt: nil,
            reviewCompletedAt: nil,
            reviewDecision: nil,
            now: now,
            calendar: calendar
        )
        guard case .due(let since) = state else {
            return XCTFail("Erwartet .due, bekommen \(state)")
        }
        XCTAssertEqual(since, now)
    }

    func testOverdueStaysDue() {
        let activatedAt = reference
        let now = calendar.date(byAdding: .day, value: 60, to: activatedAt)!
        let state = FourWeekReviewDueCalculator.state(
            activatedAt: activatedAt,
            reviewObservationStartedAt: nil,
            reviewCompletedAt: nil,
            reviewDecision: nil,
            now: now,
            calendar: calendar
        )
        guard case .due = state else {
            return XCTFail("Erwartet .due, bekommen \(state)")
        }
    }

    func testCompletedTakesPrecedenceOverDueRegardlessOfElapsedTime() {
        let activatedAt = reference
        let completedAt = calendar.date(byAdding: .day, value: 10, to: activatedAt)!
        let farInTheFuture = calendar.date(byAdding: .day, value: 365, to: activatedAt)!
        let state = FourWeekReviewDueCalculator.state(
            activatedAt: activatedAt,
            reviewObservationStartedAt: nil,
            reviewCompletedAt: completedAt,
            reviewDecision: .keptAsIs,
            now: farInTheFuture,
            calendar: calendar
        )
        XCTAssertEqual(state, .completed(at: completedAt, decision: .keptAsIs))
    }

    func testActionTakenDecisionIsPreservedOnCompletion() {
        let state = FourWeekReviewDueCalculator.state(
            activatedAt: reference,
            reviewObservationStartedAt: nil,
            reviewCompletedAt: reference,
            reviewDecision: .actionTaken,
            now: reference,
            calendar: calendar
        )
        XCTAssertEqual(state, .completed(at: reference, decision: .actionTaken))
    }

    func testUnknownWhenNeitherActivationNorObservationAnchorExists() {
        let state = FourWeekReviewDueCalculator.state(
            activatedAt: nil,
            reviewObservationStartedAt: nil,
            reviewCompletedAt: nil,
            reviewDecision: nil,
            now: reference,
            calendar: calendar
        )
        XCTAssertEqual(state, .unknown)
    }

    /// Fallback-Anker greift NUR, wenn `activatedAt` fehlt — kein erfundenes
    /// historisches Datum, sondern der tatsächliche, separat gespeicherte
    /// Beobachtungsbeginn (siehe `TrainingPlan.reviewObservationStartedAt`).
    func testObservationAnchorIsUsedOnlyWhenActivatedAtIsMissing() {
        let observationStart = reference
        let now = calendar.date(byAdding: .day, value: 28, to: observationStart)!
        let state = FourWeekReviewDueCalculator.state(
            activatedAt: nil,
            reviewObservationStartedAt: observationStart,
            reviewCompletedAt: nil,
            reviewDecision: nil,
            now: now,
            calendar: calendar
        )
        guard case .due(let since) = state else {
            return XCTFail("Erwartet .due über den Beobachtungs-Fallback, bekommen \(state)")
        }
        XCTAssertEqual(since, now)
    }

    /// `activatedAt` gewinnt immer gegen den Beobachtungs-Fallback, falls
    /// ausnahmsweise beide gesetzt sind (sollte in der Praxis nicht
    /// vorkommen — `FourWeekReviewDueStatus` setzt den Fallback nur, wenn
    /// `activatedAt` fehlt — aber die Priorität bleibt explizit testbar).
    func testActivatedAtTakesPriorityOverObservationAnchor() {
        let activatedAt = reference
        let laterObservationStart = calendar.date(byAdding: .day, value: 100, to: reference)!
        let now = calendar.date(byAdding: .day, value: 28, to: activatedAt)!
        let state = FourWeekReviewDueCalculator.state(
            activatedAt: activatedAt,
            reviewObservationStartedAt: laterObservationStart,
            reviewCompletedAt: nil,
            reviewDecision: nil,
            now: now,
            calendar: calendar
        )
        guard case .due = state else {
            return XCTFail("Erwartet .due (anhand activatedAt), bekommen \(state)")
        }
    }
}
