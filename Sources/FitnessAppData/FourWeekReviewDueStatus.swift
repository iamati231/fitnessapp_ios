#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// P7.3/P8 Stufe 3: verbindet `FourWeekReviewDueCalculator` (Core, reine
/// Logik) mit echten `TrainingPlan`-Objekten, UND hält die dauerhafte
/// Blockhistorie (`TrainingPlan.blockReviewHistoryJSON`).
///
/// **P8 Stufe 3 — wiederkehrender Zyklus (docs/P8_STUFE3_BLOCK_RUECKBLICK_PLAN.md):**
/// Der erste Block (P7) bleibt bei `activatedAt`/`reviewObservationStartedAt`
/// und 28 Tagen unverändert. Jeder Abschluss eröffnet SOFORT den nächsten
/// Block für denselben Plan — `activatedAt` wird dafür NIE verändert, der
/// Beginn des nächsten Blocks ist stattdessen der Kalendertag NACH dem
/// Abschluss des vorigen (siehe `currentBlockStart(for:)` — der
/// Abschlusstag selbst zählt vollständig noch zum ABGESCHLOSSENEN Block,
/// nie doppelt). Jeder Folgeblock nutzt `subsequentBlockIntervalDays` (42
/// Tage) statt `dueIntervalDays` (28 Tage, nur für den allerersten Block).
///
/// Ein fertig abgeschlossener Block wird NIE nachträglich anhand heutiger
/// Daten neu bewertet — `completeCurrentBlock` friert den zum Abschluss
/// tatsächlich GEZEIGTEN Befund (`FourWeekReviewOrchestrator.Review`) in
/// die Historie ein.
///
/// Mehrere gleichzeitig aktive Pläne (Task #201/#202) werden hier NIE auf
/// einen einzigen (z.B. alphabetisch ersten) reduziert — jeder aktive Plan
/// behält seinen eigenen Fälligkeits-/Historienstatus
/// (docs/NEUE_SPEZIFIKATION_P0_AUDIT.md, P7.3, ausdrückliche
/// Produktentscheidung). `FourWeekReviewAssembler.primaryPlanForReview`
/// wählt weiterhin EINEN Plan für den Review-INHALT (bereits für P7.1/P7.2
/// offen dokumentierte Vereinfachung) — die Fälligkeits-AGGREGATION hier
/// deckt dagegen ausdrücklich ALLE aktiven Pläne ab.
@MainActor
public enum FourWeekReviewDueStatus {

    // MARK: - Blockhistorie (P8 Stufe 3)

    /// Alle bereits abgeschlossenen Blöcke dieses Plans, chronologisch
    /// (ältester zuerst). Liest ausschließlich `blockReviewHistoryJSON`,
    /// wenn vorhanden — fehlt es (jeder Plan vor diesem Feld, ODER ein
    /// Plan, der noch nie über den neuen Pfad abgeschlossen wurde), wird
    /// aus den Alt-Feldern (`reviewCompletedAt`/`reviewDecisionRaw`) HÖCHSTENS
    /// EIN Eintrag nachgebildet — niemals geschrieben, nur gelesen, und der
    /// gezeigte Befund bleibt dabei bewusst `nil` (siehe
    /// `BlockReviewRecord`-Dokumentation: nie rückwirkend erfunden).
    public static func history(for plan: TrainingPlan) -> [BlockReviewRecord] {
        if let json = plan.blockReviewHistoryJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([BlockReviewRecord].self, from: data) {
            return decoded
        }
        if let completedAt = plan.reviewCompletedAt {
            return [BlockReviewRecord(
                blockStart: plan.activatedAt ?? plan.reviewObservationStartedAt,
                completedAt: completedAt,
                decision: plan.reviewDecision,
                shownOutcome: nil,
                shownDataGaps: nil
            )]
        }
        return []
    }

    /// Beginn des AKTUELL offenen Blocks. Nach dem letzten Abschluss der
    /// Kalendertag DANACH (ein Abschlusstag zählt vollständig noch zum
    /// abgeschlossenen Block — siehe Typ-Dokumentation, "Grenzzeitpunkte
    /// nicht doppelt zählen"). Vor jedem Abschluss (erster Block) der
    /// bekannte Aktivierungs-/Beobachtungsanker, unverändert wie in P7.
    public static func currentBlockStart(for plan: TrainingPlan, calendar: Calendar = .current) -> Date? {
        guard let last = history(for: plan).last else {
            return plan.activatedAt ?? plan.reviewObservationStartedAt
        }
        let completionDay = calendar.startOfDay(for: last.completedAt)
        return calendar.date(byAdding: .day, value: 1, to: completionDay)
    }

