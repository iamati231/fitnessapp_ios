#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore
import FitnessAppData

/// Paket 3a (Laufversäumnis-Hinweis, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// datenqualitätsgesicherter Hinweis für wiederholt nicht protokollierte
/// Laufgelegenheiten. Reine Beobachtung — keine Aussage zur Ursache
/// ("überfordert"/"untrainiert"/Erholung), keine automatische Reduktion/
/// Steigerung/Planänderung. Der einzige CTA öffnet den bereits bestehenden
/// Paket-1-Pfad (`CoachAdjustmentCardModel`/`CoachAdjustmentPreviewView`) —
/// dieser Typ selbst fügt KEINE neue Mutationslogik hinzu.
public struct MissedRunDaysCardModel: Equatable {
    public let summary: PlanParticipationEvaluator.Summary
    public let fingerprint: String

    /// Paket-1-Anpassungsvorschlag für denselben Plan, falls einer
    /// existiert. Korrektur gegenüber dem ursprünglichen Scope-Vorschlag:
    /// eine FRÜHERE Übernahme (`coachAdjustment?.isAlreadyApplied == true`)
    /// blendet den CTA NICHT aus — `CoachAdjustmentPreviewView` bleibt
    /// erreichbar (sie zeigt dann ehrlich "bereits übernommen"), damit ein
    /// Nutzer, der NACH einer bereits übernommenen Anpassung weiterhin
    /// Läufe verfehlt, nicht dauerhaft ausgesperrt wird.
    public let coachAdjustment: CoachAdjustmentCardModel?

    /// `nil`, wenn der Hinweis fuer `profile`/`activePlan` aktuell nicht
    /// gezeigt werden soll:
    ///   * Coach aus (`cardioCoachingEnabled == false`) — Scope-Entscheidung
    ///     (offene Frage 2 im Scope-Vorschlag): dieser Hinweis ist ein
    ///     Plan-Anpassungs-Hinweis, kein Onboarding-Nudge.
    ///   * Kein aktiver Plan.
    ///   * `MissedRunDayEvaluator` liefert `.notReliablyEvaluable` (fehlender
    ///     Aktivierungsanker, inaktiver Plan, keine identifizierbaren
    ///     Lauf-Tage, Fetch-Fehler, …) — unklare/unzureichende Daten zeigen
    ///     NIE einen Versäumnis-Hinweis.
    ///   * `missedCount` unter der Schwelle
    ///     (`CardioCoachingAdvisor.minimumMissedRunDaysToFlag`).
    ///   * Der aktuelle `fingerprint` wurde bereits abgelehnt
    ///     (`profile.missedRunHintDismissedFingerprint`) UND weder die
    ///     Planfassung noch die Beobachtung haben sich seitdem geändert
    ///     (siehe `CardioCoachingAdvisor.missedRunHintFingerprint`).
    @MainActor
    public static func make(
        for profile: UserBodyProfile,
        activePlan: TrainingPlan?,
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MissedRunDaysCardModel? {
        // `activatedAt` traegt die "Planfassung" fuer den Fingerprint unten —
        // der ECHTE, nicht auf das rollierende Fenster geclampte Anker (siehe
        // `CardioCoachingAdvisor.missedRunHintFingerprint`-Doku). Ist er
        // unbekannt, liefert `MissedRunDayEvaluator` ohnehin
        // `.notReliablyEvaluable(.activationStartUnknown)` — dieser Guard
        // macht das nur bereits hier explizit.
        guard profile.cardioCoachingEnabled, let activePlan, let planActivatedAt = activePlan.activatedAt else { return nil }
        let participation = MissedRunDayEvaluator.evaluate(plan: activePlan, in: context, now: now, calendar: calendar)
        guard case .evaluated(let summary) = participation,
              CardioCoachingAdvisor.isRecurringMissedRunDays(participation)
        else { return nil }

        // Restpunkt 1 (Re-Trigger-Korrektur): ungeclampter Gesamtzaehler
        // seit `planActivatedAt`, siehe `MissedRunDayEvaluator.
        // totalConcludedRunOpportunities`-Doc. Kann praktisch nicht `nil`
        // werden, wenn `participation` oben bereits `.evaluated` geliefert
        // hat (identische Lauf-Tage/activatedAt-Grundlage) - `?? 0` nur als
        // defensiver Fallback, kein beobachtbarer Normalfall.
        let concludedOpportunityCount = MissedRunDayEvaluator.totalConcludedRunOpportunities(
            plan: activePlan, now: now, calendar: calendar
        ) ?? 0
        let fingerprint = CardioCoachingAdvisor.missedRunHintFingerprint(
            planActivatedAt: planActivatedAt, summary: summary, concludedOpportunityCount: concludedOpportunityCount
        )
        guard profile.missedRunHintDismissedFingerprint != fingerprint else { return nil }

        return MissedRunDaysCardModel(
            summary: summary,
            fingerprint: fingerprint,
            coachAdjustment: CoachAdjustmentCardModel.make(for: profile, activePlan: activePlan)
        )
    }

    /// "Nicht jetzt": blendet den Hinweis aus, bis sich entweder die
    /// Planfassung ändert ODER neue Versäumnisse auftreten (beides fließt in
    /// `fingerprint` ein — siehe
    /// `CardioCoachingAdvisor.missedRunHintFingerprint`). Rührt den Plan
    /// NICHT an — reine Sichtbarkeits-/Prioritätsentscheidung, kein
    /// zweiter Mutationspfad.
    public func dismiss(profile: UserBodyProfile) {
        profile.missedRunHintDismissedFingerprint = fingerprint
    }
}
#endif
