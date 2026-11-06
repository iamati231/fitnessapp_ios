import XCTest
@testable import DeltiqCore

/// AI-Running-Coach Phase 2, Work Package 2A (docs/superpowers/plans/
/// 2026-11-06-ai-running-coach-phase2-implementation.md). Reine Funktion,
/// keine SwiftData-Abhaengigkeit - lokal kompilierbar UND ausfuehrbar.
final class TrainingLoadAggregatorTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func running(on day: Date, km: Double) -> TrainingActivity {
        TrainingActivity(
            date: day, runningDistanceKm: km, runningDurationSeconds: Int(km * 360),
            isRunning: true, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
    }

    private func cycling(on day: Date, km: Double) -> TrainingActivity {
        TrainingActivity(
            date: day, runningDistanceKm: nil, runningDurationSeconds: nil,
            isRunning: false, isCrossTrainingOnly: true, hasAmbiguousCardio: false,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
    }

    private func ambiguous(on day: Date) -> TrainingActivity {
        TrainingActivity(
            date: day, runningDistanceKm: nil, runningDurationSeconds: nil,
            isRunning: false, isCrossTrainingOnly: false, hasAmbiguousCardio: true,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
    }

    private func strength(on day: Date, sets: Int, volumeKg: Double) -> TrainingActivity {
        TrainingActivity(
            date: day, runningDistanceKm: nil, runningDurationSeconds: nil,
            isRunning: false, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: true, strengthSetCount: sets, strengthVolumeKg: volumeKg
        )
    }

    // MARK: - Testfall 1 (reine Laufwoche)

    func testPureRunningWeekHasZeroStrengthNumbers() {
        let week = date(2026, 1, 5)
        let activities = [running(on: week, km: 5), running(on: week.addingTimeInterval(2 * 86400), km: 8)]
        let weeks = TrainingLoadAggregator.aggregate(activities: activities, windowStart: week, now: week)
        XCTAssertEqual(weeks.reduce(0.0) { $0 + $1.running.runningDistanceKm }, 13)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.strengthSessionCount }, 0)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.strengthSetCount }, 0)
        XCTAssertEqual(weeks.reduce(0.0) { $0 + $1.strengthVolumeKg }, 0)
    }

    // MARK: - Testfall 2 (reine Krafttrainingswoche)

    func testPureStrengthWeekHasZeroRunningNumbers() {
        let week = date(2026, 1, 5)
        let activities = [strength(on: week, sets: 12, volumeKg: 3600)]
        let weeks = TrainingLoadAggregator.aggregate(activities: activities, windowStart: week, now: week)
        XCTAssertEqual(weeks.reduce(0.0) { $0 + $1.running.runningDistanceKm }, 0)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.running.runningSessionCount }, 0)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.strengthSetCount }, 12)
        XCTAssertEqual(weeks.reduce(0.0) { $0 + $1.strengthVolumeKg }, 3600)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.strengthSessionCount }, 1)
    }

    // MARK: - Testfall 3 (kombinierte Woche) + Teil C "keine gemeinsame Zahl"

    func testCombinedRunningAndStrengthWeekKeepsBothNumbersSeparate() {
        let week = date(2026, 1, 5)
        let activities = [
            running(on: week, km: 10),
            strength(on: week.addingTimeInterval(86400), sets: 15, volumeKg: 4000),
        ]
        let weeks = TrainingLoadAggregator.aggregate(activities: activities, windowStart: week, now: week.addingTimeInterval(86400))
        let totalRunning = weeks.reduce(0.0) { $0 + $1.running.runningDistanceKm }
        let totalVolume = weeks.reduce(0.0) { $0 + $1.strengthVolumeKg }
        XCTAssertEqual(totalRunning, 10, "Laufkilometer duerfen nie Krafttrainingsvolumen enthalten")
        XCTAssertEqual(totalVolume, 4000, "Krafttrainingsvolumen darf nie Laufkilometer enthalten")
    }

    // MARK: - Testfall 4 (Radfahren ohne Laufkilometer)

    func testCyclingNeverCountsTowardRunningDistance() {
        let week = date(2026, 1, 5)
        let weeks = TrainingLoadAggregator.aggregate(activities: [cycling(on: week, km: 40)], windowStart: week, now: week)
        XCTAssertEqual(weeks.reduce(0.0) { $0 + $1.running.runningDistanceKm }, 0)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.running.crossTrainingSessionCount }, 1)
    }

    // MARK: - Testfall 5 (unbekannte Sportart)

    func testUnknownActivityTypeNeverCountsAsRunningOrStrength() {
        let week = date(2026, 1, 5)
        let weeks = TrainingLoadAggregator.aggregate(activities: [ambiguous(on: week)], windowStart: week, now: week)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.running.ambiguousCardioSessionCount }, 1)
        XCTAssertEqual(weeks.reduce(0.0) { $0 + $1.running.runningDistanceKm }, 0)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.strengthSetCount }, 0)
    }

    // MARK: - Testfall 10/11 (unvollstaendige Historie / fehlende Dauer oder Distanz)

    func testMissingRunningDurationOrDistanceStaysNilNotZero() {
        let week = date(2026, 1, 5)
        let activity = TrainingActivity(
            date: week, runningDistanceKm: nil, runningDurationSeconds: nil,
            isRunning: true, isCrossTrainingOnly: false, hasAmbiguousCardio: false,
            hasStrengthActivity: false, strengthSetCount: 0, strengthVolumeKg: 0
        )
        let weeks = TrainingLoadAggregator.aggregate(activities: [activity], windowStart: week, now: week)
        // Laut CardioVolumeOverTimeAggregator wird eine Session ohne
        // bekannte Distanz zwar als Lauf-SESSION gezaehlt, traegt aber
        // keine Distanz/Pace bei - geerbtes, unveraendertes Phase-1-Verhalten.
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.running.runningSessionCount }, 1)
        XCTAssertEqual(weeks.reduce(0.0) { $0 + $1.running.runningDistanceKm }, 0, "keine Distanz heisst 0 Beitrag, niemals eine erfundene Zahl")
        XCTAssertNil(weeks.first?.running.averagePaceMinutesPerKm, "ohne Distanz/Dauer darf keine Pace erfunden werden")
    }

    func testIncompleteHistoryWithOnlySomeWeeksPresentStillFillsAllWeeksInWindow() {
        let week1 = date(2026, 1, 5)
        let week3 = date(2026, 1, 19)
        let weeks = TrainingLoadAggregator.aggregate(activities: [running(on: week1, km: 5)], windowStart: week1, now: week3)
        XCTAssertEqual(weeks.count, 3, "3 Wochen im Fenster, auch die leere mittlere Woche - gleiche Luecken-Fuell-Garantie wie Phase 1")
        XCTAssertEqual(weeks[1].running.runningSessionCount, 0)
        XCTAssertEqual(weeks[1].strengthSetCount, 0)
    }

    // MARK: - Testfall 14 (stabile Wochenzuordnung, Determinismus)

    func testAggregationIsDeterministicAcrossRepeatedCalls() {
        let week = date(2026, 1, 5)
        let activities = [running(on: week, km: 5), strength(on: week.addingTimeInterval(86400), sets: 10, volumeKg: 2000)]
        let first = TrainingLoadAggregator.aggregate(activities: activities, windowStart: week, now: week.addingTimeInterval(86400))
        let second = TrainingLoadAggregator.aggregate(activities: activities, windowStart: week, now: week.addingTimeInterval(86400))
        XCTAssertEqual(first, second, "gleiche Eingabe muss immer dasselbe Ergebnis liefern")
    }

    /// Kettlebell-/Bodyweight-Training traegt keine eigene Sportart-Flagge
    /// in `TrainingActivity` (es ist Krafttraining, kein Cardio) - der
    /// Nachweis liegt in `TrainingActivityExtractorTests` (DeltiqData), wo
    /// echte `Equipment`-getaggte `Exercise`s durch den vollen Datenfluss
    /// laufen. Hier nur der Grenzfall: 0 kg Volumen bei vorhandenen Saetzen
    /// ist ein gueltiger, von "keine Kraftarbeit" UNTERSCHEIDBARER Zustand.
    func testBodyweightStrengthHasZeroVolumeButNonZeroSetCount() {
        let week = date(2026, 1, 5)
        let bodyweight = strength(on: week, sets: 8, volumeKg: 0)
        let weeks = TrainingLoadAggregator.aggregate(activities: [bodyweight], windowStart: week, now: week)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.strengthSetCount }, 8, "Bodyweight-Saetze sind Trainingsaktivitaet, auch bei 0 kg")
        XCTAssertEqual(weeks.reduce(0.0) { $0 + $1.strengthVolumeKg }, 0)
        XCTAssertEqual(weeks.reduce(0) { $0 + $1.strengthSessionCount }, 1, "0 kg Volumen darf nicht mit 'keine Kraftarbeit' verwechselt werden")
    }
}
