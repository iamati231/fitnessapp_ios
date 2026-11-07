#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import DeltiqCore
import DeltiqData

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/2026-11-06-ai-running-coach-phase1-implementation.md,
/// Abschnitt 3): verbindet `CardioHistoryExtractor` -> `CardioVolumeOverTimeAggregator`
/// -> `RaceProgressAssessment` zu einem Dashboard-Karten-Modell, Vorbild
/// `CoachAdjustmentCardModel`. Rein lesend - KEIN Schreibzugriff auf
/// `TrainingPlan`/`TrainingDay`, nirgends in diesem Typ.
@available(iOS 17.0, macOS 14.0, *)
public struct RaceProgressCardModel: Equatable {
    /// Parallel zu `assessment.weeklyFlags` (gleicher Index) - die
    /// tatsaechlich ausgewerteten Rohdaten, fuer die Detailansicht
    /// ("welche Daten wurden ausgewertet?", Ticket Abschnitt 9).
    public let weeklySeries: [CardioVolumeOverTimePoint]
    public let assessment: RaceProgressAssessment.Assessment
    public let dueState: RaceProgressDueCalculator.State
    /// Ziel+Renndatum-Fingerprint - identifiziert, FUER WELCHE Konfiguration
    /// diese Bewertung gilt (fuer `RaceProgressDueCalculator`).
    public let configurationFingerprint: String
    /// Konfiguration + Outcome - identifiziert, ob die GEZEIGTE Aussage sich
    /// seit dem letzten "Nicht jetzt" veraendert hat (fuer die Karten-
    /// Sichtbarkeit). Bewusst ein ANDERER Fingerprint als
    /// `configurationFingerprint`: ein Dismiss soll nicht dauerhaft gelten,
    /// wenn sich das Urteil durch neue Trainingsdaten aendert, auch ohne
    /// Ziel-/Renndatum-Wechsel.
    public let dismissalFingerprint: String
    /// Running Coach - Herzfrequenz-Trainingszonen: trennt die aus der
    /// manuell hinterlegten HFmax berechneten Zonen von einer tatsaechlich
    /// gemessenen Trainingsherzfrequenz (siehe `HeartRateZoneContextBuilder`-
    /// Doku) - niemals eine erfundene Durchschnittsherzfrequenz.
    public let heartRateZoneContext: HeartRateZoneDisplayState

    /// `nil`, wenn der Coach nicht aktiv ist (Leitplanke: identischer Vertrag
    /// wie `CoachAdjustmentCardModel.make`).
    public static func make(for profile: UserBodyProfile, allSessions: [WorkoutSession], now: Date = Date()) -> RaceProgressCardModel? {
        guard profile.cardioCoachingEnabled else { return nil }

        let loggedSessions = CardioHistoryExtractor.loggedSessions(from: allSessions)
        // Design-Dokument Regel 1: die GESAMTE verfuegbare Laufhistorie
        // fliesst in die Trend-Metriken ein - das Aggregations-Fenster
        // beginnt daher beim fruehesten geloggten Datum, NICHT erst bei
        // `cardioCoachingEnabledAt` (das grenzt nur die Warnungen ein, siehe
        // `RaceProgressAssessment.WeeklyFlag`-Doku).
        let windowStart = loggedSessions.map(\.date).min() ?? (profile.cardioCoachingEnabledAt ?? now)
        let series = CardioVolumeOverTimeAggregator.aggregate(sessions: loggedSessions, windowStart: windowStart, now: now)
        let currentWeeklyVolumeKm = Self.currentWeeklyVolume(from: series)
        let configurationFingerprint = Self.makeConfigurationFingerprint(goal: profile.cardioGoal, raceDate: profile.cardioRaceDate)
        // Letzte Woche in `series` ist immer die laufende Kalenderwoche
        // (CardioVolumeOverTimeAggregator-loop-Invariante). Das letzte Element
        // stammt per Definition aus der aktuellen, noch nicht abgeschlossenen
        // Woche, es sei denn, die Serie ist leer.
        let isCurrentWeekIncomplete = !series.isEmpty

        let assessment = RaceProgressAssessment.assess(.init(
            weeklySeries: series,
            goal: profile.cardioGoal,
            raceDate: profile.cardioRaceDate,
            coachingObservationStart: profile.cardioCoachingEnabledAt,
            currentWeeklyVolumeKm: currentWeeklyVolumeKm,
            isCurrentWeekIncomplete: isCurrentWeekIncomplete,
            now: now
        ))

        let dueState = RaceProgressDueCalculator.state(
            lastAnalyzedAt: profile.raceProgressLastAnalyzedAt,
            lastAnalyzedConfigurationFingerprint: profile.raceProgressLastAnalyzedConfigurationFingerprint,
            currentConfigurationFingerprint: configurationFingerprint,
            latestLoggedTrainingDate: loggedSessions.map(\.date).max(),
            now: now
        )

        return RaceProgressCardModel(
            weeklySeries: series,
            assessment: assessment,
            dueState: dueState,
            configurationFingerprint: configurationFingerprint,
            dismissalFingerprint: "\(configurationFingerprint)#\(String(describing: assessment.outcome))",
            heartRateZoneContext: HeartRateZoneContextBuilder.make(
                maxHeartRateBpm: profile.maxHeartRateBpm,
                measuredAverageBpm: Self.mostRecentMeasuredAverageHeartRateBpm(from: series)
            )
        )
    }

