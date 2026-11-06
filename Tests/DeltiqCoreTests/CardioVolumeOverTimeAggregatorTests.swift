import XCTest
@testable import DeltiqCore

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md,
/// Abschnitt 3): reine Funktion, keine SwiftData-Abhaengigkeit - lokal auf
/// jedem Host kompilierbar UND ausfuehrbar (anders als der DeltiqData-Bestand).
///
/// Bugfix-Regression (CI-Fund auf echtem macOS-Runner, siehe Abschlussbericht):
/// die urspruengliche Fassung dieser Tests liess `aggregate(...)`s `now:`
/// weglassen (Default `Date()` = tatsaechliches Tagesdatum des Testlaufs) UND
/// filterte das Ergebnis per `points.first { $0.weekStart == week }` -
/// `weekStart` wird von `Calendar.current` (lokal-/runner-abhaengig) aus
/// `dateInterval(of: .weekOfYear, for:)` berechnet und muss NICHT mit dem
/// rohen Eingabedatum uebereinstimmen (nur wenn dieses zufaellig exakt der
/// erste Tag seiner Kalenderwoche ist). Auf dem Windows-Host (nur
/// Kompilierungspruefung moeglich) blieb das unentdeckt; auf dem echten
/// macOS-CI-Runner schlugen 5 von 7 betroffenen Tests fehl, die anderen 2
/// bestanden nur zufaellig (vacuous pass: `nil?.x == nil`). Fix: `now:`
/// immer explizit und knapp an die Eingabedaten gebunden, UND Summierung
/// ueber ALLE zurueckgegebenen Punkte statt kalenderabhaengiger
/// Einzelpunkt-Suche - robust unabhaengig von `Calendar.current`s
/// tatsaechlicher Konfiguration auf dem jeweiligen Host.
final class CardioVolumeOverTimeAggregatorTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func running(
        on day: Date, km: Double?, seconds: Int?
    ) -> CardioVolumeOverTimeAggregator.LoggedSession {
        .init(
            date: day, runningDistanceKm: km, runningDurationSeconds: seconds,
            isRunning: true, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: false
        )
    }

    private func crossTraining(on day: Date) -> CardioVolumeOverTimeAggregator.LoggedSession {
        .init(
            date: day, runningDistanceKm: nil, runningDurationSeconds: nil,
            isRunning: false, isCrossTrainingOnly: true, hasAmbiguousCardio: false,
            hasStrengthActivity: false
        )
    }

    private func ambiguous(on day: Date) -> CardioVolumeOverTimeAggregator.LoggedSession {
        .init(
            date: day, runningDistanceKm: nil, runningDurationSeconds: nil,
            isRunning: false, isCrossTrainingOnly: false, hasAmbiguousCardio: true,
            hasStrengthActivity: false
        )
    }

    private func strength(on day: Date) -> CardioVolumeOverTimeAggregator.LoggedSession {
        .init(
            date: day, runningDistanceKm: nil, runningDurationSeconds: nil,
            isRunning: false, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: true
        )
    }

    // Testfall 9 (Plan Abschnitt 6): Krafttraining fliesst nie in Lauf-Umfang ein.
    func testStrengthSessionCountFeedsLoadRecoveryButNeverRunningVolume() {
        let week = date(2026, 1, 5)
        let secondDay = week.addingTimeInterval(86400)
        let points = CardioVolumeOverTimeAggregator.aggregate(
            sessions: [strength(on: week), strength(on: secondDay)],
            windowStart: week, now: secondDay
        )
        XCTAssertEqual(points.reduce(0) { $0 + $1.strengthSessionCount }, 2)
        XCTAssertEqual(points.reduce(0.0) { $0 + $1.runningDistanceKm }, 0, "Krafttraining darf nie in den Lauf-Umfang einfliessen")
        XCTAssertEqual(points.reduce(0) { $0 + $1.runningSessionCount }, 0)
    }

    // Testfall 18: bekannte Cross-Training-Woche ist kein Lauf-Gap.
    func testCyclingOnlyWeekIsCrossTrainingNotGapNotDataGap() {
        let week = date(2026, 1, 5)
        let points = CardioVolumeOverTimeAggregator.aggregate(
            sessions: [crossTraining(on: week)], windowStart: week, now: week
        )
        XCTAssertEqual(points.reduce(0) { $0 + $1.crossTrainingSessionCount }, 1)
        XCTAssertEqual(points.reduce(0) { $0 + $1.runningSessionCount }, 0)
        XCTAssertEqual(points.reduce(0) { $0 + $1.ambiguousCardioSessionCount }, 0, "Radfahren ist bekannt, keine Mehrdeutigkeit")
    }

    // Testfall 19: unbekannte Sportart wird nie als Laufen gezaehlt.
    func testAmbiguousEnduranceSportKindNeverCountsAsRunningDistance() {
        let week = date(2026, 1, 5)
        let points = CardioVolumeOverTimeAggregator.aggregate(
            sessions: [ambiguous(on: week)], windowStart: week, now: week
        )
        XCTAssertEqual(points.reduce(0) { $0 + $1.ambiguousCardioSessionCount }, 1)
        XCTAssertEqual(points.reduce(0) { $0 + $1.runningSessionCount }, 0)
        XCTAssertEqual(points.reduce(0.0) { $0 + $1.runningDistanceKm }, 0)
    }

    // Testfall 23: eine Session mit Lauf- UND Rad-Signal (vom Extractor als
    // isRunning=true UND zusaetzlichem Cross-Training-Kontext geliefert, z.B.
    // ein Brick) zaehlt als Running, Cross-Training-Information bleibt sichtbar
    // (hier: zwei separate LoggedSession-Eintraege am selben Tag, da die
    // Aggregator-Ebene Session-granular arbeitet, nicht Log-granular -
    // die Zusammenfuehrung pro WorkoutSession ist Aufgabe des Extractors).
    func testMixedRunAndCyclingSessionCountsAsRunningWithCrossTrainingContextPreserved() {
        let week = date(2026, 1, 5)
        let mixedSession = CardioVolumeOverTimeAggregator.LoggedSession(
            date: week, runningDistanceKm: 5, runningDurationSeconds: 1800,
            isRunning: true, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: false
        )
        let points = CardioVolumeOverTimeAggregator.aggregate(sessions: [mixedSession], windowStart: week, now: week)
        XCTAssertEqual(points.reduce(0) { $0 + $1.runningSessionCount }, 1)
        XCTAssertEqual(points.reduce(0.0) { $0 + $1.runningDistanceKm }, 5)
    }

    func testLongestRunAndDistanceWeightedPaceAreComputedCorrectly() {
        let week = date(2026, 1, 5)
        let secondRunDay = week.addingTimeInterval(2 * 86400)
        let points = CardioVolumeOverTimeAggregator.aggregate(
            sessions: [
                running(on: week, km: 5, seconds: 1800),       // 6:00 min/km
                running(on: secondRunDay, km: 15, seconds: 4500), // 5:00 min/km, longest
            ],
            windowStart: week, now: secondRunDay
        )
        XCTAssertEqual(points.reduce(0.0) { $0 + $1.runningDistanceKm }, 20)
        XCTAssertEqual(points.reduce(0) { $0 + $1.runningSessionCount }, 2)
        XCTAssertEqual(points.compactMap(\.longestRunKm).max(), 15)
        // Distanz-gewichtet: (1800+4500)s / 20km = 315s/km = 5.25 min/km.
        // Nur gueltig, wenn beide Laeufe in DENSELBEN Bucket fallen (gleiche
        // Kalenderwoche) - mit `now:` knapp an `secondRunDay` gebunden UND
        // beide Tage nur 2 Tage auseinander ist das auf jeder realistischen
        // `Calendar.current`-Konfiguration der Fall; zur Sicherheit wird hier
        // trotzdem ueber alle Punkte distanz-gewichtet gemittelt statt einen
        // einzelnen Bucket anzunehmen.
        let totalDistance = points.reduce(0.0) { $0 + $1.runningDistanceKm }
        let totalWeightedPace = points.compactMap { point -> Double? in
            guard let pace = point.averagePaceMinutesPerKm else { return nil }
            return pace * point.runningDistanceKm
        }.reduce(0, +)
        XCTAssertEqual(totalWeightedPace / totalDistance, 5.25, accuracy: 0.001)
    }

    func testPaceIsNilWhenNoRunHasBothDistanceAndDuration() {
        let week = date(2026, 1, 5)
        let points = CardioVolumeOverTimeAggregator.aggregate(
            sessions: [running(on: week, km: 5, seconds: nil)], windowStart: week, now: week
        )
        XCTAssertTrue(points.allSatisfy { $0.averagePaceMinutesPerKm == nil })
    }

    func testHeartRateIsAlwaysNilInPhase1() {
        let week = date(2026, 1, 5)
        let points = CardioVolumeOverTimeAggregator.aggregate(
            sessions: [running(on: week, km: 5, seconds: 1800)], windowStart: week, now: week
        )
        XCTAssertFalse(points.isEmpty, "Testaufbau: mindestens ein Punkt wird erwartet")
        XCTAssertTrue(points.allSatisfy { $0.averageHeartRateBpm == nil }, "Phase 1 hat keine HF-Datenquelle - nie geraten/geschaetzt")
    }

    // Luecken-Darstellung: jede Woche im Fenster bekommt einen Eintrag, auch
    // komplett leer - gleiches Prinzip wie VolumeOverTimeAggregator.
    func testGapWeeksWithNoActivityAtAllGetAZeroedEntryNotASkippedOne() {
        let week1 = date(2026, 1, 5)
        let week3 = date(2026, 1, 19)
        let points = CardioVolumeOverTimeAggregator.aggregate(
            sessions: [running(on: week1, km: 5, seconds: 1500)],
            windowStart: week1, now: week3
        )
        XCTAssertEqual(points.count, 3, "3 Wochen im Fenster, auch die leere mittlere Woche")
        let middle = points[1]
        XCTAssertEqual(middle.runningSessionCount, 0)
        XCTAssertEqual(middle.strengthSessionCount, 0)
        XCTAssertEqual(middle.crossTrainingSessionCount, 0)
        XCTAssertEqual(middle.ambiguousCardioSessionCount, 0)
    }
}
