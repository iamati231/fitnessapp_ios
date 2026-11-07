// AI-Running-Coach Phase 1 (docs/superpowers/plans/
// 2026-11-06-ai-running-coach-phase1-implementation.md, Abschnitt 3): reiner
// Orchestrator, Vorbild `FourWeekReviewOrchestrator` - nimmt bereits
// berechnete Signale entgegen, erfindet keine eigene Trainingslogik, hat
// bewusst KEINE "apply"-Methode. Keine SwiftData-Abhaengigkeit, kein
// `Date()`/`Calendar.current` im Code-Pfad - alles injiziert.

import Foundation

public enum RaceProgressAssessment {

    // MARK: - Input

    public struct Input: Sendable, Equatable {
        /// Die GESAMTE verfuegbare Lauf-Wochenserie, nicht nur ein
        /// Ausschnitt - ein Zielwechsel bewertet dieselbe Serie neu, verwirft
        /// nie Historie (Design-Dokument Regel 1/4).
        public let weeklySeries: [CardioVolumeOverTimePoint]
        public let goal: CardioGoal
        public let raceDate: Date?
        /// `nil` = Beobachtungsbeginn unbekannt - siehe `WeeklyFlag`-Doku,
        /// Decision 2: dann wird JEDE Woche konservativ als
        /// `.beforeCoachingObservationPeriod` behandelt.
        public let coachingObservationStart: Date?
        /// Vom Aufrufer FRISCH aus `weeklySeries` berechnet - NIEMALS
        /// `UserBodyProfile.weeklyBaseVolumeKm` (siehe Implementierungsplan
        /// Abschnitt 4, "Schutz vor stale Werten"). Diese Funktion selbst
        /// kennt `UserBodyProfile` nicht einmal.
        public let currentWeeklyVolumeKm: Double?
        /// true wenn das letzte Element in `weeklySeries` die aktuelle, noch
        /// nicht abgeschlossene Kalenderwoche repraesentiert. Immer true wenn
        /// Daten aus `CardioVolumeOverTimeAggregator.aggregate()` stammen
        /// (loop-Invariante). Verhindert, dass eine leere laufende Woche
        /// faelschlich als zweite abgeschlossene Gap-Woche zaehlt.
        public let isCurrentWeekIncomplete: Bool
        public let now: Date

        public init(
            weeklySeries: [CardioVolumeOverTimePoint],
            goal: CardioGoal,
            raceDate: Date?,
            coachingObservationStart: Date?,
            currentWeeklyVolumeKm: Double?,
            isCurrentWeekIncomplete: Bool = true,
            now: Date
        ) {
            self.weeklySeries = weeklySeries
            self.goal = goal
            self.raceDate = raceDate
            self.coachingObservationStart = coachingObservationStart
            self.currentWeeklyVolumeKm = currentWeeklyVolumeKm
            self.isCurrentWeekIncomplete = isCurrentWeekIncomplete
            self.now = now
        }
    }

    // MARK: - Per-Woche-Klassifikation

    /// `nil` = ganz normale, aktive Lauf-Woche innerhalb des
    /// Beobachtungszeitraums - kein Befund. Jeder andere Fall ist einer von
    /// fuenf disjunkten, nie geratenen Gruenden (siehe Design-Dokument,
    /// "Entschieden: cardioCoachingEnabledAt markiert den Beobachtungs-
    /// Zeitraum"). Eine Lauf-Plateau-/Inaktivitaets-WARNUNG (`Concern.
    /// recentTrainingGap`) entsteht ausschliesslich aus `.genuineGap`-Wochen
    /// INNERHALB des Beobachtungszeitraums.
    public enum WeeklyFlag: Sendable, Equatable {
        case beforeCoachingObservationPeriod
        case strengthOnlyWeek
        case crossTrainingOnlyWeek
        case ambiguousActivityWeek
        case genuineGap
    }

    // MARK: - Output

    public enum Concern: Sendable, Equatable {
        case loadIncreasedTooFast(percentOverLastNWeeks: Double, weeks: Int)
        case insufficientRecovery(consecutiveHighLoadWeeks: Int)
        case volumePlateau(weeks: Int)
        case goalLikelyUnrealistic(CardioFeasibilityCalculator.Result)
        /// Ticket-Testfall 3 ("Trainingspause korrekt erkannt") - entsteht
        /// NUR aus `.genuineGap`-Wochen, nie aus vor der Coaching-Aktivierung
        /// liegenden oder bekannten Nicht-Lauf-Wochen.
        case recentTrainingGap(consecutiveWeeks: Int)
    }

