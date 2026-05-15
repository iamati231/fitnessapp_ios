import XCTest
@testable import FitnessAppCore

/// DEL-081 + DEL-093: Tests fuer die Drei-State-Kategorisierung einer
/// Workout-Session — mit besonderem Fokus auf den Ad-Hoc-Cardio-Fix.
final class SessionCategoryTests: XCTestCase {

    func testPureStrengthSession() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: false, distanceKm: nil, durationSeconds: nil),
            (isCardio: false, distanceKm: nil, durationSeconds: nil),
            (isCardio: false, distanceKm: nil, durationSeconds: nil)
        ])
        XCTAssertEqual(category, .pureStrength)
    }

    func testPureCardioSession() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: true, distanceKm: 5.0, durationSeconds: 1500)
        ])
        XCTAssertEqual(category, .pureCardio)
    }

    func testMixedSession() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: false, distanceKm: nil, durationSeconds: nil),    // Bench-Set
            (isCardio: false, distanceKm: nil, durationSeconds: nil),    // Bench-Set
            (isCardio: true,  distanceKm: 3.0, durationSeconds: 900)     // Run
        ])
        XCTAssertEqual(category, .mixed)
    }

    /// DEL-081 + DEL-093: Ein Plan-Mixed-Day mit GESKIPPTEM Cardio (z.B.
    /// User hat den Lauf nicht gemacht) zaehlt weiterhin als pureStrength —
    /// sonst wuerde die History "Mixed" anzeigen, obwohl der User nur
    /// Bankdruecken absolviert hat.
    func testStrengthPlusSkippedCardioStaysPureStrength() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: false, distanceKm: nil, durationSeconds: nil),
            (isCardio: true,  distanceKm: nil, durationSeconds: nil)
        ])
        XCTAssertEqual(category, .pureStrength)
    }

    /// Strength + Cardio mit 0 km zaehlt ebenfalls nicht als Mixed —
    /// > 0-Guard im Evaluator.
    func testStrengthPlusZeroDistanceCardioStaysPureStrength() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: false, distanceKm: nil, durationSeconds: nil),
            (isCardio: true,  distanceKm: 0.0, durationSeconds: 0)
        ])
        XCTAssertEqual(category, .pureStrength)
    }

    /// DEL-093 Bugfix: Ad-Hoc-Laufband-Workout, bei dem der User NUR die
    /// Dauer eingetragen hat (kein km). Vorher fiel das auf pureStrength
    /// zurueck und die History zeigte "0 Sätze · 0 kg" — jetzt landet es
    /// korrekt im pureCardio-Zweig (Dauer · Distanz · Pace).
    func testAdHocCardioWithOnlyDurationCountsAsPureCardio() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: true, distanceKm: nil, durationSeconds: 1200)   // 20 min Laufband
        ])
        XCTAssertEqual(category, .pureCardio)
    }

    /// DEL-093: Reines Cardio mit Distanz (kein Strength-Anteil) — landet
    /// natuerlich auch im pureCardio-Zweig.
    func testAdHocCardioWithOnlyDistanceCountsAsPureCardio() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: true, distanceKm: 5.0, durationSeconds: nil)
        ])
        XCTAssertEqual(category, .pureCardio)
    }

    /// DEL-093: Selbst ein Cardio-Log ohne JEGLICHE Werte (User hat einfach
    /// den Checkmark gedrueckt) landet im pureCardio-Zweig — defensiver
    /// Fallback fuer freie Ad-Hoc-Trainings, sonst zeigte History wieder
    /// die irrefuehrenden Strength-Metriken.
    func testAdHocCardioWithNoValuesStillPureCardio() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: true, distanceKm: nil, durationSeconds: nil)
        ])
        XCTAssertEqual(category, .pureCardio)
    }

    /// Mehrere Ad-Hoc-Cardio-Logs (z.B. 2× Laufband, jeweils nur Dauer) →
    /// pureCardio. Sicherheitsnetz, dass `hasAnyCardio` greift, auch wenn
    /// keiner der Logs distanz-/duration-meaningful gefuellt ist.
    func testMultipleAdHocCardioLogsAllDurationOnlyStillPureCardio() {
        let category = SessionCategory.evaluate(logs: [
            (isCardio: true, distanceKm: nil, durationSeconds: 600),
            (isCardio: true, distanceKm: nil, durationSeconds: 900)
        ])
        XCTAssertEqual(category, .pureCardio)
    }

    /// Empty-Logs → defensiv pureStrength (UI rendert sich dann nicht
    /// als "Lauf, aber leer").
    func testEmptyLogsReturnsPureStrength() {
        let category = SessionCategory.evaluate(logs: [])
        XCTAssertEqual(category, .pureStrength)
    }
}
