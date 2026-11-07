import XCTest
@testable import DeltiqCore

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md,
/// Abschnitt 3). Reine Funktion, lokal kompilierbar UND ausfuehrbar.
final class RaceProgressAssessmentTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func point(
        _ weekOffset: Int, km: Double = 20, runs: Int = 3, longest: Double? = nil,
        pace: Double? = nil, cross: Int = 0, ambiguous: Int = 0, strength: Int = 2
    ) -> CardioVolumeOverTimePoint {
        CardioVolumeOverTimePoint(
            weekStart: date(2026, 1, 5).addingTimeInterval(TimeInterval(weekOffset * 7 * 86400)),
            runningDistanceKm: km, runningSessionCount: runs, longestRunKm: longest,
            averagePaceMinutesPerKm: pace, averageHeartRateBpm: nil,
            crossTrainingSessionCount: cross, ambiguousCardioSessionCount: ambiguous,
            strengthSessionCount: strength
        )
    }

    /// Bugfix-Regression (CI-Fund auf echtem macOS-Runner): `observationStart
    /// ?? series.first?.weekStart` kollabierte ein ausdruecklich uebergebenes
    /// `nil` (bei `testUnknownCoachingObservationStartSuppressesAllPeriodBasedConcerns`
    /// explizit gewollt) stillschweigend auf einen echten Wert - jeder
    /// Aufrufer dieser Datei uebergibt `observationStart` bereits explizit
    /// (auch `nil`), der Default existiert nur fuer eine nicht genutzte
    /// Bequemlichkeit und wird hier entfernt, damit ein echtes `nil` auch
    /// ein echtes `nil` bleibt.
    private func input(
        series: [CardioVolumeOverTimePoint],
        goal: CardioGoal = .halfMarathon,
        raceDate: Date? = nil,
        observationStart: Date?,
        currentWeeklyVolumeKm: Double? = 20,
        isCurrentWeekIncomplete: Bool = true
    ) -> RaceProgressAssessment.Input {
        .init(
            weeklySeries: series, goal: goal, raceDate: raceDate,
            coachingObservationStart: observationStart,
            currentWeeklyVolumeKm: currentWeeklyVolumeKm,
            isCurrentWeekIncomplete: isCurrentWeekIncomplete,
            now: series.last?.weekStart.addingTimeInterval(6 * 86400) ?? Date()
        )
    }

    // MARK: - Testfall 6: unzureichende Daten -> keine erfundene Aussage

    func testFewerThanMinimumWeeksProducesInsufficientDataNotAConfidentVerdict() {
        let series = [point(0, km: 20)]
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: series[0].weekStart))
        XCTAssertEqual(result.outcome, .insufficientData)
        XCTAssertTrue(result.dataGaps.contains { if case .insufficientHistory = $0 { return true }; return false })
    }

    // MARK: - Testfall 7: fehlende HF-Daten blockieren die uebrige Analyse nicht

    func testMissingHeartRateDataGapDoesNotBlockVolumeOrPaceAssessment() {
        let series = (0..<4).map { point($0, km: 20) }
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: series[0].weekStart))
        XCTAssertTrue(result.dataGaps.contains(.noHeartRateData))
        XCTAssertNotEqual(result.outcome, .insufficientData, "fehlende HF darf die restliche Auswertung nicht blockieren")
    }

    // MARK: - Testfall 4: steigender Wochenumfang wird erkannt

    func testLoadIncreaseOver25PercentOverThreeWeeksRaisesConcern() {
        let series = [point(0, km: 20), point(1, km: 23), point(2, km: 26), point(3, km: 28)]
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: series[0].weekStart, currentWeeklyVolumeKm: 28))
        guard case .attentionNeeded(let concerns) = result.outcome else {
            return XCTFail("expected attentionNeeded, got \(result.outcome)")
        }
        XCTAssertTrue(concerns.contains { if case .loadIncreasedTooFast = $0 { return true }; return false })
    }

    // MARK: - Testfall 5: stagnierende Leistungsentwicklung (Plateau) erkannt

    func testFlatVolumeAcrossMinimumWeeksRaisesPlateauConcern() {
        let series = [point(0, km: 20), point(1, km: 20.5), point(2, km: 19.5), point(3, km: 20)]
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: series[0].weekStart))
        guard case .attentionNeeded(let concerns) = result.outcome else {
            return XCTFail("expected attentionNeeded, got \(result.outcome)")
        }
        XCTAssertTrue(concerns.contains { if case .volumePlateau = $0 { return true }; return false })
    }

    // MARK: - Testfall 3: Trainingspause korrekt erkannt

    func testGenuineGapAfterCoachingActivationIsFlaggedAndRaisesConcern() {
        let active = point(0, km: 20)
        let gap1 = point(1, km: 0, runs: 0, cross: 0, ambiguous: 0, strength: 0)
        let gap2 = point(2, km: 0, runs: 0, cross: 0, ambiguous: 0, strength: 0)
        let series = [active, gap1, gap2]
        // gap2 ist eine abgeschlossene historische Woche, nicht die laufende
        // Woche – isCurrentWeekIncomplete: false, damit beide Luecken zaehlen.
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: series[0].weekStart, isCurrentWeekIncomplete: false))
        XCTAssertEqual(result.weeklyFlags[1], .genuineGap)
        XCTAssertEqual(result.weeklyFlags[2], .genuineGap)
        guard case .attentionNeeded(let concerns) = result.outcome else {
            return XCTFail("expected attentionNeeded, got \(result.outcome)")
        }
        XCTAssertTrue(concerns.contains { if case .recentTrainingGap(let weeks) = $0 { return weeks == 2 }; return false })
    }

    // MARK: - Testfall 16: Wochen vor Coaching-Aktivierung nie als Inaktivitaet gewertet

    func testWeeksBeforeCoachingActivationNeverProduceInactivityConcernButStillCountTowardVolumeTrend() {
        let beforeActivation = point(0, km: 0, runs: 0, strength: 0) // z.B. reiner Krafttrainierer vorher
        let afterActivation1 = point(1, km: 20)
        let afterActivation2 = point(2, km: 20)
        let series = [beforeActivation, afterActivation1, afterActivation2]
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: afterActivation1.weekStart))
        XCTAssertEqual(result.weeklyFlags[0], .beforeCoachingObservationPeriod)
        // Keine Gap-Concern, da Woche 0 ausserhalb des Beobachtungszeitraums liegt.
        if case .attentionNeeded(let concerns) = result.outcome {
            XCTAssertFalse(concerns.contains { if case .recentTrainingGap = $0 { return true }; return false })
        }
    }

    // MARK: - Testfall 17/18/19: Wochen-Klassifikation

    func testStrengthOnlyWeekIsFlaggedNotAsGenuineGap() {
        let series = [point(0, km: 20), point(1, km: 0, runs: 0, strength: 3), point(2, km: 20)]
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: series[0].weekStart))
        XCTAssertEqual(result.weeklyFlags[1], .strengthOnlyWeek)
    }

    func testCyclingOnlyWeekIsFlaggedAsCrossTrainingNotGap() {
        let series = [point(0, km: 20), point(1, km: 0, runs: 0, cross: 2, strength: 0), point(2, km: 20)]
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: series[0].weekStart))
        XCTAssertEqual(result.weeklyFlags[1], .crossTrainingOnlyWeek)
    }

    func testAmbiguousActivityWeekIsFlaggedDistinctlyAndSurfacedAsDataGap() {
        let series = [point(0, km: 20), point(1, km: 0, runs: 0, ambiguous: 1, strength: 0), point(2, km: 20)]
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: series[0].weekStart))
        XCTAssertEqual(result.weeklyFlags[1], .ambiguousActivityWeek)
        XCTAssertTrue(result.dataGaps.contains { if case .ambiguousActivityPresent(let count) = $0 { return count == 1 }; return false })
    }

    // MARK: - Testfall 8: Zielwechsel -> Neubewertung der gesamten Historie

    func testGoalChangeReassessesEntireHistoryAgainstNewGoalWithoutDiscardingIt() {
        let series = (0..<6).map { point($0, km: 20) }
        let halfMarathonResult = RaceProgressAssessment.assess(
            input(series: series, goal: .halfMarathon, observationStart: series[0].weekStart, currentWeeklyVolumeKm: 20)
        )
        let marathonResult = RaceProgressAssessment.assess(
            input(series: series, goal: .marathon, raceDate: series.last!.weekStart.addingTimeInterval(60 * 86400), observationStart: series[0].weekStart, currentWeeklyVolumeKm: 20)
        )
        // Gleiche Historie (series) fliesst in BEIDE Bewertungen vollstaendig ein -
        // kein Datenverlust durch den Zielwechsel.
        XCTAssertEqual(halfMarathonResult.weeklyFlags.count, series.count)
        XCTAssertEqual(marathonResult.weeklyFlags.count, series.count)
        // Marathon in 60 Tagen bei 20km/Woche ist nicht erreichbar -> eigener Concern,
        // egal ob das Gesamturteil attentionNeeded oder offTrack lautet.
        let marathonConcerns: [RaceProgressAssessment.Concern]
        switch marathonResult.outcome {
        case .attentionNeeded(let c): marathonConcerns = c
        case .offTrack(let c): marathonConcerns = c
        default: return XCTFail("expected a concern-bearing outcome, got \(marathonResult.outcome)")
        }
        XCTAssertTrue(marathonConcerns.contains { if case .goalLikelyUnrealistic = $0 { return true }; return false })
    }

    // MARK: - coachingObservationStart unbekannt -> nie eine Inaktivitaets-Warnung

    func testUnknownCoachingObservationStartSuppressesAllPeriodBasedConcerns() {
        let series = [point(0, km: 0, runs: 0, strength: 0), point(1, km: 0, runs: 0, strength: 0), point(2, km: 0, runs: 0, strength: 0)]
        let result = RaceProgressAssessment.assess(input(series: series, observationStart: nil))
        XCTAssertTrue(result.weeklyFlags.allSatisfy { $0 == .beforeCoachingObservationPeriod })
        XCTAssertTrue(result.dataGaps.contains(.coachingObservationStartUnknown))
        if case .attentionNeeded(let concerns) = result.outcome {
            XCTAssertFalse(concerns.contains { if case .recentTrainingGap = $0 { return true }; return false })
        }
    }
}
