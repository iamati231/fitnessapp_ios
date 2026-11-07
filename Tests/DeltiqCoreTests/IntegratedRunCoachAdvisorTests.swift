import XCTest
import Foundation
@testable import DeltiqCore

final class IntegratedRunCoachAdvisorTests: XCTestCase {

    // MARK: - Prio 1: Unzureichende Lastdaten

    func testPrio1_nilLoadTrend_returnsInsufficientData() {
        let result = assess(loadTrend: nil)
        XCTAssertEqual(result.primaryAction, .insufficientData)
        XCTAssertEqual(result.rationale, .shortHistory)
    }

    func testPrio1_insufficientDataCompleteness_returnsInsufficientData() {
        let trend = makeTrend(dataCompleteness: .insufficient(reasons: [
            .shortHistory(weeksAvailable: 1, weeksNeeded: 3),
            .durationDataUnavailable
        ]))
        let result = assess(loadTrend: trend)
        XCTAssertEqual(result.primaryAction, .insufficientData)
        XCTAssertEqual(result.rationale, .shortHistory)
    }

    // MARK: - Prio 2: Kein Lauftraining

    func testPrio2_allNonRunningFlags_returnsBuildBase() {
        let flags: [RaceProgressAssessment.WeeklyFlag?] = [
            .genuineGap, .genuineGap, .genuineGap, .genuineGap
        ]
        let rp = makeAssessment(outcome: .insufficientData, weeklyFlags: flags)
        let result = assess(raceProgress: rp)
        XCTAssertEqual(result.primaryAction, .buildRunningBase)
        XCTAssertEqual(result.rationale, .noRunningData)
    }

    func testPrio2_mixedWithRunningFlag_doesNotFire() {
        // nil = running week, so prio 2 should NOT fire
        let flags: [RaceProgressAssessment.WeeklyFlag?] = [
            .genuineGap, nil, .genuineGap, .genuineGap
        ]
        let rp = makeAssessment(outcome: .onTrack, weeklyFlags: flags)
        let result = assess(raceProgress: rp)
        XCTAssertNotEqual(result.primaryAction, .buildRunningBase)
    }

    func testPrio2_emptyEvaluated_doesNotFire() {
        // All flags are beforeCoachingObservationPeriod → evaluated is empty
        let flags: [RaceProgressAssessment.WeeklyFlag?] = [
            .beforeCoachingObservationPeriod, .beforeCoachingObservationPeriod
        ]
        let rp = makeAssessment(outcome: .onTrack, weeklyFlags: flags)
        let result = assess(raceProgress: rp)
        XCTAssertNotEqual(result.primaryAction, .buildRunningBase)
    }

    // MARK: - Prio 3: Ueberwiegend Cross-Training

    func testPrio3_threeCrossTrainingWeeks_returnsBuildBase() {
        let flags: [RaceProgressAssessment.WeeklyFlag?] = [
            .crossTrainingOnlyWeek, .crossTrainingOnlyWeek, .crossTrainingOnlyWeek, nil
        ]
        let rp = makeAssessment(outcome: .onTrack, weeklyFlags: flags)
        let result = assess(raceProgress: rp)
        XCTAssertEqual(result.primaryAction, .buildRunningBase)
        XCTAssertEqual(result.rationale, .crossTrainingOnly)
    }

    func testPrio3_twoCrossTrainingWeeks_doesNotFire() {
        let flags: [RaceProgressAssessment.WeeklyFlag?] = [
            .crossTrainingOnlyWeek, .crossTrainingOnlyWeek, nil, nil
        ]
        let rp = makeAssessment(outcome: .onTrack, weeklyFlags: flags)
        let result = assess(raceProgress: rp)
        XCTAssertNotEqual(result.rationale, .crossTrainingOnly)
    }

    // MARK: - Prio 4: Plananpassung ausstehend

    func testPrio4_planAdjustmentPending_returnsPlanAdjustmentAvailable() {
        let result = assess(planAdjustmentPending: true)
        XCTAssertEqual(result.primaryAction, .planAdjustmentAvailable)
        XCTAssertEqual(result.rationale, .planJustAdjusted)
    }

    func testPrio4_planAdjustmentNotPending_doesNotFire() {
        let result = assess(planAdjustmentPending: false)
        XCTAssertNotEqual(result.primaryAction, .planAdjustmentAvailable)
    }

    // MARK: - Prio 5: Ziel wahrscheinlich nicht erreichbar

