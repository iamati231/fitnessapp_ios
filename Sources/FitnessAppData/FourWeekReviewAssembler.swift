#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// P7.2: Baut die reale Eingabe für `FourWeekReviewOrchestrator` (P7.1) aus
/// SwiftData zusammen. Reiner Daten-Zubringer — trifft selbst KEINE
/// Progressions-/Deload-Entscheidung, sondern ruft ausschließlich die
/// bestehenden, bereits an anderer Stelle produktiv genutzten Bausteine auf:
///
///   * `PlanParticipationEvaluator` (P6.2) für den Soll-Ist-Vergleich.
///   * `DeloadAdvisor.shouldRecommendDeload` mit **identischer Herleitung**
///     wie `DashboardView.shouldRecommendDeload` (dieselbe Drei-Wochen-
///     Fenster-/CNS-Last-Logik) — keine zweite, abweichende Berechnung.
///   * `AbsenceDeload.assess` (bereits produktiv für den Trainings-Start-
///     Comeback-Dialog genutzt) für das Comeback-Signal, statt
///     `ComebackAdvisor` ein zweites Mal eigenständig anzusteuern.
///   * Den zuletzt gespeicherten `PeriodicCheckIn` (P6.3).
///
/// `@MainActor`, weil `AbsenceDeload.assess` und `DeloadManager.isActive`
/// main-actor-isoliert sind (siehe deren eigene Dokumentation).
@MainActor
public enum FourWeekReviewAssembler {