    public enum DataGap: Sendable, Equatable {
        case insufficientHistory(weeksAvailable: Int, weeksNeeded: Int)
        /// Phase 1 hat keine Herzfrequenz-Datenquelle - wird IMMER gemeldet,
        /// sobald ueberhaupt Wochen vorliegen (Ticket-Testfall 7: blockiert
        /// die uebrige Auswertung nicht).
        case noHeartRateData
        case coachingObservationStartUnknown
        case ambiguousActivityPresent(weekCount: Int)
    }

    public enum Outcome: Sendable, Equatable {
        case onTrack
        case attentionNeeded([Concern])
        case offTrack([Concern])
        /// Ticket-Testfall 6: zu wenig Historie fuer ein Urteil - wird NIE
        /// durch `.onTrack` ersetzt, auch wenn zufaellig keine Concerns
        /// berechnet werden konnten.
        case insufficientData
    }

    public struct Assessment: Sendable, Equatable {
        public let outcome: Outcome
        public let dataGaps: [DataGap]
        /// Parallel zu `Input.weeklySeries` (gleicher Index).
        public let weeklyFlags: [WeeklyFlag?]

        public init(outcome: Outcome, dataGaps: [DataGap], weeklyFlags: [WeeklyFlag?]) {
            self.outcome = outcome
            self.dataGaps = dataGaps
            self.weeklyFlags = weeklyFlags
        }
    }

    // MARK: - Produktregeln (ausdruecklich vorlaeufig, keine wissenschaftliche
    // Herleitung - gleiches Prinzip wie `FourWeekReviewOrchestrator.
    // significantMissedRatioThreshold`/`CardioFeasibilityCalculator.
    // maxWeeklyRampPercent`, bei echtem Nutzerfeedback anpassbar)

    /// Unterhalb dieser Wochenzahl ist JEDES Urteil (auch `.onTrack`) eine
    /// erfundene Aussage - `Outcome.insufficientData` statt eines Verdikts.
    public static let minimumWeeksForVerdict = 2
    /// Fenstergroesse (Anzahl Wochenpunkte) fuer die Belastungssteigerungs-
    /// und Plateau-Pruefung.
    public static let trendWindowPoints = 4
    /// Mehr als 25% Zuwachs ueber `trendWindowPoints - 1` Wochen gilt als zu
    /// schnell - lose an der bestehenden 10%/Woche-Rampenregel verankert
    /// (`CardioFeasibilityCalculator.maxWeeklyRampPercent`): drei Wochen
    /// MIT Rampe waeren ~33%, 25% ist ein Fruehwarn-Wert knapp darunter.
    public static let loadIncreaseThreshold = 0.25
    /// Innerhalb von +/-5% des Fenster-Mittels gilt als "kein Fortschritt".
    public static let plateauBandPercent = 0.05
    /// Mindestanzahl durchgehend nicht-fallender Wochen fuer einen
    /// Regenerations-Hinweis.
    public static let minimumConsecutiveHighLoadWeeksForRecoveryConcern = 3
    /// Ab zwei durchgehenden echten Luecken-Wochen gilt eine Pause als
    /// eigenstaendiger Befund (nicht schon bei einer einzelnen verpassten
    /// Woche - sonst waere jede Analyse ein Vorwurf).
    public static let minimumConsecutiveGapWeeksForConcern = 2
    /// Ab dieser Luecken-Laenge gilt das Gesamturteil als `.offTrack`, nicht
    /// nur `.attentionNeeded`.
    public static let offTrackGapWeeksThreshold = 3

    // MARK: - Bewertung

