#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Paket 3a (Laufversäumnis-Hinweis, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
/// baut die reale Eingabe für `PlanParticipationEvaluator` (P6.2), aber
/// GEFILTERT auf nur die Lauf-Tage eines Plans — reuse des bestehenden
/// Evaluators mit einer kleinen Projektions-Funktion, kein zweiter
/// Analyse-Pfad (Paket-3-Scope-Vorschlag, Abschnitt "Wiederverwendung").
///
/// **Eignungspruefung des Evaluators fuer Lauf-Gelegenheiten (Schritt 1 der
/// Umsetzung, nicht blind angenommen):**
///   * `PlanParticipationEvaluator`s flexible Kadenz-Zaehlung
///     (`.flexibleWeeklyCadence`) behauptet NIE einen konkreten "Tag X wurde
///     verfehlt" — sie liefert nur eine Gesamtzahl faelliger/erfuellter
///     Gelegenheiten. Das erfuellt die Vorgabe "keine festen
///     Tagesversaeumnisse aus einem flexiblen Plan erfinden" bereits durch
///     den bestehenden Mechanismus — kein zusaetzlicher Guard noetig, der
///     flexible Plaene pauschal von der Auswertung ausschliesst.
///   * `activatedAt` ist laut Typ-Doku NUR ein Periodenstart-Parameter,
///     keine erzwungene "echte" Aktivierung (siehe `FourWeekReviewAssembler`,
///     das denselben Trick fuer Block-Grenzen nutzt). Das rollierende
///     Fenster unten clamped `activatedAt` deshalb NUR NACH VORNE
///     (`max(activatedAt, windowStart)`) — es wird nie ein FRUEHERES Datum
///     als die echte Aktivierung vorgetaeuscht, nur ein SPAETERES.
///   * Ein Planwechsel setzt `activatedAt` neu (P6.1) — alte Versaeumnisse
///     aus einem vorherigen Plan fallen dadurch automatisch aus dem
///     bewerteten Zeitraum, ohne dass dieser Typ selbst etwas dafuer tun
///     muss.
///   * Der Basis-Evaluator ist bewusst SPORT-AGNOSTISCH (jede reale Session
///     zaehlt fuer jeden Tag). Fuer eine lauf-spezifische Projektion ist das
///     NICHT ausreichend — eine Kraft- oder Ad-hoc-Session ohne erkennbaren
///     Lauf-Bezug darf keinen verfehlten Lauf-Tag "abdecken". Diese Funktion
///     uebernimmt deshalb NUR Sessions, die ueber eine echte Tag-Referenz
///     (`WorkoutSession.day`) zu einem bereits als Lauf-Tag identifizierten
///     `TrainingDay` DIESES Plans gehoeren (Vorwaerts-Traversal
///     `plan.days` → `day.sessions`, gleiches Crash-sichere Muster wie
///     `FourWeekReviewAssembler.realOccurrences`). Ad-hoc-Sessions ohne
///     Tag-Referenz und Sessions auf NICHT-Lauf-Tagen des Plans zaehlen
///     bewusst NICHT mit — ihr Sport-Bezug waere geraten.
@MainActor
public enum MissedRunDayEvaluator {

    /// Ein Tag zaehlt als "Lauf-Tag", wenn er kein Ruhetag ist UND entweder
    /// ueber `TrainingDay.enduranceSportKind` (Paket 2, strukturierte
    /// `.enduranceIntervals`-Einheiten) ODER ueber mindestens eine
    /// Cardio-Uebung mit `Exercise.enduranceSportKind == .running` als
    /// Laufen identifiziert ist. NIE aus dem Namen hergeleitet (Paket-2-
    /// Legacy-Vertrag, siehe `testEnduranceSportKindDefaultsToNilOnRoundtripAndIsNotDerivedFromDayName`)
    /// — ein Cardio-Tag mit `enduranceSportKind == nil` (Altbestand/nicht
    /// gepflegt) zaehlt deshalb bewusst NICHT als Lauf-Tag, auch wenn er
    /// inhaltlich einer sein koennte. Das unterzaehlt im Zweifel (keine
    /// Gelegenheit erfunden), uebertreibt aber nie.
    public static func isRunningDay(_ day: TrainingDay) -> Bool {
        guard day.type != .rest else { return false }
        if day.enduranceSportKind == .running { return true }
        return day.exercises.contains { $0.isCardio && $0.enduranceSportKind == .running }
    }

    /// Wirft bei einem echten Fetch-Fehler (statt ihn stillschweigend als
    /// "keine Sessions" zu behandeln) — gleicher P9-Fund/Schutz wie
    /// `FourWeekReviewAssembler.assemble`: ein geschluckter Fetch-Fehler
    /// wuerde hier sonst wie "nichts geloggt" aussehen und faelschlich JEDE
    /// faellige Gelegenheit als verfehlt zaehlen.
    public static func evaluate(
        plan: TrainingPlan,
        in context: ModelContext,
        now: Date = Date(),
        windowDays: Int = CardioCoachingAdvisor.missedRunWindowDays,
        calendar: Calendar = .current
    ) -> PlanParticipationEvaluator.Result {
        do {
            let input = try participationInput(plan: plan, in: context, now: now, windowDays: windowDays, calendar: calendar)
            return PlanParticipationEvaluator.evaluate(input, asOf: now)
        } catch {
            return .notReliablyEvaluable(.underlyingDataFetchFailed)
        }
    }

