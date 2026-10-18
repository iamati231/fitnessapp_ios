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
    /// unterscheidet — Deload-/Comeback-Signale bleiben bewusst global: das
    /// ist eine eigenständige Produktentscheidung (Erschöpfung/CNS-Last ist
    /// personen-, nicht planbezogen), KEINE technische Notlösung — anders als
    /// zuvor hier dokumentiert, hat `WorkoutSession` über `day: TrainingDay?`
    /// sehr wohl eine reale, bei jedem produktiven Session-Start gesetzte
    /// Referenz zurück zu ihrem Plan (`day.plan`). Genau diese Referenz nutzt
    /// `realOccurrences(in:for:)` jetzt, um die Soll-Ist-Teilnahme korrekt pro
    /// Plan zu isolieren (siehe dessen Dokumentation für die drei
    /// unterschiedenen Fälle und warum unklare Historie ausgeschlossen statt
    /// geraten wird).
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
        // aktive Pläne sind ein zulässiger Zustand (Task #201/#202). Die
        // Soll-Ist-Teilnahme LÄSST SICH inzwischen zuverlässig pro Plan
        // trennen (siehe `realOccurrences(in:for:)` — `WorkoutSession.day`
        // trägt eine reale Plan-Referenz); diese Funktion hier entscheidet
        // trotzdem bewusst NICHT automatisch, FÜR WELCHEN der mehreren
        // aktiven Pläne ein Aufrufer ohne explizite Auswahl überhaupt
        // reviewen will — das bliebe sonst eine stillschweigende Annahme.
        // Bei mehreren aktiven Plänen wird hier der nach Name sortiert ERSTE
        // bewertet; eine echte Mehrplan-Aufteilung bleibt eine spätere,
        // eigenständige UX-Erweiterung — offen benannt, nicht stillschweigend
        // verschwiegen. Gilt ausdrücklich NUR für Aufrufer OHNE explizite
        // Planauswahl (`assemble(in:for: nil)`); P9 ergänzt
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
        // Mehrdeutigkeit (siehe `realOccurrences`) kann nur entstehen, wenn
        // es ueberhaupt mehr als einen aktiven Plan gibt, den eine
        // Session-ohne-Tag-Referenz alternativ meinen koennte.
        let multipleActivePlans = allActivePlans(in: context).count > 1
        let (occurrences, excludedUnattributable) = realOccurrences(
            in: context, for: plan, ambiguousAcrossActivePlans: multipleActivePlans
        )

        return PlanParticipationEvaluator.Input(
            activatedAt: plan.activatedAt,
            isActive: plan.isActive,
            occurrences: occurrences,
            nonRestDayCount: nonRestDays.count,
            nonRestWeekdays: Set(nonRestDays.map(\.weekday)),
            usesFixedWeekdays: plan.generatorInput?.usesFixedWeekdays,
            hasUnattributableSessionsExcluded: excludedUnattributable,
            calendar: calendar
        )
    }

    /// Alle echten (nicht als Ruhetag markierten) Sessions, DIE SICH `plan`
    /// ZUORDNEN LASSEN, unabhängig vom Abschlussstatus —
    /// `PlanParticipationEvaluator` braucht ausdrücklich auch
    /// `.partial`/`.startedOnly`, nicht nur abgeschlossene Einheiten (siehe
    /// dessen eigene Drei-Stufen-Dokumentation).
    ///
    /// P6.2 verlangt ausdrücklich "kein globaler Soll-Ist-Topf" — jeder Plan
    /// wird einzeln bewertet. `WorkoutSession.day` (gesetzt an allen drei
    /// echten Erzeugungspfaden: `DayEditorView`/`DashboardView`
    /// Plan-Start, Ruhetag-Überspringen, spontanes Ad-hoc-Training) liefert
    /// dafür über `day.plan` eine reale, zur Erzeugungszeit korrekte
    /// Plan-Referenz. Drei Fälle, pro Session:
    ///   1. `day.plan === plan` → zählt für GENAU diesen Plan.
    ///   2. `day.plan` ist ein ANDERER Plan → zählt NICHT (das war der Bug:
    ///      vorher flossen Sessions eines zweiten aktiven Plans fälschlich in
    ///      jede Auswertung ein). Unabhängig davon, ob dieser andere Plan
    ///      noch aktiv ist — ein Plan zählt nie Sessions, die strukturell
    ///      einem anderen Plan gehören.
    ///   3. `day == nil` — entweder ein echtes Ad-hoc-Training (`day` zeigt
    ///      auf einen ephemeren Tag OHNE Plan, `day.plan == nil`: zählt
    ///      bewusst für JEDEN aktiven Plan mit, wer frei statt nach Plan
    ///      trainiert hat, hat an dem Tag trotzdem real trainiert) ODER die
    ///      Session hat GAR KEINE Tag-Referenz (CSV-Import/Restore setzt sie
    ///      nie, oder der ursprüngliche Tag wurde später gelöscht/regeneriert
    ///      — `deleteRule: .nullify`). Bei genau einem aktiven Plan ist das
    ///      unproblematisch (keine Alternative, der die Session gehören
    ///      könnte); bei mehreren aktiven Plänen lässt sich das NICHT mehr
    ///      zuverlässig auflösen. Statt über `dayName`/Plan-Namen zu raten
    ///      oder die Session irgendeinem Plan stillschweigend gutzuschreiben,
    ///      wird sie dann ausgeschlossen — sichtbar gemacht über
    ///      `hasUnattributableSessionsExcluded` /
    ///      `.unattributableHistoryExcludedDueToMultipleActivePlans`.
    private static func realOccurrences(
        in context: ModelContext,
        for plan: TrainingPlan,
        ambiguousAcrossActivePlans: Bool
    ) -> (occurrences: [PlanParticipationEvaluator.SessionOccurrence], hasExcludedUnattributable: Bool) {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isRestDay == false }
        ))) ?? []

        var hasExcludedUnattributable = false
        var occurrences: [PlanParticipationEvaluator.SessionOccurrence] = []
        for session in sessions {
            if let owningPlan = session.day?.plan {
                guard owningPlan === plan else { continue }
            } else if session.day == nil, ambiguousAcrossActivePlans {
                hasExcludedUnattributable = true
                continue
            }
            // Verbleibende Fälle: `day.plan === plan` (oben bereits
            // bestätigt), echtes Ad-hoc (`day != nil`, `day.plan == nil`),
            // oder `day == nil` bei nur einem aktiven Plan.

            let outcome: PlanParticipationEvaluator.SessionOccurrence.Outcome
            if session.isCompleted {
                outcome = .completed
            } else if !session.loggedSets.isEmpty {
                outcome = .partial
            } else {
                outcome = .startedOnly
            }
            occurrences.append(.init(date: session.startTime, outcome: outcome))
        }
        return (occurrences, hasExcludedUnattributable)
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