    /// 28 Tage für den allerersten Block (P7, unverändert), danach 42 Tage
    /// (P8 Stufe 3, ausdrückliche Produktregel — keine wissenschaftliche
    /// Schwelle, siehe docs/P8_STUFE3_BLOCK_RUECKBLICK_PLAN.md).
    public static func intervalDays(for plan: TrainingPlan) -> Int {
        history(for: plan).isEmpty
            ? FourWeekReviewDueCalculator.dueIntervalDays
            : FourWeekReviewDueCalculator.subsequentBlockIntervalDays
    }

    // MARK: - Fälligkeit des aktuellen Blocks

    /// Fälligkeits-Status des AKTUELL offenen Blocks. `now`/`calendar`
    /// injiziert, damit Aufrufer (Tests eingeschlossen) deterministisch
    /// bleiben. Legt bei Bedarf einmalig den Beobachtungs-Fallback an (siehe
    /// Typ-Dokumentation) — mutiert also ggf. den `context`, deshalb NICHT
    /// aus einer SwiftUI-`body`-Auswertung heraus aufrufen.
    public static func state(
        for plan: TrainingPlan,
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FourWeekReviewDueCalculator.State {
        establishObservationAnchorIfNeeded(for: plan, now: now, in: context)
        return FourWeekReviewDueCalculator.state(
            blockStart: currentBlockStart(for: plan, calendar: calendar),
            intervalDays: intervalDays(for: plan),
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
                blockStart: currentBlockStart(for: plan, calendar: calendar),
                intervalDays: intervalDays(for: plan),
                now: now,
                calendar: calendar
            )
            if case .due = state { return true }
            return false
        }
    }

    // MARK: - Abschluss (eröffnet sofort den nächsten Block)

    /// Schließt den AKTUELL offenen Block ab und eröffnet damit implizit
    /// den nächsten für denselben Plan — kein zusätzlicher "Block starten"-
    /// Schritt (siehe Typ-Dokumentation). Nur durch eine ausdrückliche
    /// Nutzeraktion im Review-Screen aufzurufen — NIE durch bloßes
    /// Öffnen/Verlassen der Seite.
    ///
    /// **Idempotent gegen Doppeltippen/erneute Ausführung:** `expectedBlockStart`
    /// ist der Blockbeginn, den der Aufrufer beim LADEN des Screens über
    /// `currentBlockStart(for:)` ermittelt hat. Stimmt er beim tatsächlichen
    /// Aufruf nicht mehr mit dem GERADE JETZT neu berechneten
    /// `currentBlockStart` überein (z. B. weil ein erster, bereits
    /// verarbeiteter Tap diesen Block schon abgeschlossen hat), ändert
    /// dieser Aufruf nichts und gibt `false` zurück — kein doppelter
    /// Historien-Eintrag.
    ///
    /// Der übergebene `shownReview` MUSS exakt das sein, was dem Nutzer beim
    /// Tap angezeigt wurde (nicht neu berechnet) — ein später abgeschlossener
    /// Block darf nicht anhand zwischenzeitlich veränderter Daten zu einem
    /// anderen Ergebnis werden, als tatsächlich zu sehen war.
    @discardableResult
    public static func completeCurrentBlock(
        for plan: TrainingPlan,
        expectedBlockStart: Date?,
        decision: FourWeekReviewDueCalculator.Decision,
        shownReview: FourWeekReviewOrchestrator.Review,
        now: Date = Date(),
        calendar: Calendar = .current,
        in context: ModelContext
    ) -> Bool {
        guard currentBlockStart(for: plan, calendar: calendar) == expectedBlockStart else {
            return false
        }
        var entries = history(for: plan)
        entries.append(BlockReviewRecord(
            blockStart: expectedBlockStart,
            completedAt: now,
            decision: decision,
            shownOutcome: shownReview.outcome,
            shownDataGaps: shownReview.dataGaps
        ))
        guard let data = try? JSONEncoder().encode(entries),
              let json = String(data: data, encoding: .utf8)
        else { return false }

        plan.blockReviewHistoryJSON = json
        // Rückwärtskompatibilität: spiegelt immer den JEWEILS LETZTEN
        // Abschluss, für jeden Code, der weiterhin nur diese Altfelder liest.
        plan.reviewCompletedAt = now
        plan.reviewDecision = decision
        try? context.save()
        return true
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