    /// Paket-3a-Restpunkt 1 (Re-Trigger-Korrektur, docs/DELTIQ_DEVICE_ACCEPTANCE.md):
    /// liefert die Gesamtzahl faelliger Lauf-Gelegenheiten seit dem ECHTEN,
    /// UNGECLAMPTEN `plan.activatedAt` — bewusst NICHT auf das rollierende
    /// 14-Tage-Fenster begrenzt (anders als `evaluate`/`participationInput`
    /// oben). Grund: `missedCount` aus dem rollierenden Fenster SAETTIGT
    /// sich an der Fenster-Obergrenze, sobald der Plan laenger als das
    /// Fenster aktiv ist — ab dann bleibt er bei fortgesetztem Versaeumnis
    /// UNVERAENDERT, obwohl taeglich eine weitere, echte, abgeschlossene
    /// Gelegenheit hinzukommt (mit jedem neuen Tag faellt gleichzeitig eine
    /// alte aus dem Fenster heraus). Diese Funktion liefert stattdessen
    /// einen monoton wachsenden Zaehler, der NUR von `activatedAt`/der
    /// Schedule-Struktur/`now` abhaengt (reine Kalenderrechnung, kein
    /// Sessions-Fetch noetig) — jede neu VERSTRICHENE faellige Gelegenheit
    /// erhoeht ihn, unabhaengig davon, ob sie erfuellt oder verfehlt wurde.
    /// `CardioCoachingAdvisor.missedRunHintFingerprint` nutzt ihn als
    /// zusaetzliche Komponente, um genau dieses "neue Gelegenheit trotz
    /// gedeckeltem `missedCount`"-Szenario von echtem Stillstand (nichts hat
    /// sich veraendert) zu unterscheiden.
    ///
    /// `nil`, wenn `PlanParticipationEvaluator` denselben Plan/dieselbe
    /// Schedule-Struktur ohnehin als `.notReliablyEvaluable` einstufen
    /// wuerde (kein Aktivierungsanker, inaktiver Plan, keine Lauf-Tage, …) —
    /// in diesem Fall liefert `evaluate` oben ebenfalls kein Ergebnis und
    /// der Hinweis erscheint gar nicht erst.
    public static func totalConcludedRunOpportunities(
        plan: TrainingPlan,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        let runningDays = plan.days.filter(isRunningDay)
        guard !runningDays.isEmpty, let activatedAt = plan.activatedAt else { return nil }
        let input = PlanParticipationEvaluator.Input(
            activatedAt: activatedAt,
            isActive: plan.isActive,
            occurrences: [],
            nonRestDayCount: runningDays.count,
            nonRestWeekdays: Set(runningDays.map(\.weekday)),
            usesFixedWeekdays: plan.generatorInput?.usesFixedWeekdays,
            calendar: calendar
        )
        guard case .evaluated(let summary) = PlanParticipationEvaluator.evaluate(input, asOf: now) else { return nil }
        return summary.plannedCount
    }

    private static func participationInput(
        plan: TrainingPlan,
        in context: ModelContext,
        now: Date,
        windowDays: Int,
        calendar: Calendar
    ) throws -> PlanParticipationEvaluator.Input {
        let runningDays = plan.days.filter(isRunningDay)
        let runningDaySessionIDs = Set(runningDays.flatMap { $0.sessions.map(\.persistentModelID) })

        // Rollierendes Fenster: `activatedAt` wird NUR nach vorne (naeher an
        // `now`) geclamped, nie rueckwaerts erfunden (siehe Typ-Doku oben).
        let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: calendar.startOfDay(for: now))
        let periodStart: Date?
        if let activatedAt = plan.activatedAt {
            periodStart = windowStart.map { max(activatedAt, $0) } ?? activatedAt
        } else {
            periodStart = nil
        }

        // Keine identifizierbaren Lauf-Tage im aktuellen Plan (weder klar
        // als Laufen markiert noch ueberhaupt vorhanden)? `nonRestDayCount`
        // unten wird dann 0 und der Basis-Evaluator liefert regulaer
        // `.planHasNoTrainingDays` — kein Sonderfall noetig, auch kein
        // Fetch, wenn es ohnehin nichts zuzuordnen gibt.
        guard !runningDays.isEmpty else {
            return PlanParticipationEvaluator.Input(
                activatedAt: periodStart,
                isActive: plan.isActive,
                occurrences: [],
                nonRestDayCount: 0,
                nonRestWeekdays: [],
                usesFixedWeekdays: plan.generatorInput?.usesFixedWeekdays,
                calendar: calendar
            )
        }

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isRestDay == false }
        ))
        let occurrences: [PlanParticipationEvaluator.SessionOccurrence] = sessions.compactMap { session in
            guard runningDaySessionIDs.contains(session.persistentModelID) else { return nil }
            let outcome: PlanParticipationEvaluator.SessionOccurrence.Outcome
            if session.isCompleted {
                outcome = .completed
            } else if !session.loggedSets.isEmpty {
                outcome = .partial
            } else {
                outcome = .startedOnly
            }
            return .init(date: session.startTime, outcome: outcome)
        }

        return PlanParticipationEvaluator.Input(
            activatedAt: periodStart,
            isActive: plan.isActive,
            occurrences: occurrences,
            nonRestDayCount: runningDays.count,
            nonRestWeekdays: Set(runningDays.map(\.weekday)),
            usesFixedWeekdays: plan.generatorInput?.usesFixedWeekdays,
            calendar: calendar
        )
    }
}
#endif
