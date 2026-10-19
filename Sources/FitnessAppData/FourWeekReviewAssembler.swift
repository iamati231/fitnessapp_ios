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
    /// Referenz zurück zu ihrem Plan. `realOccurrences(in:for:)` isoliert die
    /// Soll-Ist-Teilnahme korrekt pro Plan, OHNE diese Referenz je rückwärts
    /// zu lesen (seit dem Build-164-Fund per VORWÄRTS-Traversal von
    /// `plan.days`/`day.sessions` — siehe dessen Dokumentation für die vier
    /// unterschiedenen Fälle und warum unklare Historie ausgeschlossen statt
    /// geraten wird).
    /// P8 Stufe 3: `participation` und `latestCheckIn` sind jetzt
    /// BLOCKBEZOGEN (seit `FourWeekReviewDueStatus.currentBlockStart(for:)`,
    /// nicht mehr seit `plan.activatedAt` über die gesamte Planlaufzeit) —
    /// für den ersten Block identisch zu vorher (`currentBlockStart` liefert
    /// dort exakt `activatedAt`), für jeden Folgeblock zählt nur noch, was
    /// SEIT dem letzten Abschluss passiert ist. Ein Check-in aus einem
    /// vorigen Block wird dadurch nie als aktuell übernommen (siehe
    /// `latestCheckInFeedback`). Deload/Comeback bleiben unverändert GLOBAL
    /// (personen-, nicht blockbezogen) — eigenständige, bereits getroffene
    /// Produktentscheidung, keine Lücke.
    public static func assemble(
        in context: ModelContext,
        for plan: TrainingPlan? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FourWeekReviewOrchestrator.Review {
        let resolvedPlan = plan ?? primaryActivePlan(in: context)
        let blockStart = resolvedPlan.flatMap {
            FourWeekReviewDueStatus.currentBlockStart(for: $0, calendar: calendar)
        }

        // P9-Fund: die fuer die Teilnahme-Eingabe noetigen Fetches (Plaene,
        // Tage, Sessions, siehe `realOccurrences`) wurden bisher per `try?`
        // stillschweigend zu "keine Ergebnisse" degradiert — ein echter
        // Fetch-Fehler waere so als "keine Trainings" oder "kein zweiter
        // aktiver Plan, also keine Mehrdeutigkeit" FEHLINTERPRETIERT worden,
        // statt als das auszuweisen, was er ist: eine unvollstaendige
        // Datengrundlage. Deshalb hier explizit abgefangen, BEVOR
        // `PlanParticipationEvaluator.evaluate` ueberhaupt mit (potenziell
        // unvollstaendigen) Daten aufgerufen wird — bestehende
        // Anrechnungsregeln fuer den Normalfall (kein Fetch-Fehler) bleiben
        // dabei unveraendert.
        let participation: PlanParticipationEvaluator.Result
        do {
            let input = try participationInput(in: context, for: resolvedPlan, periodStart: blockStart, calendar: calendar)
            participation = PlanParticipationEvaluator.evaluate(input, asOf: now)
        } catch {
            participation = .notReliablyEvaluable(.underlyingDataFetchFailed)
        }

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
            latestCheckIn: latestCheckInFeedback(in: context, since: blockStart, asOf: now),
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

    /// `periodStart` ist der Beginn des AKTUELL zu bewertenden Blocks
    /// (`FourWeekReviewDueStatus.currentBlockStart(for:)`, vom Aufrufer
    /// übergeben) — für den ersten Block identisch zu `plan.activatedAt`,
    /// für jeden Folgeblock der Kalendertag nach dem vorigen Abschluss.
    /// `PlanParticipationEvaluator.Input.activatedAt` ist dafür technisch
    /// nur ein Periodenstart-Parameter, kein Zwang zur echten
    /// Plan-Aktivierung (siehe dessen eigene Dokumentation) — kein neuer
    /// Evaluator nötig.
    /// Wirft (statt `try?` zu schlucken), damit `assemble` einen echten
    /// Fetch-Fehler von einer leeren, aber erfolgreich gelesenen Datenlage
    /// unterscheiden kann (P9-Fund, siehe `assemble`-Dokumentation).
    private static func participationInput(
        in context: ModelContext,
        for plan: TrainingPlan?,
        periodStart: Date?,
        calendar: Calendar
    ) throws -> PlanParticipationEvaluator.Input {
        guard let plan else {
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
        // Session-ohne-Tag-Referenz alternativ meinen koennte. Bewusst ein
        // EIGENER, werfender Fetch statt der oeffentlichen `allActivePlans(in:)`
        // (die bleibt fuer ihre bestehenden Aufrufer — UI-Picker,
        // `FourWeekReviewDueStatus` — unveraendert: dort IST eine leere Liste
        // ein legitimer, sichtbarer Zustand "kein aktiver Plan"). Hier
        // dagegen wuerde ein geschluckter Fetch-Fehler fälschlich als "kein
        // zweiter aktiver Plan, also keine Mehrdeutigkeit" interpretiert.
        let multipleActivePlans = try context.fetch(FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.isActive == true }
        )).count > 1
        let (occurrences, excludedUnattributableDates) = try realOccurrences(
            in: context, for: plan, ambiguousAcrossActivePlans: multipleActivePlans
        )

        return PlanParticipationEvaluator.Input(
            activatedAt: periodStart,
            isActive: plan.isActive,
            occurrences: occurrences,
            nonRestDayCount: nonRestDays.count,
            nonRestWeekdays: Set(nonRestDays.map(\.weekday)),
            usesFixedWeekdays: plan.generatorInput?.usesFixedWeekdays,
            excludedUnattributableDates: excludedUnattributableDates,
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
    /// wird einzeln bewertet. Zuordnung geschieht AUSSCHLIESSLICH über
    /// VORWÄRTS-Traversal von frisch gefetchten, garantiert lebenden
    /// `TrainingPlan`/`TrainingDay`-Wurzeln (`plan.days` → `day.sessions`) —
    /// NIE über eine rückwärtige `session.day?.plan`-Dereferenzierung auf
    /// einer beliebigen, app-weit gefetchten Session. Grund (Build-164-Fund,
    /// siehe `docs/TESTFLIGHT_CRASH_164.md`): `WorkoutSession.day` trug auf
    /// mindestens einem Testgerät, bereits vor dem Nullify-Inverse-Fix
    /// (`4e656eb9`), eine verwaiste Referenz auf eine längst gelöschte
    /// `TrainingDay`-Zeile. Das Lesen von `.day` selbst crasht dabei nicht,
    /// aber JEDES Lesen einer gespeicherten Eigenschaft auf dem Ziel (hier
    /// `.plan`) löst `_InvalidFutureBackingData` aus — ein fataler Abbruch,
    /// den auch optionales Verketten nicht abfängt. Diese Funktion liest
    /// deshalb auf `WorkoutSession` nur noch EIGENE, immer sichere
    /// Eigenschaften (`persistentModelID`, `isCompleted`, `loggedSets`,
    /// `startTime`) und ordnet ausschließlich über zuvor vorwärts
    /// gesammelte Mengen von Session-IDs zu. Drei Fälle, pro Session:
    ///   1. ID in `ownSessionIDs` (über `plan.days` → `day.sessions`
    ///      erreichbar) → zählt für GENAU diesen Plan.
    ///   2. ID in `otherPlanSessionIDs` (über einen ANDEREN, ebenfalls
    ///      frisch gefetchten Plan erreichbar) → zählt NICHT. Unabhängig
    ///      davon, ob dieser andere Plan noch aktiv ist — ein Plan zählt nie
    ///      Sessions, die strukturell einem anderen Plan gehören.
    ///   3. Weder 1 noch 2, aber ID in `anyDayOwnedSessionIDs` (über einen
    ///      frisch gefetchten `TrainingDay` OHNE Plan erreichbar, also ein
    ///      echter Ad-hoc-Tag) → zählt bewusst für JEDEN aktiven Plan mit,
    ///      wer frei statt nach Plan trainiert hat, hat an dem Tag trotzdem
    ///      real trainiert.
    ///   4. Weder 1 noch 2 noch 3 — die Session hat entweder GAR KEINE
    ///      Tag-Referenz (CSV-Import/Restore setzt sie nie) ODER eine
    ///      verwaiste Altreferenz auf eine nicht mehr existierende Zeile
    ///      (Build-164-Szenario). Beide Unterfälle sind von hier aus bewusst
    ///      NICHT unterscheidbar, ohne die gefährliche Rückreferenz zu
    ///      lesen, und werden deshalb gleich behandelt: bei genau einem
    ///      aktiven Plan unproblematisch (keine Alternative, der die Session
    ///      gehören könnte, zählt wie echtes Ad-hoc) — bei mehreren aktiven
    ///      Plänen lässt sich das NICHT mehr zuverlässig auflösen. Statt über
    ///      `dayName`/Plan-Namen zu raten oder die Session irgendeinem Plan
    ///      stillschweigend gutzuschreiben, wird sie dann ausgeschlossen —
    ///      sichtbar gemacht über `excludedUnattributableDates` /
    ///      `.unattributableHistoryExcludedDueToMultipleActivePlans`. Das
    ///      Datum der Session (nicht nur ein pauschales Bool) wird dabei
    ///      mitgegeben, damit `PlanParticipationEvaluator` die Datenlücke nur
    ///      fuer den Block zeigt, in den die ausgeschlossene Session
    ///      tatsächlich fällt (P9-Fund gegen `fce424e`).
    ///
    /// Wirft (statt `try?` zu schlucken, P9-Fund): ein fehlgeschlagener
    /// Plan-/Tage-/Session-Fetch darf nicht stillschweigend zu "keine
    /// anderen Pläne"/"keine Tage"/"keine Sessions" werden — das würde hier
    /// Sessions, die tatsächlich einem ANDEREN Plan gehören, fälschlich
    /// diesem Plan gutschreiben (weil `otherPlanSessionIDs` dann faelschlich
    /// leer wäre), statt den Fehler an `assemble` durchzureichen.
    private static func realOccurrences(
        in context: ModelContext,
        for plan: TrainingPlan,
        ambiguousAcrossActivePlans: Bool
    ) throws -> (occurrences: [PlanParticipationEvaluator.SessionOccurrence], excludedUnattributableDates: [Date]) {
        let allPlans = try context.fetch(FetchDescriptor<TrainingPlan>())
        let allDays = try context.fetch(FetchDescriptor<TrainingDay>())

        let ownSessionIDs = Set(plan.days.flatMap { $0.sessions.map(\.persistentModelID) })
        let otherPlanSessionIDs = Set(
            allPlans
                .filter { $0.persistentModelID != plan.persistentModelID }
                .flatMap { $0.days.flatMap { $0.sessions.map(\.persistentModelID) } }
        )
        let anyDayOwnedSessionIDs = Set(allDays.flatMap { $0.sessions.map(\.persistentModelID) })

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isRestDay == false }
        ))

        // P9-Fund (gegen `fce424e` geprüft): NICHT mehr nur EIN Bool — das
        // Datum jeder ausgeschlossenen Session wird mitgeführt, damit
        // `PlanParticipationEvaluator` sie auf den aktuell bewerteten Block
        // zeitfenstern kann. Ohne das haette eine unattribuierbare Session
        // aus einem LAENGST VERGANGENEN Block faelschlich auch den
        // AKTUELLEN Block als Datenluecke markiert.
        var excludedUnattributableDates: [Date] = []
        var occurrences: [PlanParticipationEvaluator.SessionOccurrence] = []
        for session in sessions {
            let id = session.persistentModelID
            if otherPlanSessionIDs.contains(id) { continue }
            if !ownSessionIDs.contains(id) && !anyDayOwnedSessionIDs.contains(id) {
                if ambiguousAcrossActivePlans {
                    excludedUnattributableDates.append(session.startTime)
                    continue
                }
            }
            // Verbleibende Fälle: eigene Session (Fall 1), Ad-hoc-Tag ohne
            // Plan (Fall 3), oder — bei nur einem aktiven Plan — keine/
            // verwaiste Tag-Referenz (Fall 4).
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
        return (occurrences, excludedUnattributableDates)
    }

    // MARK: - Periodisches Feedback (P6.3, P8 Stufe 3 blockbezogen)

    /// P8 Stufe 3: nur noch ein Check-in INNERHALB des aktuell offenen
    /// Blocks (`since`...`asOf`) zählt — ein Check-in aus einem vorigen
    /// Block wird NIE als aktuell übernommen. `since == nil` (kein
    /// bekannter Blockbeginn, z. B. `activatedAt` unbekannt) lässt die
    /// Untergrenze bewusst offen, statt eine Datenlücke zu melden, wo
    /// tatsächlich ein Check-in vorliegt — dieselbe konservative
    /// Fallback-Haltung wie beim Teilnahme-Evaluator.
    ///
    /// `PeriodicCheckIn` bleibt PERSONENBEZOGEN, nicht planbezogen — bei
    /// mehreren aktiven Plänen zählt derselbe Check-in für jeden Block
    /// jedes Plans, der zeitlich hineinfällt (keine neue, hier eingeführte
    /// Planbindung).
    private static func latestCheckInFeedback(
        in context: ModelContext,
        since blockStart: Date?,
        asOf: Date
    ) -> FourWeekReviewOrchestrator.CheckInFeedback? {
        let descriptor = FetchDescriptor<PeriodicCheckIn>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let checkIns = (try? context.fetch(descriptor)) ?? []
        guard let latest = checkIns.first(where: { checkIn in
            guard checkIn.date <= asOf else { return false }
            if let blockStart { return checkIn.date >= blockStart }
            return true
        }) else { return nil }
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
