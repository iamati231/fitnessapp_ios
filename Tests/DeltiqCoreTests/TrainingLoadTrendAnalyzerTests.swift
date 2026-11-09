import XCTest
@testable import DeltiqCore

/// AI-Running-Coach Phase 2, Work Package 2B (docs/superpowers/plans/
/// 2026-11-06-ai-running-coach-phase2-implementation.md). Reine Funktion,
/// keine SwiftData-Abhaengigkeit - lokal kompilierbar UND ausfuehrbar.
final class TrainingLoadTrendAnalyzerTests: XCTestCase {

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// Echte, am Kalender ausgerichtete Wochenstarts - niemals von Hand
    /// 7-Tage-Schritte addiert (bekannte Kalenderwochen-Falle, siehe
    /// `CardioVolumeOverTimeAggregatorTests`-Doku in diesem Repo).
    private func weekStart(_ offset: Int, from base: Date) -> Date {
        let baseStart = utc.dateInterval(of: .weekOfYear, for: base)!.start
        return utc.date(byAdding: .weekOfYear, value: offset, to: baseStart)!
    }

    private func week(
        _ weekStart: Date, runKm: Double = 0, runSessions: Int = 0,
        crossTraining: Int = 0, ambiguous: Int = 0,
        strengthSessions: Int = 0, strengthSets: Int = 0, strengthVolume: Double = 0
    ) -> TrainingLoadWeek {
        TrainingLoadWeek(
            weekStart: weekStart,
            running: CardioVolumeOverTimePoint(
                weekStart: weekStart, runningDistanceKm: runKm, runningSessionCount: runSessions,
                longestRunKm: runSessions > 0 && runKm > 0 ? runKm : nil, averagePaceMinutesPerKm: nil,
                averageHeartRateBpm: nil, crossTrainingSessionCount: crossTraining,
                ambiguousCardioSessionCount: ambiguous, strengthSessionCount: strengthSessions
            ),
            strengthSessionCount: strengthSessions, strengthSetCount: strengthSets, strengthVolumeKg: strengthVolume
        )
    }

    private let base = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14, arbitrary anchor

    // MARK: - Testfall 1: stabiles Laufvolumen

