import XCTest
@testable import FitnessAppCore

final class CardioBaselineCalculatorTests: XCTestCase {

    // MARK: - weeklyVolumeKm

    func testEmptyDistancesYieldsNil() {
        XCTAssertNil(CardioBaselineCalculator.weeklyVolumeKm(distancesKm: []))
    }

    func testWeeklyVolumeIsSumDividedByFourWeeks() throws {
        // 10 + 15 + 20 + 25 = 70 km ueber 4 Wochen -> 17.5 km/Woche.
        let result = try XCTUnwrap(CardioBaselineCalculator.weeklyVolumeKm(distancesKm: [10, 15, 20, 25]))
        XCTAssertEqual(result, 17.5, accuracy: 0.0001)
    }

    func testWeeklyVolumeCountsEveryLoggedRunRegardlessOfLength() throws {
        // Anders als die Referenzpace hat das Wochenvolumen KEINEN
        // Mindest-Distanz-/Dauer-Filter - auch ein kurzer Erholungslauf zaehlt.
        let result = try XCTUnwrap(CardioBaselineCalculator.weeklyVolumeKm(distancesKm: [0.5, 1.0]))
        XCTAssertEqual(result, 0.375, accuracy: 0.0001)
    }

    // MARK: - fastestReferenceSeconds

    func testEmptyRunsYieldsNil() {
        XCTAssertNil(CardioBaselineCalculator.fastestReferenceSeconds(from: []))
    }

    func testExactFiveKReferenceRunScalesToItself() {
        // 5 km in 25:00 (1500s) -> Pace 5.0 min/km -> Referenz fuer genau
        // 5 km ist wieder 1500s.
        let run = CardioBaselineCalculator.RunSample(distanceKm: 5.0, durationSeconds: 1500)
        XCTAssertEqual(CardioBaselineCalculator.fastestReferenceSeconds(from: [run]), 1500)
    }

    func testTenKRunScalesDownToFiveKEquivalent() {
        // 10 km in 45:00 (2700s) -> Pace 4.5 min/km -> 5-km-Aequivalent:
        // 4.5 * 5 * 60 = 1350s (22:30).
        let run = CardioBaselineCalculator.RunSample(distanceKm: 10.0, durationSeconds: 2700)
        XCTAssertEqual(CardioBaselineCalculator.fastestReferenceSeconds(from: [run]), 1350)
    }

    func testPicksTheFastestOfMultipleQualifyingRuns() {
        let slower = CardioBaselineCalculator.RunSample(distanceKm: 5.0, durationSeconds: 1500)  // 5.0 min/km
        let faster = CardioBaselineCalculator.RunSample(distanceKm: 10.0, durationSeconds: 2700) // 4.5 min/km
        XCTAssertEqual(
            CardioBaselineCalculator.fastestReferenceSeconds(from: [slower, faster]),
            1350,
            "der schnellere Lauf (niedrigere Pace) muss gewinnen, unabhaengig von der Reihenfolge der Eingabe"
        )
        XCTAssertEqual(
            CardioBaselineCalculator.fastestReferenceSeconds(from: [faster, slower]),
            1350
        )
    }

    func testRunBelowMinimumDistanceIsExcluded() {
        // 2.9 km - knapp unter der 3-km-Referenz-Schwelle, egal wie schnell.
        let tooShort = CardioBaselineCalculator.RunSample(distanceKm: 2.9, durationSeconds: 600)
        XCTAssertNil(CardioBaselineCalculator.fastestReferenceSeconds(from: [tooShort]))
    }

    func testRunBelowMinimumDurationIsExcludedEvenIfDistanceQualifies() {
        // 5 km, aber nur 299s (< 5 Min) - fehlgestartete Uhr/Dateneingabefehler.
        let tooFast = CardioBaselineCalculator.RunSample(distanceKm: 5.0, durationSeconds: 299)
        XCTAssertNil(CardioBaselineCalculator.fastestReferenceSeconds(from: [tooFast]))
    }

    func testExactBoundaryDistanceAndDurationQualify() {
        // Exakt 3.0 km und exakt 300s - >= zaehlt, nicht erst > .
        let boundary = CardioBaselineCalculator.RunSample(distanceKm: 3.0, durationSeconds: 300)
        XCTAssertNotNil(CardioBaselineCalculator.fastestReferenceSeconds(from: [boundary]))
    }

    func testNonQualifyingRunsAreIgnoredAmongMixedInput() {
        let tooShort = CardioBaselineCalculator.RunSample(distanceKm: 2.0, durationSeconds: 600)
        let qualifying = CardioBaselineCalculator.RunSample(distanceKm: 5.0, durationSeconds: 1500)
        XCTAssertEqual(
            CardioBaselineCalculator.fastestReferenceSeconds(from: [tooShort, qualifying]),
            1500
        )
    }

