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

    public static func assemble(
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FourWeekReviewOrchestrator.Review {
        let participation = PlanParticipationEvaluator.evaluate(
            participationInput(in: context, calendar: calendar),
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

    private static func participationInput(
        in context: ModelContext,
        calendar: Calendar
    ) -> PlanParticipationEvaluator.Input {
        let activePlans = (try? context.fetch(FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.isActive == true }
        ))) ?? []

        // Bewusste Vereinfachung dieses ersten Wurfs: mehrere gleichzeitig
        // aktive Pläne sind ein zulässiger Zustand (Task #201/#202), aber
        // `WorkoutSession` hat keine stabile Referenz zurück auf ihren Plan
        // (nur den Namens-Snapshot `dayName`) — eine zuverlässige Aufteilung
        // der Sessions auf mehrere gleichzeitig aktive Pläne gibt es dafür
        // nirgends im Code. Bei mehreren aktiven Plänen wird hier der nach
        // Name sortiert ERSTE bewertet; eine echte Mehrplan-Aufteilung bleibt
        // eine spätere, eigenständige Erweiterung — offen benannt, nicht
        // stillschweigend verschwiegen.
        guard let plan = activePlans.sorted(by: { $0.name < $1.name }).first else {
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
