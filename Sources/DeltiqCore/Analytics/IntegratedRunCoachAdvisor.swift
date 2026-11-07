import Foundation

/// Phase 3 WP-A: Deterministische Priorisierungsfunktion, die Race-Progress-,
/// Trainingsbelastungs- und Dichte-Signale zu EINEM Coaching-Urteil zusammen-
/// fasst. Reine Funktion: kein State, kein SwiftData, kein Date().
///
/// Prioritaetsreihenfolge 1–12 ist verbindlich und getestet; keine Empfehlung
/// wird zweimal ausgegeben (kein doppeltes Reduktionssignal).
public enum IntegratedRunCoachAdvisor {

    public static func assess(
        raceProgress: RaceProgressAssessment.Assessment?,
        loadTrend: TrainingLoadTrend?,
        densityAssessment: TrainingDensityAnalyzer.Assessment?,
        weeksToRace: Int?,
        daysToRace: Int?,
        planAdjustmentPending: Bool
    ) -> IntegratedCoachingOutcome {
        let issues = collectDataQualityIssues(
            from: loadTrend,
            raceProgress: raceProgress,
            densityAssessment: densityAssessment
        )

        func out(_ action: CoachingAction, _ rationale: CoachingRationale) -> IntegratedCoachingOutcome {
            IntegratedCoachingOutcome(primaryAction: action, rationale: rationale, dataQualityIssues: issues)
        }

        // Prio 1 — Zu wenig Lastdaten fuer ein Urteil
        guard let loadTrend else {
            return out(.insufficientData, .shortHistory)
        }
        if case .insufficient = loadTrend.dataCompleteness {
            return out(.insufficientData, .shortHistory)
        }

        // Ausgewertete Wochen: letzte 4 innerhalb des Beobachtungszeitraums
        let evaluated = (raceProgress?.weeklyFlags ?? [])
            .filter { $0 != .beforeCoachingObservationPeriod }
            .suffix(4)

        // Prio 2 — Kein Lauftraining in den ausgewerteten Wochen
        if !evaluated.isEmpty && evaluated.allSatisfy({ $0 != nil }) {
            return out(.buildRunningBase, .noRunningData)
        }

        // Prio 3 — Ueberwiegend Cross-Training statt Laufen
        if evaluated.filter({ $0 == .crossTrainingOnlyWeek }).count >= 3 {
            return out(.buildRunningBase, .crossTrainingOnly)
        }

        // Prio 4 — Plananpassung haengt zur Bestaetigung aus
        if planAdjustmentPending {
            return out(.planAdjustmentAvailable, .planJustAdjusted)
        }

        // Concerns aus dem Race-Progress-Urteil
        let concerns: [RaceProgressAssessment.Concern]
        switch raceProgress?.outcome {
        case .attentionNeeded(let c): concerns = c
        case .offTrack(let c): concerns = c
        default: concerns = []
        }

        let loadDev = loadTrend.loadDevelopment

        // Prio 5 — Ziel wahrscheinlich nicht erreichbar
        if concerns.contains(where: { if case .goalLikelyUnrealistic = $0 { return true }; return false }) {
            return out(.reassessGoal, .goalLikelyUnreachable)
        }

        // Prio 6 — Aktuelle Trainingspause (6a: Renntag 0–14 Tage → halten)
        if concerns.contains(where: { if case .recentTrainingGap = $0 { return true }; return false }) {
            if let days = daysToRace, days >= 0 && days <= 14 {
                return out(.maintainCurrent, .recentGapDetected)
            }
            return out(.buildRunningBase, .recentGapDetected)
        }

        // Prio 7 — Unzureichende Erholung (raceProgress oder Dichte-Signale)
        let rpInsuffRecovery = concerns.contains(where: { if case .insufficientRecovery = $0 { return true }; return false })
        let densityRecovery: Bool = {
            guard let d = densityAssessment else { return false }
            if d.outcome == .highTrainingDensity || d.outcome == .insufficientRecoveryEvidence { return true }
            return d.concerns.contains(where: {
                if case .deloadIndicatedByExistingSystem = $0 { return true }
                if case .closelySpacedRunningSessions = $0 { return true }
                if case .highConsecutiveTrainingDays = $0 { return true }
                return false
            })
        }()
        if rpInsuffRecovery || densityRecovery {
            return out(.reduceLoadThisWeek, .recoveryNeeded)
        }

        // Prio 8 — Belastung zu schnell gestiegen (nur Laufen, nicht reiner Kraft-Zuwachs)
        let tooFast = concerns.contains(where: { if case .loadIncreasedTooFast = $0 { return true }; return false })
        let sigRunningIncrease: Bool = {
            if case .significantIncrease(let disciplines, _) = loadDev {
                return disciplines.contains(.running)
            }
            return false
        }()
        let densityHighLoad = densityAssessment?.outcome == .increasingLoad
        if tooFast || sigRunningIncrease || densityHighLoad {
            return out(.reduceLoadThisWeek, .positiveProgressHighLoad)
        }

        // Prio 9/10 — Volumen-Plateau (9: Renntag < 10 Wochen → staerker erhoehen)
        if concerns.contains(where: { if case .volumePlateau = $0 { return true }; return false }) {
            if let weeks = weeksToRace, weeks < 10 {
                return out(.increaseWeeklyVolume(targetPercent: 0.15), .plateauNearRace(weeksToRace: weeks))
            }
            return out(.increaseWeeklyVolume(targetPercent: 0.10), .plateauNearRace(weeksToRace: weeksToRace ?? 0))
        }

        // Prio 11 — Auf Kurs, Belastung stabil oder ruecklaeufig
        if case .onTrack = raceProgress?.outcome {
            switch loadDev {
            case .stable, .declining:
                return out(.maintainCurrent, .positiveProgressStableLoad)
            default:
                break
            }
        }

        // Prio 12 — Standard-Fallback
        return out(.maintainCurrent, .positiveProgressStableLoad)
    }