    // MARK: - classifyWeeklyVolume

    func testClassifyNoEntriesYieldsBeginner() {
        let (cat, km) = CardioBaselineCalculator.classifyWeeklyVolume(entries: [])
        XCTAssertEqual(cat, .beginner)
        XCTAssertEqual(km, CardioBaselineCalculator.beginnerDefaultKm, accuracy: 0.001)
    }

    func testClassifyActiveRunnerMedianOfFourWeeks() {
        let ref = Date()
        let cal = Calendar.current
        let daysAgo = { (n: Int) in cal.date(byAdding: .day, value: -n, to: ref)! }
        // Week 0: 10, Woche 1: 15, Woche 2: 12, Woche 3: 8 → sorted [8,10,12,15] → median 11
        let entries = [
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(3),  distanceKm: 10),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(10), distanceKm: 15),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(17), distanceKm: 12),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(24), distanceKm: 8),
        ]
        let (cat, km) = CardioBaselineCalculator.classifyWeeklyVolume(entries: entries, referenceDate: ref)
        XCTAssertEqual(cat, .activeRunner)
        XCTAssertEqual(km, 11.0, accuracy: 0.001)
    }

    func testClassifyActiveRunnerMedianIgnoresOutlier() {
        let ref = Date()
        let cal = Calendar.current
        let daysAgo = { (n: Int) in cal.date(byAdding: .day, value: -n, to: ref)! }
        // Renneinsatz-Woche (50 km) darf Baseline nicht aufblasen:
        // sorted [20,20,20,50] → median 20, nicht Mittelwert 27.5
        let entries = [
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(2),  distanceKm: 50),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(10), distanceKm: 20),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(17), distanceKm: 20),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(24), distanceKm: 20),
        ]
        let (cat, km) = CardioBaselineCalculator.classifyWeeklyVolume(entries: entries, referenceDate: ref)
        XCTAssertEqual(cat, .activeRunner)
        XCTAssertEqual(km, 20.0, accuracy: 0.001)
    }

    func testClassifyReturningRunnerPauseDetected() {
        let ref = Date()
        let cal = Calendar.current
        let daysAgo = { (n: Int) in cal.date(byAdding: .day, value: -n, to: ref)! }
        // Letzter Lauf vor 50 Tagen → pauseWeeks=7, factor=0.60
        // Historical buckets vor der Pause: [10,20,15,8] → sorted [8,10,15,20] → hist=12.5
        // suggested = max(12.5*0.60, 3.0) = 7.5
        let entries = [
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(50), distanceKm: 10),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(57), distanceKm: 20),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(64), distanceKm: 15),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(71), distanceKm: 8),
        ]
        let (cat, km) = CardioBaselineCalculator.classifyWeeklyVolume(entries: entries, referenceDate: ref)
        XCTAssertEqual(cat, .returningRunner(pauseWeeks: 7))
        XCTAssertEqual(km, 7.5, accuracy: 0.001)
    }

    func testClassifyInsufficientDataOneActiveWeek() {
        let ref = Date()
        let cal = Calendar.current
        let daysAgo = { (n: Int) in cal.date(byAdding: .day, value: -n, to: ref)! }
        // Nur 1 aktive Woche → insufficientData; mean=2.5 → max(2.5, beginnerDefault=3.0)
        let entries = [
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(10), distanceKm: 10),
        ]
        let (cat, km) = CardioBaselineCalculator.classifyWeeklyVolume(entries: entries, referenceDate: ref)
        XCTAssertEqual(cat, .insufficientData)
        XCTAssertEqual(km, CardioBaselineCalculator.beginnerDefaultKm, accuracy: 0.001)
    }

    // MARK: - Median: leere Wochen nicht einrechnen (DEL-251-v2 Bugfix)

    func testClassifyActiveRunnerFourEqualWeeks() {
        let ref = Date()
        let cal = Calendar.current
        let daysAgo = { (n: Int) in cal.date(byAdding: .day, value: -n, to: ref)! }
        // 4 × 10 km → activeKm=[10,10,10,10], median=10
        let entries = [
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(3),  distanceKm: 10),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(10), distanceKm: 10),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(17), distanceKm: 10),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(24), distanceKm: 10),
        ]
        let (cat, km) = CardioBaselineCalculator.classifyWeeklyVolume(entries: entries, referenceDate: ref)
        XCTAssertEqual(cat, .activeRunner)
        XCTAssertEqual(km, 10.0, accuracy: 0.001)
    }

    func testClassifyActiveRunnerTwoActiveTwoEmpty() {
        let ref = Date()
        let cal = Calendar.current
        let daysAgo = { (n: Int) in cal.date(byAdding: .day, value: -n, to: ref)! }
        // 2 aktive Wochen × 10 km, 2 leere → typisches Volumen = 10 km, nicht (0+10)/2=5
        let entries = [
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(3),  distanceKm: 10),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(10), distanceKm: 10),
        ]
        let (cat, km) = CardioBaselineCalculator.classifyWeeklyVolume(entries: entries, referenceDate: ref)
        XCTAssertEqual(cat, .activeRunner)
        XCTAssertEqual(km, 10.0, accuracy: 0.001,
            "Zwei leere Wochen duerfen den Median nicht kuenstlich auf 5 km halbieren")
    }

    func testClassifyActiveRunnerOneActiveIsInsufficientNotQuartered() {
        let ref = Date()
        let cal = Calendar.current
        let daysAgo = { (n: Int) in cal.date(byAdding: .day, value: -n, to: ref)! }
        // 1 aktive Woche (10 km) → insufficientData; kein kuenstliches 10/4=2.5
        let entries = [
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(3), distanceKm: 10),
        ]
        let (cat, km) = CardioBaselineCalculator.classifyWeeklyVolume(entries: entries, referenceDate: ref)
        XCTAssertEqual(cat, .insufficientData)
        XCTAssertEqual(km, CardioBaselineCalculator.beginnerDefaultKm, accuracy: 0.001,
            "Eine aktive Woche darf nicht auf 10/4=2.5 heruntergerechnet werden")
    }

    func testClassifyReturningRunnerTwoActiveTwoEmptyHistorical() {
        let ref = Date()
        let cal = Calendar.current
        let daysAgo = { (n: Int) in cal.date(byAdding: .day, value: -n, to: ref)! }
        // Pause 50 Tage, vor der Pause: bucket 0 (10 km) und bucket 2 (15 km); buckets 1+3 leer
        // Fix: preActiveKm=[10,15] → hist=(10+15)/2=12.5 * 0.60 = 7.5
        // Fehler pre-fix: preSorted=[0,0,10,15] → hist=(0+10)/2=5 * 0.60 = 3.0
        let entries = [
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(50), distanceKm: 10),
            CardioBaselineCalculator.TimestampedEntry(date: daysAgo(64), distanceKm: 15),
        ]
        let (cat, km) = CardioBaselineCalculator.classifyWeeklyVolume(entries: entries, referenceDate: ref)
        XCTAssertEqual(cat, .returningRunner(pauseWeeks: 7))
        XCTAssertEqual(km, 7.5, accuracy: 0.001,
            "Leere Wochen vor der Pause duerfen hist. Median nicht auf (0+10)/2=5 senken")
    }

    // MARK: - isRunningEquipment (Lauffilter)

    func testRunningEquipmentIncludesOutdoorRun() {
        XCTAssertTrue(CardioBaselineCalculator.isRunningEquipment(.none),
            ".none (Outdoor-Lauf) muss als Laufeinheit gelten")
    }

    func testRunningEquipmentIncludesTreadmill() {
        XCTAssertTrue(CardioBaselineCalculator.isRunningEquipment(.treadmill),
            ".treadmill muss als Laufeinheit gelten")
    }

    func testRunningEquipmentExcludesCycling() {
        XCTAssertFalse(CardioBaselineCalculator.isRunningEquipment(.bikeOutdoor),
            "Radfahren (.bikeOutdoor) darf nicht als Laufkilometer zaehlen")
    }

    func testRunningEquipmentExcludesErgometer() {
        XCTAssertFalse(CardioBaselineCalculator.isRunningEquipment(.ergometer),
            "Ergometer/Schwimmen darf nicht als Laufkilometer zaehlen")
    }

    func testRunningEquipmentExcludesRowing() {
        XCTAssertFalse(CardioBaselineCalculator.isRunningEquipment(.rowingMachine),
            "Rudern darf nicht als Laufkilometer zaehlen")
    }

    func testRunningEquipmentExactlyNoneAndTreadmill() {
        // Schlaegt an, wenn CardioEquipment neue Faelle bekommt und isRunningEquipment nicht angepasst wird.
        let running = CardioEquipment.allCases.filter { CardioBaselineCalculator.isRunningEquipment($0) }
        XCTAssertEqual(Set(running), [.none, .treadmill],
            "Genau .none (Outdoor) und .treadmill sind Laufeinheiten — alle anderen gelten als nicht-Lauf")
    }
}
