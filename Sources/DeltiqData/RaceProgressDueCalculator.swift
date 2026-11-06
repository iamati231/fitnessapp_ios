#if canImport(SwiftData)
import Foundation
import SwiftData

/// AI-Running-Coach Phase 1 (docs/superpowers/plans/
/// 2026-11-06-ai-running-coach-phase1-implementation.md, Abschnitt 3):
/// Faelligkeits-Zustand fuer die naechste `RaceProgressAssessment`-
/// Auswertung, Vorbild `FourWeekReviewDueStatus` - "kein Push, keine
/// garantierte Ausfuehrungszeit, nur eine passive Anzeige beim
/// App-Oeffnen/nach einem ausloesenden Ereignis" (Design-Dokument,
/// Nicht-Ziele).
///
/// Implementierungs-Ruling (Plan-Abweichung, hier dokumentiert): der
/// Plan-Entwurf sah eigene `DueReason`-Faelle fuer `goalChanged`/
/// `raceDateChanged`/`significantVolumeChange` vor, die jeweils einen
/// zusaetzlichen persistierten "letzter bekannter Wert"-Schnappschuss
/// gebraucht haetten. Geloest nach dem bereits etablierten Fingerprint-
/// Muster dieses Repos (wie `cardioPlanAdjustmentFingerprint` etc.):
/// `configurationFingerprint` deckt Ziel UND Renndatum in EINEM Wert ab
/// (`.configurationChanged`), `significantVolumeChange` entfaellt ganz -
/// es ist in der Praxis redundant zu `.newActivitySinceLastAnalysis`
/// (eine signifikante Umfangssteigerung ohne neu geloggte Einheiten ist
/// nicht moeglich), ein eigenes "Umfang beim letzten Check"-Feld waere
/// unbelegter Mehraufwand ohne echten Zusatznutzen.
@MainActor
public enum RaceProgressDueCalculator {

    public enum DueReason: Sendable, Equatable {
        case neverAnalyzed
        /// Ziel ODER Renndatum haben sich seit der letzten Analyse geaendert.
        case configurationChanged
        case newActivitySinceLastAnalysis
        case periodicIntervalElapsed
    }

    public enum State: Sendable, Equatable {
        case due(reasons: [DueReason])
        case notYetDue(nextCheckAt: Date)
    }

    /// Produktregel, keine wissenschaftliche Schwelle - gleiches Prinzip wie
    /// `FourWeekReviewDueCalculator.dueIntervalDays`.
    public static let periodicIntervalDays = 14

    /// Reiner Lesezugriff, sicher aus `body` aufrufbar - etabliert nichts.
    public static func state(
        lastAnalyzedAt: Date?,
        lastAnalyzedConfigurationFingerprint: String?,
        currentConfigurationFingerprint: String,
        latestLoggedTrainingDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> State {
        guard let lastAnalyzedAt else {
            return .due(reasons: [.neverAnalyzed])
        }
        if lastAnalyzedConfigurationFingerprint != currentConfigurationFingerprint {
            return .due(reasons: [.configurationChanged])
        }

        var reasons: [DueReason] = []
        if let latestLoggedTrainingDate, latestLoggedTrainingDate > lastAnalyzedAt {
            reasons.append(.newActivitySinceLastAnalysis)
        }
        let nextPeriodicCheck = calendar.date(byAdding: .day, value: periodicIntervalDays, to: lastAnalyzedAt) ?? now
        if now >= nextPeriodicCheck {
            reasons.append(.periodicIntervalElapsed)
        }

        guard !reasons.isEmpty else {
            return .notYetDue(nextCheckAt: nextPeriodicCheck)
        }
        return .due(reasons: reasons)
    }

    /// Legt, falls noetig, GENAU EINMAL `cardioCoachingEnabledAt = now` fuer
    /// ein Profil an, das den Coach bereits vor diesem Feld aktiviert hatte
    /// (`cardioCoachingEnabled == true`, `cardioCoachingEnabledAt == nil`) -
    /// Design-Dokument, "Migration/Default fuer Bestandsnutzer": niemals ein
    /// Datum in die Vergangenheit erfinden, "Beobachtung beginnt jetzt
    /// nachweislich" ist die einzige wahre Aussage. NIE aus einer SwiftUI-
    /// `body`-Auswertung heraus aufrufen (identische Regel wie beim Vorbild
    /// `FourWeekReviewDueStatus.establishObservationAnchorIfNeeded`).
    public static func establishObservationAnchorIfNeeded(
        for profile: UserBodyProfile, now: Date = Date(), in context: ModelContext
    ) {
        guard profile.cardioCoachingEnabled, profile.cardioCoachingEnabledAt == nil else { return }
        profile.cardioCoachingEnabledAt = now
        try? context.save()
    }

    /// Nach einer tatsaechlich durchgefuehrten/angezeigten Analyse
    /// aufzurufen. Persistiert sowohl den Zeitpunkt als auch die
    /// Konfiguration, gegen die bewertet wurde - der naechste `state(...)`-
    /// Aufruf erkennt eine zwischenzeitliche Ziel-/Renndatum-Aenderung damit
    /// zuverlaessig (`.configurationChanged`), ohne ein eigenes
    /// "letztes Ziel"-Feld zu brauchen.
    @discardableResult
    public static func recordAnalysisCompleted(
        for profile: UserBodyProfile,
        configurationFingerprint: String,
        now: Date = Date(),
        in context: ModelContext
    ) -> Bool {
        profile.raceProgressLastAnalyzedAt = now
        profile.raceProgressLastAnalyzedConfigurationFingerprint = configurationFingerprint
        try? context.save()
        return true
    }
}
#endif