    // MARK: - Private

    private static func collectDataQualityIssues(
        from loadTrend: TrainingLoadTrend?,
        raceProgress: RaceProgressAssessment.Assessment?,
        densityAssessment: TrainingDensityAnalyzer.Assessment?
    ) -> [DataQualityIssue] {
        var issues: [DataQualityIssue] = []
        func addIfNew(_ issue: DataQualityIssue) {
            if !issues.contains(issue) { issues.append(issue) }
        }

        // Lasttrend-Vollstaendigkeit
        if let loadTrend {
            let reasons: [TrainingLoadDataCompleteness.Reason]
            switch loadTrend.dataCompleteness {
            case .complete: reasons = []
            case .partial(let r): reasons = r
            case .insufficient(let r): reasons = r
            }
            for reason in reasons {
                switch reason {
                case .shortHistory(let avail, let needed): addIfNew(.historyTooShort(weeksAvailable: avail, weeksNeeded: needed))
                case .currentWeekIncomplete: break
                case .missingRunningDistance(let weeks): addIfNew(.runningDistanceMissing(weekCount: weeks))
                case .unknownActivityPresent(let weeks): addIfNew(.ambiguousActivitiesPresent(weekCount: weeks))
                case .durationDataUnavailable: addIfNew(.durationDataUnavailable)
                }
            }
        }

        // Race-Progress-Datenlücken
        for gap in raceProgress?.dataGaps ?? [] {
            switch gap {
            case .insufficientHistory(let avail, let needed): addIfNew(.historyTooShort(weeksAvailable: avail, weeksNeeded: needed))
            case .ambiguousActivityPresent(let count): addIfNew(.ambiguousActivitiesPresent(weekCount: count))
            case .noHeartRateData, .coachingObservationStartUnknown: break
            }
        }

        // Dichte-Datenlücken (.sessionFeelingUnavailable → kein erfundener RPE)
        for gap in densityAssessment?.dataGaps ?? [] {
            switch gap {
            case .noMeasuredIntensityData: addIfNew(.durationDataUnavailable)
            case .insufficientHistory, .sessionFeelingUnavailable: break
            }
        }

        return issues
    }
}