    /// Juengster Wochenwert MIT tatsaechlich gemessener Durchschnitts-HF
    /// (`CardioVolumeOverTimePoint.averageHeartRateBpm` - Phase 1 hat dafuer
    /// noch keine Datenquelle, bleibt also heute immer `nil`; die Auswahl-
    /// logik ist bereits bereit fuer eine spaetere Messdatenquelle). Rundet
    /// erst HIER auf einen ganzzahligen bpm-Wert, nie vorher.
    static func mostRecentMeasuredAverageHeartRateBpm(from series: [CardioVolumeOverTimePoint]) -> Int? {
        series.last(where: { $0.averageHeartRateBpm != nil })?.averageHeartRateBpm.map { Int($0.rounded()) }
    }

    /// Implementierungsplan Abschnitt 4 ("Schutz vor stale Werten"): NIE
    /// `UserBodyProfile.weeklyBaseVolumeKm` (einmaliger, nie synchronisierter
    /// Onboarding-Schnappschuss) - stattdessen das Mittel der letzten 2
    /// Wochen MIT tatsaechlich geloggtem Laufumfang aus der echten,
    /// frisch berechneten Wochenserie.
    static func currentWeeklyVolume(from series: [CardioVolumeOverTimePoint]) -> Double? {
        let recentActiveWeeks = series.suffix(2).filter { $0.runningDistanceKm > 0 }
        guard !recentActiveWeeks.isEmpty else { return nil }
        return recentActiveWeeks.map(\.runningDistanceKm).reduce(0, +) / Double(recentActiveWeeks.count)
    }

    static func makeConfigurationFingerprint(goal: CardioGoal, raceDate: Date?) -> String {
        let raceDatePart = raceDate.map { String(Int($0.timeIntervalSince1970)) } ?? "none"
        return "\(goal.rawValue)#\(raceDatePart)"
    }

    /// "Nicht jetzt" - setzt NUR den Dismiss-Fingerprint, ruehrt Plan/Profil-
    /// Ziel nicht an (identisches Prinzip wie jede andere Dashboard-Karte).
    public func dismiss(profile: UserBodyProfile) {
        profile.raceProgressDismissedFingerprint = dismissalFingerprint
    }

    /// Nach dem Anzeigen aufzurufen - persistiert Zeitpunkt+Konfiguration,
    /// damit `RaceProgressDueCalculator` einen erneuten App-Start/Doppeltap
    /// nicht als weiterhin faellig meldet. Reiner Lese-zu-Schreib-Uebergang
    /// auf `UserBodyProfile`-Feldern - RUEHRT `TrainingPlan`/`TrainingDay`
    /// NIE an.
    @MainActor
    public func recordAnalysisShown(for profile: UserBodyProfile, in context: ModelContext, now: Date = Date()) {
        RaceProgressDueCalculator.recordAnalysisCompleted(
            for: profile, configurationFingerprint: configurationFingerprint, now: now, in: context
        )
    }
}
#endif