    /// P9 (Mehrplan-Bedienablauf): `plan` lässt den Aufrufer EXPLIZIT
    /// festlegen, welcher Plan bewertet wird — `nil` (Default) behält die
    /// bestehende "erster aktiver Plan nach Name"-Vereinfachung
    /// (`primaryActivePlan`) für Aufrufer bei, die keinen Plan ausgewählt
    /// haben (Rückwärtskompatibilität zu allen bisherigen Call-Sites/Tests).
    /// Die Soll-Ist-Teilnahme ist das EINZIGE Signal, das sich pro Plan
    /// unterscheidet — Deload-/Comeback-Signale bleiben bewusst global
    /// (siehe `shouldRecommendDeload`-Dokumentation: `WorkoutSession` hat
    /// keine stabile Plan-Referenz, eine Zuordnung zu EINEM Plan gäbe es
    /// nirgends im Code).
    public static func assemble(
        in context: ModelContext,
        for plan: TrainingPlan? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FourWeekReviewOrchestrator.Review {
        let participation = PlanParticipationEvaluator.evaluate(
            participationInput(in: context, for: plan, calendar: calendar),
            asOf: now
        )

        let comebackSignal: FourWeekReviewOrchestrator.ComebackSignal? = AbsenceDeload
            .assess(in: context, now: now, calendar: calendar)
            .map { assessment in
                FourWeekReviewOrchestrator.ComebackSignal(
                    gapDays: assessment.gapDays,
                    prescription: ComebackAdvisor.prescription(forGapDays: assessment.gapDays)
                )
            }

        return FourWeekReviewOrchestrator.review(.init(
            participation: participation,
            latestCheckIn: latestCheckInFeedback(in: context),
            deloadRecommended: shouldRecommendDeload(in: context, now: now, calendar: calendar),
            comebackSignal: comebackSignal
        ))
    }

    // MARK: - Soll-Ist-Eingabe (P6.2)

    /// Derselbe Plan, den `participationInput` für den Review-INHALT
    /// bewertet (siehe dessen Dokumentation zur "erster Plan nach Name"-
    /// Vereinfachung) — P7.3 nutzt dies, um Fälligkeit/Abschluss exakt für
    /// den Plan anzuzeigen und zu speichern, der tatsächlich bewertet wurde,
    /// statt eine zweite, abweichende Auswahl zu treffen.
    public static func primaryPlanForReview(in context: ModelContext) -> TrainingPlan? {
        primaryActivePlan(in: context)
    }

    /// P9: alle aktuell aktiven Pläne, sortiert nach Anzeigename — EINZIGE
    /// Quelle der Wahrheit für "gibt es mehr als einen aktiven Plan", damit
    /// UI-Picker (`FourWeekReviewEntryView`) und die Fälligkeits-Aggregation
    /// (`FourWeekReviewDueStatus.isAnyDue`) dieselbe Grundmenge sehen.
    public static func allActivePlans(in context: ModelContext) -> [TrainingPlan] {
        let activePlans = (try? context.fetch(FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.isActive == true }
        ))) ?? []
        return activePlans.sorted { $0.name < $1.name }
    }

    private static func primaryActivePlan(in context: ModelContext) -> TrainingPlan? {
        // Bewusste Vereinfachung dieses ersten Wurfs: mehrere gleichzeitig
        // aktive Pläne sind ein zulässiger Zustand (Task #201/#202), aber
        // `WorkoutSession` hat keine stabile Referenz zurück auf ihren Plan
        // (nur den Namens-Snapshot `dayName`) — eine zuverlässige Aufteilung
        // der Sessions auf mehrere gleichzeitig aktive Pläne gibt es dafür
        // nirgends im Code. Bei mehreren aktiven Plänen wird hier der nach
        // Name sortiert ERSTE bewertet; eine echte Mehrplan-Aufteilung bleibt
        // eine spätere, eigenständige Erweiterung — offen benannt, nicht
        // stillschweigend verschwiegen. Gilt ausdrücklich NUR für Aufrufer
        // OHNE explizite Planauswahl (`assemble(in:for: nil)`); P9 ergänzt
        // `FourWeekReviewEntryView`, das bei mehreren aktiven Plänen eine
        // ausdrückliche Auswahl anbietet, statt sich auf diese Vereinfachung
        // zu verlassen. Die P7.3-FälligkeitsAGGREGATION
        // (`FourWeekReviewDueStatus.isAnyDue`) wertete bereits zuvor JEDEN
        // aktiven Plan einzeln aus, ohne diese Auswahl zu übernehmen.
        allActivePlans(in: context).first
    }

    private static func participationInput(
        in context: ModelContext,
        for explicitPlan: TrainingPlan?,
        calendar: Calendar
    ) -> PlanParticipationEvaluator.Input {
        guard let plan = explicitPlan ?? primaryActivePlan(in: context) else {
            return PlanParticipationEvaluator.Input(
                activatedAt: nil,
                isActive: false,
                occurrences: [],
                nonRestDayCount: 0,
                nonRestWeekdays: [],
                usesFixedWeekdays: nil,
                calendar: calendar
            )
        }

        let nonRestDays = plan.days.filter { $0.type != .rest }

        return PlanParticipationEvaluator.Input(
            activatedAt: plan.activatedAt,
            isActive: plan.isActive,
            occurrences: realOccurrences(in: context),
            nonRestDayCount: nonRestDays.count,
            nonRestWeekdays: Set(nonRestDays.map(\.weekday)),
            usesFixedWeekdays: plan.generatorInput?.usesFixedWeekdays,
            calendar: calendar
        )
    }

    /// Alle echten (nicht als Ruhetag markierten) Sessions, unabhängig vom
    /// Abschlussstatus — `PlanParticipationEvaluator` braucht ausdrücklich
    /// auch `.partial`/`.startedOnly`, nicht nur abgeschlossene Einheiten
    /// (siehe dessen eigene Drei-Stufen-Dokumentation). Ad-hoc-Sessions
    /// zählen bewusst MIT: wer frei statt nach Plan trainiert hat, hat an dem
    /// Tag trotzdem real trainiert.
    private static func realOccurrences(in context: ModelContext) -> [PlanParticipationEvaluator.SessionOccurrence] {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isRestDay == false }
        ))) ?? []
        return sessions.map { session in
            let outcome: PlanParticipationEvaluator.SessionOccurrence.Outcome
            if session.isCompleted {
                outcome = .completed
            } else if !session.loggedSets.isEmpty {
                outcome = .partial
            } else {
                outcome = .startedOnly
            }
            return PlanParticipationEvaluator.SessionOccurrence(date: session.startTime, outcome: outcome)
        }
    }

    // MARK: - Periodisches Feedback (P6.3)

    private static func latestCheckInFeedback(in context: ModelContext) -> FourWeekReviewOrchestrator.CheckInFeedback? {
        var descriptor = FetchDescriptor<PeriodicCheckIn>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let latest = (try? context.fetch(descriptor))?.first else { return nil }
        return FourWeekReviewOrchestrator.CheckInFeedback(
            frequencyFeedback: latest.frequencyFeedback,
            durationFeedback: latest.durationFeedback,
            hadComplaints: latest.hadComplaints,
            goalStillCurrent: latest.goalStillCurrent,
            exertionFeedback: latest.exertionFeedback
        )
    }

    // MARK: - Deload-Signal (identische Herleitung wie DashboardView)

    /// Spiegelt exakt `DashboardView.shouldRecommendDeload` — bewusst
    /// dieselbe Drei-Wochen-Fenster-/CNS-Last-/Hard-Session-Logik, damit
    /// diese Übersicht niemals eine andere Deload-Einschätzung zeigt als das
    /// Dashboard selbst. Die eigentliche ENTSCHEIDUNG bleibt vollständig in
    /// `DeloadAdvisor` — hier wird nur dieselbe reale Datengrundlage erneut
    /// zusammengestellt, nicht neu entschieden.
    private static func shouldRecommendDeload(
        in context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard !DeloadManager.isActive(in: context) else { return false }
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return false
        }

        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true && $0.isRestDay == false }
        ))) ?? []

        var weeklyLoads: [Double] = []
        for offset in stride(from: -3, through: -1, by: 1) {
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else {
                return false
            }
            let load = sessions
                .filter { $0.startTime >= start && $0.startTime < end }
                .reduce(0.0) { $0 + $1.strengthCNSLoad }
            weeklyLoads.append(load)
        }

        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? .distantPast
        let hardSessions = sessions.filter {
            $0.startTime >= fourteenDaysAgo
                && DeloadAdvisor.isHardStrengthSession(
                    feeling: $0.sessionFeeling,
                    containsStrengthWork: $0.containsStrengthWork
                )
        }.count

        return DeloadAdvisor.shouldRecommendDeload(weeklyLoads: weeklyLoads, hardSessionCount: hardSessions)
    }
}
#endif
