#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// P7.3: verbindet `FourWeekReviewDueCalculator` (Core, reine Logik) mit
/// echten `TrainingPlan`-Objekten. Stellt sicher, dass ein fehlender
/// Zeitanker (`activatedAt == nil`, Altbestand vor P6.1) GENAU EINMAL durch
/// einen real gespeicherten Beobachtungsbeginn ersetzt wird — kein
/// erfundenes historisches Datum, siehe `TrainingPlan.reviewObservationStartedAt`.
///
/// Mehrere gleichzeitig aktive Pläne (Task #201/#202) werden hier NIE auf
/// einen einzigen (z.B. alphabetisch ersten) reduziert — jeder aktive Plan
/// behält seinen eigenen Fälligkeits-/Abschlussstatus
/// (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md, P7.3, ausdrückliche
/// Produktentscheidung). `FourWeekReviewAssembler.primaryPlanForReview`
/// wählt weiterhin EINEN Plan für den Review-INHALT (bereits für P7.1/P7.2
/// offen dokumentierte Vereinfachung) — die Fälligkeits-AGGREGATION hier
/// deckt dagegen ausdrücklich ALLE aktiven Pläne ab.
@MainActor
public enum FourWeekReviewDueStatus {

    /// Fälligkeits-/Abschlussstatus EINES konkreten Plans. `now`/`calendar`
    /// injiziert, damit Aufrufer (Tests eingeschlossen) deterministisch
    /// bleiben. Legt bei Bedarf einmalig den Beobachtungs-Fallback an (siehe
    /// Typ-Dokumentation) — mutiert also ggf. den `context`, deshalb NICHT
    /// aus einer SwiftUI-`body`-Auswertung heraus aufrufen (siehe
    /// `isAnyDue(among:)` für den reinen, seiteneffektfreien Lesezugriff).
    public static func state(
        for plan: TrainingPlan,
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FourWeekReviewDueCalculator.State {
        establishObservationAnchorIfNeeded(for: plan, now: now, in: context)
        return FourWeekReviewDueCalculator.state(
            activatedAt: plan.activatedAt,
            reviewObservationStartedAt: plan.reviewObservationStartedAt,
            reviewCompletedAt: plan.reviewCompletedAt,
            reviewDecision: plan.reviewDecision,
            now: now,
            calendar: calendar
        )
    }

    /// Reiner Lesezugriff über bereits geladene Pläne (z.B. aus einer
    /// `@Query`) — KEINE Mutation, sicher aus einer SwiftUI-`body`-
    /// Auswertung heraus aufrufbar. Ein Plan ohne jeden Zeitanker
    /// (`activatedAt` und `reviewObservationStartedAt` beide `nil`) zählt
    /// hier bewusst NICHT als fällig (`.unknown` ist kein `.due`) — erst
    /// `establishObservationAnchorsIfNeeded` legt für ihn einen echten
    /// Beobachtungsbeginn fest.
    public static func isAnyDue(
        among plans: [TrainingPlan],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        plans.contains { plan in
            let state = FourWeekReviewDueCalculator.state(
                activatedAt: plan.activatedAt,
                reviewObservationStartedAt: plan.reviewObservationStartedAt,
                reviewCompletedAt: plan.reviewCompletedAt,
                reviewDecision: plan.reviewDecision,
                now: now,
                calendar: calendar
            )
            if case .due = state { return true }
            return false
        }
    }

    /// Markiert den Rückblick für `plan` als abgeschlossen. Nur durch eine
    /// ausdrückliche Nutzeraktion im Review-Screen aufzurufen — NIE durch
    /// bloßes Öffnen/Verlassen der Seite (siehe Typ-Dokumentation von
    /// `FourWeekReviewDueCalculator`).
    public static func markCompleted(
        for plan: TrainingPlan,
        decision: FourWeekReviewDueCalculator.Decision,
        now: Date = Date(),
        in context: ModelContext
    ) {
        plan.reviewCompletedAt = now
        plan.reviewDecision = decision
        try? context.save()
    }

    /// Legt für JEDEN aktiven Plan ohne `activatedAt` UND ohne bereits
    /// gesetzten Beobachtungsbeginn genau einmal `reviewObservationStartedAt
    /// = now` an — ein Sammel-Save statt eines Saves pro Plan. Gedacht für
    /// einen einmaligen `.task`-Aufruf beim Erscheinen eines Screens, NIE
    /// aus einer `body`-Auswertung heraus (vermeidet eine Mutation während
    /// eine `@Query` auf `TrainingPlan` dieselbe View beobachtet).
    public static func establishObservationAnchorsIfNeeded(
        in context: ModelContext,
        now: Date = Date()
    ) {
        let activePlans = (try? context.fetch(FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.isActive == true }
        ))) ?? []
        var didChange = false
        for plan in activePlans where plan.activatedAt == nil && plan.reviewObservationStartedAt == nil {
            plan.reviewObservationStartedAt = now
            didChange = true
        }
        if didChange {
            try? context.save()
        }
    }

    private static func establishObservationAnchorIfNeeded(
        for plan: TrainingPlan,
        now: Date,
        in context: ModelContext
    ) {
        guard plan.activatedAt == nil, plan.reviewObservationStartedAt == nil else { return }
        plan.reviewObservationStartedAt = now
        try? context.save()
    }
}
#endif