    func testStableRunningVolumeClassifiesAsStable() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        let weeks = starts.map { week($0, runKm: 20, runSessions: 3) }
        let now = weekStart(4, from: base) // Woche 4 (Index 3) ist dadurch vollstaendig
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertEqual(trend.running.weeklyDistanceKm.classification, .stable)
        XCTAssertEqual(trend.loadDevelopment, .stable)
    }

    // MARK: - Testfall 2: steigendes Laufvolumen

    func testIncreasingRunningVolumeIsDetected() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        let kms = [18.0, 18.0, 18.0, 27.0] // Ticket-Beispiel: flache 18km-Basis -> 27km = exakt +50%
        let weeks = zip(starts, kms).map { week($0, runKm: $1, runSessions: 3) }
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        guard case .significantIncrease(let disciplines, let percent) = trend.loadDevelopment else {
            return XCTFail("expected .significantIncrease, got \(trend.loadDevelopment)")
        }
        XCTAssertTrue(disciplines.contains(.running))
        XCTAssertEqual(percent, 0.5, accuracy: 0.01, "Ticket-Beispiel: 18km-Basis -> 27km = +50%")
    }

    // MARK: - Testfall 3: sinkendes Laufvolumen

    func testDecliningRunningVolumeIsDetected() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        let kms = [30.0, 29.0, 28.0, 15.0]
        let weeks = zip(starts, kms).map { week($0, runKm: $1, runSessions: 3) }
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        guard case .declining(let disciplines, let percent) = trend.loadDevelopment else {
            return XCTFail("expected .declining, got \(trend.loadDevelopment)")
        }
        XCTAssertTrue(disciplines.contains(.running))
        XCTAssertLessThan(percent, 0)
    }

    // MARK: - Testfall 4: stark schwankendes Laufvolumen

    func testHighlyVariableRunningVolumeIsDetected() {
        let starts = (0..<5).map { weekStart($0, from: base) }
        let kms = [10.0, 40.0, 8.0, 35.0, 12.0]
        let weeks = zip(starts, kms).map { week($0, runKm: $1, runSessions: 3) }
        let now = weekStart(5, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        guard case .highlyVariable(let cov) = trend.running.weeklyDistanceKm.classification else {
            return XCTFail("expected .highlyVariable, got \(trend.running.weeklyDistanceKm.classification)")
        }
        XCTAssertGreaterThan(cov, TrainingLoadTrendAnalyzer.variabilityCoefficientThreshold)
    }

    // MARK: - Testfall 5: steigendes Krafttrainingsvolumen

    func testIncreasingStrengthVolumeDrivesLoadDevelopment() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        let volumes = [2000.0, 2100.0, 2000.0, 3200.0]
        let weeks = zip(starts, volumes).map { week($0, strengthSessions: 3, strengthSets: 15, strengthVolume: $1) }
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        guard case .significantlyIncreasing = trend.strength.weeklyVolumeKg.classification else {
            return XCTFail("expected .significantlyIncreasing, got \(trend.strength.weeklyVolumeKg.classification)")
        }
        guard case .significantIncrease(let disciplines, _) = trend.loadDevelopment else {
            return XCTFail("expected overall .significantIncrease, got \(trend.loadDevelopment)")
        }
        XCTAssertTrue(disciplines.contains(.strength))
    }

    // MARK: - Testfall 6: sinkende Krafttrainingsfrequenz

    func testDecliningStrengthFrequencyIsVisibleIndependentlyOfVolume() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        // Volumen bleibt stabil, nur die SESSION-Anzahl sinkt (weniger, dafuer haertere Einheiten).
        let sessions = [4, 4, 4, 3]
        let weeks = zip(starts, sessions).map { week($0, strengthSessions: $1, strengthSets: 10, strengthVolume: 2000) }
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        guard case .declining = trend.strength.weeklySessionCount.classification else {
            return XCTFail("expected .declining session count, got \(trend.strength.weeklySessionCount.classification)")
        }
    }

    // MARK: - Testfall 7: kombinierte Lauf- und Krafttrainingswochen

    func testCombinedRunningAndStrengthWeeksStayIndependent() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        let weeks = starts.map { week($0, runKm: 20, runSessions: 3, strengthSessions: 2, strengthSets: 10, strengthVolume: 1500) }
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertEqual(trend.running.weeklyDistanceKm.classification, .stable)
        XCTAssertEqual(trend.strength.weeklyVolumeKg.classification, .stable)
        XCTAssertEqual(trend.running.weeklyDistanceKm.currentValue, 20)
        XCTAssertEqual(trend.strength.weeklyVolumeKg.currentValue, 1500)
    }

    // MARK: - Testfall 8: Radfahren ohne Laufkilometer

    func testCyclingNeverCountsTowardRunningDistance() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        let weeks = starts.map { week($0, crossTraining: 2) }
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertEqual(trend.running.weeklyDistanceKm.currentValue, 0)
        XCTAssertEqual(trend.otherEndurance.weeklySessionCount.currentValue, 2)
    }

    // MARK: - Testfall 9: mehrere Sportarten innerhalb einer Woche

    func testMultipleDisciplinesInOneWeekStayIsolated() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        let weeks = starts.map {
            week($0, runKm: 15, runSessions: 2, crossTraining: 1, ambiguous: 1, strengthSessions: 2, strengthSets: 8, strengthVolume: 1000)
        }
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertEqual(trend.running.weeklyDistanceKm.currentValue, 15)
        XCTAssertEqual(trend.otherEndurance.weeklySessionCount.currentValue, 1)
        XCTAssertEqual(trend.overall.weeklyAmbiguousSessionCount.currentValue, 1)
        XCTAssertEqual(trend.strength.weeklyVolumeKg.currentValue, 1000)
    }

    // MARK: - Testfall 10: Laufwoche mit fehlender Distanz

    func testRunningWeekWithMissingDistanceFlagsDataCompleteness() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        var weeks = starts.map { week($0, runKm: 20, runSessions: 3) }
        weeks[1] = week(starts[1], runKm: 0, runSessions: 2) // Sessions vorhanden, Distanz unbekannt
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        guard case .partial(let reasons) = trend.dataCompleteness else {
            return XCTFail("expected .partial, got \(trend.dataCompleteness)")
        }
        XCTAssertTrue(reasons.contains { if case .missingRunningDistance(let count) = $0 { return count == 1 }; return false })
    }

    // MARK: - Testfall 11: fehlende Trainingsdauer

    func testDurationDataIsAlwaysFlaggedUnavailable() {
        let now = weekStart(1, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: [week(weekStart(0, from: base), runKm: 10, runSessions: 2)], now: now, calendar: utc)
        XCTAssertNil(trend.overall.weeklyTotalDurationSeconds, "2A's Datenmodell erfasst keine Trainingsdauer - niemals erfinden")
        let reasons: [TrainingLoadDataCompleteness.Reason]
        switch trend.dataCompleteness {
        case .complete: return XCTFail("duration must never allow .complete")
        case .partial(let r), .insufficient(let r): reasons = r
        }
        XCTAssertTrue(reasons.contains(.durationDataUnavailable))
    }

    // MARK: - Testfall 12: historische Datenluecke

    func testGenuineGapWeekIsHonestZeroNotFalselyFlagged() {
        let starts = (0..<5).map { weekStart($0, from: base) }
        var weeks = starts.map { week($0, runKm: 20, runSessions: 3) }
        weeks[2] = week(starts[2]) // komplett leere Woche in der Mitte
        let now = weekStart(5, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        guard case .partial(let reasons) = trend.dataCompleteness else {
            return XCTFail("expected .partial, got \(trend.dataCompleteness)")
        }
        XCTAssertFalse(reasons.contains { if case .missingRunningDistance = $0 { return true }; return false },
                       "eine echte Null-Woche (0 Sessions) ist keine 'fehlende Distanz'-Woche")
    }

    // MARK: - Testfall 13: keine vorherige Vergleichswoche

    func testSingleWeekHasNoComparisonAndIsInsufficientData() {
        let now = weekStart(0, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: [week(weekStart(0, from: base), runKm: 10, runSessions: 2)], now: now, calendar: utc)
        XCTAssertNil(trend.running.weeklyDistanceKm.changeVsPreviousCompleteWeek)
        XCTAssertEqual(trend.running.weeklyDistanceKm.classification, .insufficientData)
    }

    // MARK: - Testfall 14: vorherige Woche mit 0 Laufkilometern

    func testZeroPreviousBaselineNeverProducesAMisleadingPercentage() {
        XCTAssertNil(MetricChange(previous: 0, current: 20).percentChange, "0-Basis darf nie eine Prozentzahl erzeugen")

        let starts = (0..<4).map { weekStart($0, from: base) }
        var weeks = starts.map { week($0, runKm: 20, runSessions: 3) }
        weeks[2] = week(starts[2]) // letzte vollstaendige Woche vor der aktuellen hatte 0 km
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertNil(trend.running.weeklyDistanceKm.changeVsPreviousCompleteWeek?.percentChange)
    }

    // MARK: - Testfall 15: aktuelle unvollstaendige Kalenderwoche

    func testCurrentIncompleteWeekIsFlagged() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        let weeks = starts.map { week($0, runKm: 20, runSessions: 3) }
        let now = starts[3].addingTimeInterval(2 * 86400) // mitten in Woche 4 (Index 3)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertFalse(trend.isCurrentWeekComplete)
        let reasons: [TrainingLoadDataCompleteness.Reason]
        switch trend.dataCompleteness {
        case .complete: return XCTFail()
        case .partial(let r), .insufficient(let r): reasons = r
        }
        XCTAssertTrue(reasons.contains(.currentWeekIncomplete))
    }

    // MARK: - Testfall 16: Zeitzonen-/Wochenwechsel

    func testWeekBoundaryWithExplicitFirstWeekdayDoesNotCrashOrMisclassify() {
        var mondayStart = utc
        mondayStart.firstWeekday = 2 // Montag als Wochenstart (DE-Konvention)
        let anchor = date(2026, 3, 2) // ein Montag
        func monWeekStart(_ offset: Int) -> Date {
            let start = mondayStart.dateInterval(of: .weekOfYear, for: anchor)!.start
            return mondayStart.date(byAdding: .weekOfYear, value: offset, to: start)!
        }
        let weeks = (0..<4).map { week(monWeekStart($0), runKm: 20, runSessions: 3) }
        let now = monWeekStart(4)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: mondayStart)
        XCTAssertEqual(trend.running.weeklyDistanceKm.classification, .stable)
    }

    // MARK: - Testfall 17: Jahreswechsel

    func testYearBoundaryWeeksAreHandledCorrectly() {
        let anchor = date(2025, 12, 22)
        let starts = (0..<4).map { weekStart($0, from: anchor) } // laeuft ueber den 1.1.2026
        let weeks = zip(starts, [18.0, 18.0, 18.0, 27.0]).map { week($0, runKm: $1, runSessions: 3) }
        let now = weekStart(4, from: anchor)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        guard case .significantIncrease = trend.loadDevelopment else {
            return XCTFail("Jahreswechsel darf die Berechnung nicht stoeren, got \(trend.loadDevelopment)")
        }
    }

    // MARK: - Testfall 18: Schaltjahr

    func testLeapYearFebruaryIsHandledCorrectly() {
        let anchor = date(2024, 2, 19) // 2024 ist ein Schaltjahr, enthaelt den 29. Februar
        let starts = (0..<4).map { weekStart($0, from: anchor) }
        let weeks = starts.map { week($0, runKm: 20, runSessions: 3) }
        let now = weekStart(4, from: anchor)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertEqual(trend.running.weeklyDistanceKm.classification, .stable)
    }

    // MARK: - Testfall 19: unbekannte Aktivitaet

    func testUnknownActivityIsFlaggedAndNeverCountsAsRunning() {
        let starts = (0..<4).map { weekStart($0, from: base) }
        var weeks = starts.map { week($0, runKm: 20, runSessions: 3) }
        weeks[3] = week(starts[3], runKm: 20, runSessions: 3, ambiguous: 1)
        let now = weekStart(4, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        guard case .partial(let reasons) = trend.dataCompleteness else {
            return XCTFail("expected .partial, got \(trend.dataCompleteness)")
        }
        XCTAssertTrue(reasons.contains { if case .unknownActivityPresent(let count) = $0 { return count == 1 }; return false })
        XCTAssertEqual(trend.running.weeklyDistanceKm.currentValue, 20, "unbekannte Aktivitaet darf Laufkilometer nicht veraendern")
    }

    // MARK: - Testfall 20/21/22: Acute:Chronic Datenbasis

    func testAcuteChronicRatioIsNilWithFewerThan28DaysHistory() {
        let starts = (0..<3).map { weekStart($0, from: base) } // nur 3 vollstaendige Wochen = 21 Tage
        let weeks = starts.map { week($0, runKm: 20, runSessions: 3) }
        let now = weekStart(3, from: base)
        XCTAssertNil(TrainingLoadTrendAnalyzer.acuteChronicRatio(weeks: weeks, now: now, calendar: utc))
    }

    func testAcuteChronicRatioIsComputedAtExactly28Days() {
        let starts = (0..<4).map { weekStart($0, from: base) } // exakt 4 vollstaendige Wochen = 28 Tage
        let weeks = zip(starts, [20.0, 20.0, 20.0, 30.0]).map { week($0, runKm: $1, runSessions: 3) }
        let now = weekStart(4, from: base)
        let acr = TrainingLoadTrendAnalyzer.acuteChronicRatio(weeks: weeks, now: now, calendar: utc)
        XCTAssertNotNil(acr)
        XCTAssertEqual(acr!, 30.0 / 22.5, accuracy: 0.001)
    }

    func test28DayWindowBeforeKnownHistoryStartYieldsNil() {
        // Das Fenster insgesamt (inkl. unvollstaendiger aktueller Woche) hat
        // nur 2 Wochen - das 28-Tage-Fenster kann nicht vollstaendig
        // innerhalb der bekannten Historie liegen.
        let starts = (0..<2).map { weekStart($0, from: base) }
        let weeks = starts.map { week($0, runKm: 20, runSessions: 3) }
        let now = weekStart(2, from: base)
        XCTAssertNil(TrainingLoadTrendAnalyzer.acuteChronicRatio(weeks: weeks, now: now, calendar: utc))
    }

    // MARK: - Testfall 23: Determinismus

    func testAnalyzeIsDeterministic() {
        let starts = (0..<5).map { weekStart($0, from: base) }
        let weeks = zip(starts, [18.0, 22.0, 19.0, 25.0, 30.0]).map { week($0, runKm: $1, runSessions: 3, strengthSessions: 2, strengthSets: 10, strengthVolume: 1800) }
        let now = weekStart(5, from: base)
        let first = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        let second = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertEqual(first, second)
    }

    // MARK: - Grenzfaelle: Division durch 0, negative Werte, ungueltige Eingaben

    func testEmptyWeeksArrayNeverCrashesAndReportsInsufficientData() {
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: [], now: base, calendar: utc)
        XCTAssertNil(trend.currentWeek)
        XCTAssertFalse(trend.isCurrentWeekComplete)
        XCTAssertEqual(trend.loadDevelopment, .insufficientData)
        XCTAssertNil(trend.acuteChronicRatio)
        guard case .insufficient = trend.dataCompleteness else {
            return XCTFail("expected .insufficient, got \(trend.dataCompleteness)")
        }
    }

    func testZeroMeanNeverProducesANaNCoefficientOfVariation() {
        let starts = (0..<5).map { weekStart($0, from: base) }
        let weeks = starts.map { week($0) } // alles 0 - reine Nicht-Teilnahme, kein Datenfehler
        let now = weekStart(5, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertEqual(trend.running.weeklyDistanceKm.classification, .notApplicable)
        XCTAssertEqual(trend.loadDevelopment, .stable, "beide Disziplinen bei 0 -> stabil, nie ein Rechenfehler")
    }

    func testAcuteChronicRatioIsNilWhenChronicAverageIsZero() {
        // 4 VOLLSTAENDIGE Wochen ohne jeden Lauf (das chronische 4-Wochen-
        // Fenster), der erste Lauf ueberhaupt faellt erst in die AKTUELLE,
        // unvollstaendige 5. Woche - fliesst damit nie in `completeWeeks`
        // ein, das chronische Fenster bleibt bei 0.
        let starts = (0..<5).map { weekStart($0, from: base) }
        var weeks = starts.map { week($0) }
        weeks[4] = week(starts[4], runKm: 15, runSessions: 2)
        let now = starts[4].addingTimeInterval(2 * 86400) // mitten in Woche 5 - Woche 5 bleibt unvollstaendig
        XCTAssertNil(TrainingLoadTrendAnalyzer.acuteChronicRatio(weeks: weeks, now: now, calendar: utc),
                     "ein Sprung von 0 auf irgendeinen Wert ist kein sinnvolles Verhaeltnis")
    }

    func testNegativeMeanNeverTriggersVariabilityCheck() {
        // Kann in der Praxis nicht entstehen (SessionAggregator/2A klemmen
        // negative Werte bereits), aber die Funktion darf bei einem
        // theoretisch negativen Eingabewert nie abstuerzen oder NaN liefern.
        let starts = (0..<3).map { weekStart($0, from: base) }
        let weeks = starts.map { week($0, runKm: -5, runSessions: 1) }
        let now = weekStart(3, from: base)
        let trend = TrainingLoadTrendAnalyzer.analyze(weeks: weeks, now: now, calendar: utc)
        XCTAssertFalse(trend.running.weeklyDistanceKm.currentValue?.isNaN ?? false)
    }
}