    public static func assess(_ input: Input) -> Assessment {
        let flags = input.weeklySeries.map { flag(for: $0, observationStart: input.coachingObservationStart) }

        var dataGaps: [DataGap] = []
        if !input.weeklySeries.isEmpty {
            dataGaps.append(.noHeartRateData)
        }
        if input.coachingObservationStart == nil {
            dataGaps.append(.coachingObservationStartUnknown)
        }
        let ambiguousWeekCount = flags.filter { $0 == .ambiguousActivityWeek }.count
        if ambiguousWeekCount > 0 {
            dataGaps.append(.ambiguousActivityPresent(weekCount: ambiguousWeekCount))
        }

        guard input.weeklySeries.count >= minimumWeeksForVerdict else {
            dataGaps.append(.insufficientHistory(weeksAvailable: input.weeklySeries.count, weeksNeeded: minimumWeeksForVerdict))
            return Assessment(outcome: .insufficientData, dataGaps: dataGaps, weeklyFlags: flags)
        }

        var concerns: [Concern] = []
        if let loadConcern = checkLoadIncrease(input.weeklySeries) { concerns.append(loadConcern) }
        if let recoveryConcern = checkRecovery(input.weeklySeries) { concerns.append(recoveryConcern) }
        if let plateauConcern = checkPlateau(input.weeklySeries) { concerns.append(plateauConcern) }
        if let feasibility = CardioFeasibilityCalculator.evaluate(
            goal: input.goal, raceDate: input.raceDate, weeklyBaseVolumeKm: input.currentWeeklyVolumeKm, today: input.now
        ), feasibility.feasible == false {
            concerns.append(.goalLikelyUnrealistic(feasibility))
        }
        // Aktuelle (unvollstaendige) Woche aus Gap-Streak ausschliessen,
        // damit eine leere laufende Woche nicht als zweite abgeschlossene
        // Gap-Woche zaehlt (spec §10 "Problem A").
        let flagsForStreak: [WeeklyFlag?]
        if input.isCurrentWeekIncomplete && flags.last == .genuineGap {
            flagsForStreak = Array(flags.dropLast())
        } else {
            flagsForStreak = flags
        }
        let trailingGapStreak = trailingGenuineGapStreak(flagsForStreak)
        if trailingGapStreak >= minimumConsecutiveGapWeeksForConcern {
            concerns.append(.recentTrainingGap(consecutiveWeeks: trailingGapStreak))
        }

        let outcome: Outcome
        if concerns.isEmpty {
            outcome = .onTrack
        } else {
            let isOffTrack = concerns.contains { if case .goalLikelyUnrealistic = $0 { return true }; return false }
                || trailingGapStreak >= offTrackGapWeeksThreshold
            outcome = isOffTrack ? .offTrack(concerns) : .attentionNeeded(concerns)
        }

        return Assessment(outcome: outcome, dataGaps: dataGaps, weeklyFlags: flags)
    }

    // MARK: - Private

    private static func flag(for point: CardioVolumeOverTimePoint, observationStart: Date?) -> WeeklyFlag? {
        guard let observationStart else { return .beforeCoachingObservationPeriod }
        if point.weekStart < observationStart { return .beforeCoachingObservationPeriod }
        if point.runningSessionCount > 0 { return nil }
        if point.crossTrainingSessionCount > 0 { return .crossTrainingOnlyWeek }
        if point.strengthSessionCount > 0 { return .strengthOnlyWeek }
        if point.ambiguousCardioSessionCount > 0 { return .ambiguousActivityWeek }
        return .genuineGap
    }

    private static func trailingGenuineGapStreak(_ flags: [WeeklyFlag?]) -> Int {
        var streak = 0
        for flag in flags.reversed() {
            guard flag == .genuineGap else { break }
            streak += 1
        }
        return streak
    }

    private static func checkLoadIncrease(_ series: [CardioVolumeOverTimePoint]) -> Concern? {
        guard series.count >= trendWindowPoints else { return nil }
        let window = series.suffix(trendWindowPoints)
        let first = window.first!.runningDistanceKm
        let last = window.last!.runningDistanceKm
        guard first > 0 else { return nil }
        let change = (last - first) / first
        guard change > loadIncreaseThreshold else { return nil }
        return .loadIncreasedTooFast(percentOverLastNWeeks: change, weeks: trendWindowPoints - 1)
    }

    private static func checkPlateau(_ series: [CardioVolumeOverTimePoint]) -> Concern? {
        guard series.count >= trendWindowPoints else { return nil }
        let window = series.suffix(trendWindowPoints).map(\.runningDistanceKm)
        let average = window.reduce(0, +) / Double(window.count)
        guard average > 0 else { return nil }
        let band = average * plateauBandPercent
        guard window.allSatisfy({ abs($0 - average) <= band }) else { return nil }
        return .volumePlateau(weeks: trendWindowPoints)
    }

    private static func checkRecovery(_ series: [CardioVolumeOverTimePoint]) -> Concern? {
        guard series.count >= minimumConsecutiveHighLoadWeeksForRecoveryConcern,
              series.last!.runningDistanceKm > 0
        else { return nil }
        var streak = 1
        var index = series.count - 1
        while index > 0, series[index].runningDistanceKm >= series[index - 1].runningDistanceKm, series[index - 1].runningDistanceKm > 0 {
            streak += 1
            index -= 1
        }
        guard streak >= minimumConsecutiveHighLoadWeeksForRecoveryConcern else { return nil }
        return .insufficientRecovery(consecutiveHighLoadWeeks: streak)
    }
}