    func testPrio5_goalUnreachable_returnsReassessGoal() {
        let feasibility = CardioFeasibilityCalculator.Result(
            feasible: false, weeksNeeded: 20, weeksAvailable: 4, suggestedGoal: nil
        )
        let rp = makeAssessment(outcome: .offTrack([.goalLikelyUnrealistic(feasibility)]))
        let result = assess(raceProgress: rp)
        XCTAssertEqual(result.primaryAction, .reassessGoal)
        XCTAssertEqual(result.rationale, .goalLikelyUnreachable)
    }

    // MARK: - Prio 6a: Trainingspause, Rennen ≤ 14 Tage

    func testPrio6a_gapWithRaceIn14Days_returnsMaintainCurrent() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: 14)
        XCTAssertEqual(result.primaryAction, .maintainCurrent)
        XCTAssertEqual(result.rationale, .recentGapDetected)
    }

    func testPrio6a_gapWithRaceIn0Days_returnsMaintainCurrent() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: 0)
        XCTAssertEqual(result.primaryAction, .maintainCurrent)
        XCTAssertEqual(result.rationale, .recentGapDetected)
    }

    func testPrio6a_gapWithRaceIn1Day_returnsMaintainCurrent() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: 1)
        XCTAssertEqual(result.primaryAction, .maintainCurrent)
    }

    func testPrio6a_gapWithRaceIn7Days_returnsMaintainCurrent() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: 7)
        XCTAssertEqual(result.primaryAction, .maintainCurrent)
    }

    func testPrio6a_gapWithRaceIn13Days_returnsMaintainCurrent() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: 13)
        XCTAssertEqual(result.primaryAction, .maintainCurrent)
    }

    // MARK: - Prio 6b: Trainingspause, kein nahes Rennen

    func testPrio6b_gapWithRaceIn15Days_returnsBuildBase() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: 15)
        XCTAssertEqual(result.primaryAction, .buildRunningBase)
        XCTAssertEqual(result.rationale, .recentGapDetected)
    }

    func testPrio6b_gapWithRaceIn20Days_returnsBuildBase() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: 20)
        XCTAssertEqual(result.primaryAction, .buildRunningBase)
    }

    func testPrio6b_gapWithRaceIn21Days_returnsBuildBase() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: 21)
        XCTAssertEqual(result.primaryAction, .buildRunningBase)
    }

    func testPrio6b_gapWithNilDaysToRace_returnsBuildBase() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: nil)
        XCTAssertEqual(result.primaryAction, .buildRunningBase)
        XCTAssertEqual(result.rationale, .recentGapDetected)
    }

    // MARK: - Prio 7: Erholung unzureichend

    func testPrio7_insufficientRecovery_returnsReduceLoad() {
        let rp = makeAssessment(outcome: .attentionNeeded([.insufficientRecovery(consecutiveHighLoadWeeks: 3)]))
        let result = assess(raceProgress: rp)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .recoveryNeeded)
    }

    // MARK: - Prio 8: Belastung zu schnell gestiegen

    func testPrio8_loadIncreasedTooFast_returnsReduceLoad() {
        let rp = makeAssessment(outcome: .attentionNeeded([.loadIncreasedTooFast(percentOverLastNWeeks: 0.30, weeks: 3)]))
        let result = assess(raceProgress: rp)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .positiveProgressHighLoad)
    }

    func testPrio8_significantLoadIncrease_returnsReduceLoad() {
        let trend = makeTrend(loadDevelopment: .significantIncrease(disciplines: [.running], percent: 0.60))
        let result = assess(loadTrend: trend)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .positiveProgressHighLoad)
    }

    // MARK: - Prio 9: Volumen-Plateau, Rennen in < 10 Wochen

    func testPrio9_plateauNearRace_returnsIncrease15Percent() {
        let rp = makeAssessment(outcome: .attentionNeeded([.volumePlateau(weeks: 4)]))
        let result = assess(raceProgress: rp, weeksToRace: 8)
        XCTAssertEqual(result.primaryAction, .increaseWeeklyVolume(targetPercent: 0.15))
        XCTAssertEqual(result.rationale, .plateauNearRace(weeksToRace: 8))
    }

    // MARK: - Prio 10: Volumen-Plateau, kein nahes Rennen

    func testPrio10_plateauNoRace_returnsIncrease10Percent() {
        let rp = makeAssessment(outcome: .attentionNeeded([.volumePlateau(weeks: 4)]))
        let result = assess(raceProgress: rp, weeksToRace: nil)
        XCTAssertEqual(result.primaryAction, .increaseWeeklyVolume(targetPercent: 0.10))
        XCTAssertEqual(result.rationale, .plateauNearRace(weeksToRace: 0))
    }

    func testPrio10_plateauRaceIn10Weeks_returnsIncrease10Percent() {
        let rp = makeAssessment(outcome: .attentionNeeded([.volumePlateau(weeks: 4)]))
        let result = assess(raceProgress: rp, weeksToRace: 10)
        XCTAssertEqual(result.primaryAction, .increaseWeeklyVolume(targetPercent: 0.10))
        XCTAssertEqual(result.rationale, .plateauNearRace(weeksToRace: 10))
    }

    // MARK: - Prio 11: Auf Kurs, Belastung stabil oder sinkend

    func testPrio11_onTrackStableLoad_returnsMaintainCurrent() {
        let rp = makeAssessment(outcome: .onTrack)
        let trend = makeTrend(loadDevelopment: .stable)
        let result = assess(raceProgress: rp, loadTrend: trend)
        XCTAssertEqual(result.primaryAction, .maintainCurrent)
        XCTAssertEqual(result.rationale, .positiveProgressStableLoad)
    }

    func testPrio11_onTrackDecliningLoad_returnsMaintainCurrent() {
        let rp = makeAssessment(outcome: .onTrack)
        let trend = makeTrend(loadDevelopment: .declining(disciplines: [.running], percent: -0.10))
        let result = assess(raceProgress: rp, loadTrend: trend)
        XCTAssertEqual(result.primaryAction, .maintainCurrent)
        XCTAssertEqual(result.rationale, .positiveProgressStableLoad)
    }

    // MARK: - Prio 12: Standard-Fallback

    func testPrio12_default_returnsMaintainCurrent() {
        let rp = makeAssessment(outcome: .onTrack)
        let trend = makeTrend(loadDevelopment: .moderateIncrease(disciplines: [.running], percent: 0.30))
        let result = assess(raceProgress: rp, loadTrend: trend)
        XCTAssertEqual(result.primaryAction, .maintainCurrent)
        XCTAssertEqual(result.rationale, .positiveProgressStableLoad)
    }

    // MARK: - Prioritaetsreihenfolge

    func testPriorityOrder_prio4_beats_prio6() {
        // Prio 4 (planAdjustment) schlaegt Prio 6 (gap)
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, planAdjustmentPending: true)
        XCTAssertEqual(result.primaryAction, .planAdjustmentAvailable)
    }

    func testPriorityOrder_prio5_beats_prio6() {
        let feasibility = CardioFeasibilityCalculator.Result(
            feasible: false, weeksNeeded: 20, weeksAvailable: 4, suggestedGoal: nil
        )
        let rp = makeAssessment(outcome: .offTrack([
            .goalLikelyUnrealistic(feasibility),
            .recentTrainingGap(consecutiveWeeks: 2)
        ]))
        let result = assess(raceProgress: rp)
        XCTAssertEqual(result.primaryAction, .reassessGoal)
    }

    // MARK: - DataQualityIssues

    func testDataQuality_durationDataUnavailable_alwaysPresent() {
        // partial completeness mit durationDataUnavailable
        let trend = makeTrend(dataCompleteness: .partial(reasons: [.durationDataUnavailable]))
        let result = assess(loadTrend: trend)
        XCTAssertTrue(result.dataQualityIssues.contains(.durationDataUnavailable))
    }

    func testDataQuality_runningDistanceMissing_mapped() {
        let trend = makeTrend(dataCompleteness: .partial(reasons: [
            .durationDataUnavailable,
            .missingRunningDistance(weeks: 2)
        ]))
        let result = assess(loadTrend: trend)
        XCTAssertTrue(result.dataQualityIssues.contains(.runningDistanceMissing(weekCount: 2)))
    }

    func testDataQuality_ambiguousActivities_mapped() {
        let trend = makeTrend(dataCompleteness: .partial(reasons: [
            .durationDataUnavailable,
            .unknownActivityPresent(weeks: 1)
        ]))
        let result = assess(loadTrend: trend)
        XCTAssertTrue(result.dataQualityIssues.contains(.ambiguousActivitiesPresent(weekCount: 1)))
    }

    func testDataQuality_shortHistory_mapped() {
        let trend = makeTrend(dataCompleteness: .partial(reasons: [
            .durationDataUnavailable,
            .shortHistory(weeksAvailable: 2, weeksNeeded: 3)
        ]))
        let result = assess(loadTrend: trend)
        XCTAssertTrue(result.dataQualityIssues.contains(.historyTooShort(weeksAvailable: 2, weeksNeeded: 3)))
    }

    func testDataQuality_currentWeekIncomplete_notMapped() {
        // currentWeekIncomplete soll NICHT als DataQualityIssue erscheinen
        let trend = makeTrend(dataCompleteness: .partial(reasons: [
            .durationDataUnavailable,
            .currentWeekIncomplete
        ]))
        let result = assess(loadTrend: trend)
        XCTAssertEqual(result.dataQualityIssues, [.durationDataUnavailable])
    }

    // MARK: - Fehlende Eingaben (nil raceProgress)

    func testNilRaceProgress_prio2NotFiredForEmptyFlags() {
        // Kein raceProgress → evaluated ist leer → Prio 2 faellt nicht
        let result = assess(raceProgress: nil)
        XCTAssertNotEqual(result.primaryAction, .insufficientData) // Prio 1 faellt auch nicht (loadTrend vorhanden)
    }

    // MARK: - Determinismus

    func testDeterminism_sameInputSameOutput() {
        let rp = makeAssessment(outcome: .attentionNeeded([.volumePlateau(weeks: 4)]))
        let r1 = assess(raceProgress: rp, weeksToRace: 8)
        let r2 = assess(raceProgress: rp, weeksToRace: 8)
        XCTAssertEqual(r1, r2)
    }

    // MARK: - Prio 6a: Negativer daysToRace darf Prio 6a NICHT ausloesen

    func testPrio6a_negativeDaysToRace_returnsBuildBase() {
        let rp = makeAssessment(outcome: .attentionNeeded([.recentTrainingGap(consecutiveWeeks: 2)]))
        let result = assess(raceProgress: rp, daysToRace: -1)
        XCTAssertEqual(result.primaryAction, .buildRunningBase)
        XCTAssertEqual(result.rationale, .recentGapDetected)
    }

    // MARK: - Prio 7: Dichte-Signale loesen Erholungsempfehlung aus

    func testPrio7_density_highTrainingDensity_triggersReduceLoad() {
        let d = makeDensityAssessment(outcome: .highTrainingDensity)
        let result = assess(densityAssessment: d)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .recoveryNeeded)
    }

    func testPrio7_density_insufficientRecoveryEvidence_triggersReduceLoad() {
        let d = makeDensityAssessment(outcome: .insufficientRecoveryEvidence)
        let result = assess(densityAssessment: d)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .recoveryNeeded)
    }

    func testPrio7_density_deloadIndicatedByExistingSystem_triggersReduceLoad() {
        let d = makeDensityAssessment(outcome: .balanced, concerns: [.deloadIndicatedByExistingSystem])
        let result = assess(densityAssessment: d)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .recoveryNeeded)
    }

    func testPrio7_density_closelySpacedRunningSessions_triggersReduceLoad() {
        let d = makeDensityAssessment(outcome: .balanced, concerns: [.closelySpacedRunningSessions(minimumGapHours: 18)])
        let result = assess(densityAssessment: d)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .recoveryNeeded)
    }

    func testPrio7_density_highConsecutiveTrainingDays_triggersReduceLoad() {
        let d = makeDensityAssessment(outcome: .balanced, concerns: [.highConsecutiveTrainingDays(days: 6)])
        let result = assess(densityAssessment: d)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .recoveryNeeded)
    }

    func testPrio7_density_balanced_doesNotTriggerReduceLoad() {
        let d = makeDensityAssessment(outcome: .balanced)
        let rp = makeAssessment(outcome: .onTrack)
        let result = assess(raceProgress: rp, densityAssessment: d)
        XCTAssertNotEqual(result.primaryAction, .reduceLoadThisWeek)
    }

    func testPrio7_density_insufficientData_doesNotTriggerReduceLoad() {
        let d = makeDensityAssessment(outcome: .insufficientData)
        let rp = makeAssessment(outcome: .onTrack)
        let result = assess(raceProgress: rp, densityAssessment: d)
        XCTAssertNotEqual(result.primaryAction, .reduceLoadThisWeek)
    }

    // MARK: - Prio 8: Disziplin-bewusstes Belastungssignal

    func testPrio8_pureStrengthIncrease_doesNotReduceLoad() {
        let trend = makeTrend(loadDevelopment: .significantIncrease(disciplines: [.strength], percent: 0.70))
        let result = assess(loadTrend: trend)
        XCTAssertNotEqual(result.primaryAction, .reduceLoadThisWeek)
    }

    func testPrio8_pureRunningIncrease_reducesLoad() {
        let trend = makeTrend(loadDevelopment: .significantIncrease(disciplines: [.running], percent: 0.70))
        let result = assess(loadTrend: trend)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .positiveProgressHighLoad)
    }

    func testPrio8_mixedDisciplinesIncrease_reducesLoad() {
        let trend = makeTrend(loadDevelopment: .significantIncrease(disciplines: [.running, .strength], percent: 0.50))
        let result = assess(loadTrend: trend)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .positiveProgressHighLoad)
    }

    func testPrio8_density_increasingLoad_reducesLoad() {
        let d = makeDensityAssessment(outcome: .increasingLoad)
        let result = assess(densityAssessment: d)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .positiveProgressHighLoad)
    }

    // MARK: - Prioritaet: Dichte-Prio7 schlaegt Dichte-Prio8

    func testPriority_densityPrio7_beats_densityPrio8() {
        // highTrainingDensity (→Prio7) sollte vor increasingLoad (→Prio8) feuern
        // Simuliere beide: outcome kann nur eines sein, aber zeige Prio7 gewinnt
        let d = makeDensityAssessment(outcome: .highTrainingDensity)
        let trend = makeTrend(loadDevelopment: .significantIncrease(disciplines: [.running], percent: 0.70))
        let result = assess(loadTrend: trend, densityAssessment: d)
        XCTAssertEqual(result.primaryAction, .reduceLoadThisWeek)
        XCTAssertEqual(result.rationale, .recoveryNeeded) // Prio 7 gewinnt
    }

    // MARK: - DataQualityIssues: Mehrere Quellen, keine Duplikate

    func testDataQuality_raceProgressGap_historyTooShort_mapped() {
        let rp = makeAssessment(dataGaps: [.insufficientHistory(weeksAvailable: 1, weeksNeeded: 2)])
        let result = assess(raceProgress: rp)
        XCTAssertTrue(result.dataQualityIssues.contains(.historyTooShort(weeksAvailable: 1, weeksNeeded: 2)))
    }

    func testDataQuality_raceProgressGap_ambiguousActivity_mapped() {
        let rp = makeAssessment(dataGaps: [.ambiguousActivityPresent(weekCount: 3)])
        let result = assess(raceProgress: rp)
        XCTAssertTrue(result.dataQualityIssues.contains(.ambiguousActivitiesPresent(weekCount: 3)))
    }

    func testDataQuality_density_noMeasuredIntensityData_mapsToDurationUnavailable() {
        let d = makeDensityAssessment(outcome: .balanced, dataGaps: [.noMeasuredIntensityData])
        let result = assess(densityAssessment: d)
        XCTAssertTrue(result.dataQualityIssues.contains(.durationDataUnavailable))
    }

    func testDataQuality_density_sessionFeelingUnavailable_notMapped() {
        // sessionFeelingUnavailable darf keinen erfundenen RPE-Wert implizieren
        let d = makeDensityAssessment(outcome: .balanced, dataGaps: [.sessionFeelingUnavailable])
        let trend = makeTrend(dataCompleteness: .complete)
        let result = assess(loadTrend: trend, densityAssessment: d)
        XCTAssertTrue(result.dataQualityIssues.isEmpty)
    }

    func testDataQuality_noDuplicates_whenBothSourcesReportSameIssue() {
        // loadTrend + raceProgress melden beide historyTooShort(1,2) → nur einmal
        let trend = makeTrend(dataCompleteness: .partial(reasons: [.shortHistory(weeksAvailable: 1, weeksNeeded: 2)]))
        let rp = makeAssessment(dataGaps: [.insufficientHistory(weeksAvailable: 1, weeksNeeded: 2)])
        let result = assess(raceProgress: rp, loadTrend: trend)
        let count = result.dataQualityIssues.filter {
            if case .historyTooShort(1, 2) = $0 { return true }; return false
        }.count
        XCTAssertEqual(count, 1)
    }

    func testDataQuality_noDuplicates_durationFromLoadTrendAndDensity() {
        // loadTrend meldet durationDataUnavailable, Dichte auch → nur einmal
        let d = makeDensityAssessment(outcome: .balanced, dataGaps: [.noMeasuredIntensityData])
        let trend = makeTrend(dataCompleteness: .partial(reasons: [.durationDataUnavailable]))
        let result = assess(loadTrend: trend, densityAssessment: d)
        let count = result.dataQualityIssues.filter { $0 == .durationDataUnavailable }.count
        XCTAssertEqual(count, 1)
    }

    // MARK: - RPE / Intensitaetsdaten fehlen (pruefe dataQualityIssues)

    func testMissingDuration_dataQualityIssuePresent() {
        let trend = makeTrend(dataCompleteness: .partial(reasons: [.durationDataUnavailable]))
        let result = assess(loadTrend: trend)
        XCTAssertTrue(result.dataQualityIssues.contains(.durationDataUnavailable))
    }

    // MARK: - Helpers

    private func assess(
        raceProgress: RaceProgressAssessment.Assessment? = nil,
        loadTrend: TrainingLoadTrend? = nil,
        densityAssessment: TrainingDensityAnalyzer.Assessment? = nil,
        weeksToRace: Int? = nil,
        daysToRace: Int? = nil,
        planAdjustmentPending: Bool = false
    ) -> IntegratedCoachingOutcome {
        IntegratedRunCoachAdvisor.assess(
            raceProgress: raceProgress,
            loadTrend: loadTrend ?? makeDefaultTrend(),
            densityAssessment: densityAssessment,
            weeksToRace: weeksToRace,
            daysToRace: daysToRace,
            planAdjustmentPending: planAdjustmentPending
        )
    }

    private func makeDefaultTrend() -> TrainingLoadTrend {
        makeTrend(loadDevelopment: .stable, dataCompleteness: .partial(reasons: [.durationDataUnavailable]))
    }

    private func makeTrend(
        loadDevelopment: LoadDevelopment = .stable,
        dataCompleteness: TrainingLoadDataCompleteness = .partial(reasons: [.durationDataUnavailable])
    ) -> TrainingLoadTrend {
        let m = makeMetricTrend()
        return TrainingLoadTrend(
            analyzedWeeks: [],
            currentWeek: nil,
            isCurrentWeekComplete: false,
            running: RunningLoadTrend(weeklyDistanceKm: m, weeklySessionCount: m),
            strength: StrengthLoadTrend(weeklySessionCount: m, weeklySetCount: m, weeklyVolumeKg: m),
            otherEndurance: OtherEnduranceLoadTrend(weeklySessionCount: m),
            overall: OverallTrainingSummary(weeklyAmbiguousSessionCount: m, weeklyTotalDurationSeconds: nil),
            loadDevelopment: loadDevelopment,
            acuteChronicRatio: nil,
            dataCompleteness: dataCompleteness
        )
    }

    private func makeMetricTrend() -> WeeklyMetricTrend {
        WeeklyMetricTrend(
            currentValue: nil, lastCompleteWeekValue: nil, previousWeekValue: nil,
            changeVsPreviousCompleteWeek: nil, previousWeeksAverage: nil,
            changeVsPreviousWeeksAverage: nil, changeOver28Days: nil,
            classification: .insufficientData
        )
    }

    private func makeAssessment(
        outcome: RaceProgressAssessment.Outcome = .onTrack,
        weeklyFlags: [RaceProgressAssessment.WeeklyFlag?] = [],
        dataGaps: [RaceProgressAssessment.DataGap] = []
    ) -> RaceProgressAssessment.Assessment {
        RaceProgressAssessment.Assessment(outcome: outcome, dataGaps: dataGaps, weeklyFlags: weeklyFlags)
    }

    private func makeDensityAssessment(
        outcome: TrainingDensityAnalyzer.Outcome = .balanced,
        concerns: [TrainingDensityAnalyzer.Concern] = [],
        dataGaps: [TrainingDensityAnalyzer.DataGap] = []
    ) -> TrainingDensityAnalyzer.Assessment {
        TrainingDensityAnalyzer.Assessment(
            consecutiveTrainingDays: 0,
            trainingDaysLast7: 0,
            trainingDaysLast14: 0,
            minimumRunningGapHours: nil,
            minimumStrengthGapHours: nil,
            concerns: concerns,
            dataGaps: dataGaps,
            outcome: outcome,
            analyzedPeriodDays: 14,
            analyzedActivityCount: 0
        )
    }
}
