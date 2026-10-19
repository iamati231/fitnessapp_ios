import Foundation

/// P6.2: Planbezogene Soll-Ist-Teilnahmeauswertung — reine, deterministische
/// Core-Logik (kein SwiftData, kein `Date()`/`Calendar.current` im Code-Pfad
/// selbst — Auswertungsdatum und Calendar werden immer injiziert).
///
/// **Bewusste Grenzen, direkt aus dem Gesamtmandat:**
///   * Nie einen historischen Soll-Zustand erfinden. Fehlt der Aktivierungs-
///     anker (`TrainingPlan.activatedAt`, P6.1) oder die aktuelle
///     Trainingstage-Struktur, liefert dieser Evaluator `.notReliablyEvaluable`
///     statt eine Zahl zu raten.
///   * Keine automatische kalendergesteuerte Belastungssteigerung — dieser
///     Typ berechnet ausschliesslich eine RUECKBLICKENDE Teilnahme-Kennzahl.
///     Er loest nichts aus, veraendert keinen Plan und liefert keine
///     Progressions-Empfehlung.
///   * `activatedAt` ist NUR der Start der aktuellen, ununterbrochenen
///     Aktivierungsperiode — keine vollstaendige Aktivierungshistorie (es
///     gibt kein `deactivatedAt`). Ein aktuell inaktiver Plan wird deshalb
///     grundsaetzlich NICHT bewertet (`.planNotCurrentlyActive`), weil das
///     tatsaechliche Ende seiner letzten aktiven Phase nicht bekannt ist.
///   * Mehrere gleichzeitig aktive Plaene sind ein bewusstes Produktverhalten
///     (Task #201/#202) — dieser Typ bewertet IMMER genau einen Plan. Der
///     Aufrufer ruft ihn pro aktivem Plan separat auf; es gibt hier keine
///     globale "ein Plan"-Annahme.
public enum PlanParticipationEvaluator {

    // MARK: - Input

    /// Eine einzelne reale Trainings-Session, auf einen Kalendertag reduziert.
    /// Bewusst kein `WorkoutSession` (das ist ein `@Model`) — der Aufrufer in
    /// `FitnessAppData` mappt nur das, was fuer die Auswertung zaehlt.
    public struct SessionOccurrence: Sendable, Equatable {
        /// Kalendertag der Session (`WorkoutSession.startTime`). Wird intern
        /// per `calendar.startOfDay` normalisiert — die Uhrzeit ist irrelevant.
        public let date: Date
        public let outcome: Outcome

        public init(date: Date, outcome: Outcome) {
            self.date = date
            self.outcome = outcome
        }

        /// Drei-Stufen-Klassifikation (verbindliche Vorgabe: abgeschlossen,
        /// teilweise absolviert und lediglich gestartet muessen getrennt
        /// sichtbar bleiben, nie zu einem einzigen "hat trainiert"-Bit
        /// zusammengefasst werden).
        public enum Outcome: Sendable, Equatable, Comparable {
            /// Keine einzige Uebung geloggt — Session wurde eroeffnet, aber
            /// nie wirklich begonnen (`WorkoutSession.isCompleted == false`,
            /// `logs.isEmpty`).
            case startedOnly
            /// Mindestens ein Satz geloggt, aber nie regulaer ueber "Beenden"
            /// abgeschlossen (`isCompleted == false`, `!logs.isEmpty`).
            case partial
            /// Regulaer abgeschlossen (`isCompleted == true`).
            case completed

            /// Rangfolge fuer "bester Ausgang eines Kalendertags" — mehrere
            /// Sessions am selben Tag (siehe Regel 3) werden auf den
            /// staerksten Ausgang verdichtet, niemals aufsummiert.
            public static func < (lhs: Outcome, rhs: Outcome) -> Bool {
                rank(lhs) < rank(rhs)
            }
            private static func rank(_ o: Outcome) -> Int {
                switch o {
                case .startedOnly: return 0
                case .partial: return 1
                case .completed: return 2
                }
            }
        }
    }

    /// Wie der Plan seine Trainingstage terminiert.
    public enum ScheduleKind: Sendable, Equatable {
        /// Jeder Trainingstag haengt an einem festen Kalender-Wochentag
        /// (Apple-Calendar-Konvention, 1=So...7=Sa). Leer ist unzulaessig —
        /// der Aufrufer liefert dann stattdessen `.planHasNoTrainingDays`.
        case fixedWeekdays(Set<Int>)
        /// Sequentielle Rotation ohne Wochentag-Bindung — "wie oft pro Woche"
        /// zaehlt, nicht "an welchem Tag" (`PlanNavigator`-Modell).
        case flexibleWeeklyCadence(sessionsPerWeek: Int)
    }

    public struct Input: Sendable, Equatable {
        /// `nil` = unbekannt. Siehe Typ-Dokumentation — niemals rueckwirkend
        /// erfinden, auch nicht aus dem fruehesten geloggten Workout.
        public let activatedAt: Date?
        public let isActive: Bool
        public let occurrences: [SessionOccurrence]
        /// Anzahl Trainingstage (nicht Ruhetage) in der AKTUELLEN Planstruktur.
        public let nonRestDayCount: Int
        /// Wochentage der aktuellen Trainingstage (nicht Ruhetage). Nur fuer
        /// `.fixedWeekdays` relevant, wird aber immer mitgegeben, weil der
        /// Aufrufer es ohnehin aus `TrainingDay.weekday` kennt.
        public let nonRestWeekdays: Set<Int>
        /// `PlanGeneratorInput.usesFixedWeekdays`, wenn bekannt. `nil` heisst:
        /// kein Generator-Input vorhanden (manuell gebauter oder vor diesem
        /// Feature importierter Plan) — die Terminierungsabsicht ist schlicht
        /// nicht erfasst. Wird konservativ wie `false` (flexibel) behandelt,
        /// aber als Annahme offengelegt (Regel 6/8: keine Scheinpraezision).
        public let usesFixedWeekdays: Bool?
        /// Der Aufrufer hat beim Zusammenstellen von `occurrences` reale
        /// Sessions herausgefiltert, die sich keinem bestimmten Plan sicher
        /// zuordnen ließen (siehe `DataGap.unattributableHistoryExcludedDueToMultipleActivePlans`).
        /// `false`, wenn entweder keine solchen Sessions existierten oder nur
        /// ein Plan aktiv war (dort gibt es keine Mehrdeutigkeit).
        public let hasUnattributableSessionsExcluded: Bool
        public let calendar: Calendar

        public init(
            activatedAt: Date?,
            isActive: Bool,
            occurrences: [SessionOccurrence],
            nonRestDayCount: Int,
            nonRestWeekdays: Set<Int>,
            usesFixedWeekdays: Bool?,
            hasUnattributableSessionsExcluded: Bool = false,
            calendar: Calendar
        ) {
            self.activatedAt = activatedAt
            self.isActive = isActive
            self.occurrences = occurrences
            self.nonRestDayCount = nonRestDayCount
            self.nonRestWeekdays = nonRestWeekdays
            self.usesFixedWeekdays = usesFixedWeekdays
            self.hasUnattributableSessionsExcluded = hasUnattributableSessionsExcluded
            self.calendar = calendar
        }
    }

    // MARK: - Output

    public enum Result: Sendable, Equatable {
        case notReliablyEvaluable(UnreliableReason)
        case evaluated(Summary)
    }

    /// Warum (noch) keine Aussage moeglich ist — niemals stattdessen eine
    /// 0%- oder 0-von-0-Zahl zeigen (Regel 8).
    public enum UnreliableReason: Sendable, Equatable, Codable {
        /// `activatedAt == nil` (Regel 6).
        case activationStartUnknown
        /// `isActive == false` — kein `deactivatedAt` bekannt, also kein
        /// verlaesslicher Periodenende-Zeitpunkt (Regel 7).
        case planNotCurrentlyActive
        /// `evaluationDate < activatedAt` — Dateninkonsistenz, nicht crashen.
        case evaluationBeforeActivation
        /// Plan hat strukturell keinen einzigen Trainingstag (nur Ruhetage).
        case planHasNoTrainingDays
        /// Seit Aktivierung ist proportional noch keine einzige Einheit
        /// faellig geworden (Regel 5) — 0 von 0 waere eine Scheinaussage.
        case noOpportunityDueYet
    }

    /// Welche Zaehlregel tatsaechlich angewendet wurde — maschinenlesbar
    /// und testbar, damit eine spaetere UI/Lokalisierung sie 1:1 uebersetzen
    /// kann, statt freien Text aus Core zu uebernehmen.
    public enum CountingRule: Sendable, Equatable {
        case fixedWeekdaysMatched(Set<Int>)
        case flexibleWeeklyCadence(sessionsPerWeek: Int)
        case duplicateSameDayOccurrencesCollapsedToBestOutcome
        case offScheduleOccurrencesNotCredited
        case occurrencesBeyondCadenceNotCredited
        case notYetDueOpportunitiesExcluded
    }

    /// Bekannte Grenzen DIESER konkreten Auswertung — immer mitgeliefert,
    /// nicht nur im Fehlerfall (Regel 7: ein einzelnes `activatedAt` ist nie
    /// eine vollstaendige Aktivierungshistorie; Planaenderungen innerhalb der
    /// Periode werden nicht erkannt, weil es keine Versionierung gibt).
    public enum DataGap: Sendable, Equatable {
        case singleActivationAnchorOnly
        case planStructureChangesDuringPeriodNotTracked
        case scheduleKindUnknownAssumedFlexible
        /// Der Aufrufer hat reale Sessions ausgeschlossen, weil sie sich bei
        /// mehreren gleichzeitig aktiven Plänen keinem bestimmten Plan
        /// zuordnen ließen (z. B. aus einem Backup importierte Einheiten ohne
        /// Tag-Referenz) — nie geraten (keine Namens-Zuordnung), nie
        /// stillschweigend diesem oder einem anderen Plan gutgeschrieben.
        /// Bei nur einem aktiven Plan tritt dieser Fall nicht auf, weil dort
        /// keine Mehrdeutigkeit besteht.
        case unattributableHistoryExcludedDueToMultipleActivePlans
    }

    public struct Summary: Sendable, Equatable {
        public let periodStart: Date
        public let periodEnd: Date
        public let scheduleKindUsed: ScheduleKind
        public let plannedCount: Int
        public let completedCount: Int
        public let partialCount: Int
        public let startedOnlyCount: Int
        /// `plannedCount - (completed + partial + startedOnly)` — faellige,
        /// aber ohne jede Session gebliebene Gelegenheiten. Nie negativ.
        public let missedCount: Int
        /// Reale Vorkommnisse, die NICHT auf den Soll-Zaehler angerechnet
        /// wurden (Regel 3): bei festen Wochentagen Trainings an einem
        /// Nicht-Plantag, bei flexibler Kadenz Einheiten ueber die bereits
        /// faellige Anzahl hinaus. Zaehlt niemals einen anderswo fehlenden
        /// Termin auf.
        public let extraOccurrenceCount: Int
        public let countingRules: [CountingRule]
        public let dataGaps: [DataGap]

        public init(
            periodStart: Date,
            periodEnd: Date,
            scheduleKindUsed: ScheduleKind,
            plannedCount: Int,
            completedCount: Int,
            partialCount: Int,
            startedOnlyCount: Int,
            missedCount: Int,
            extraOccurrenceCount: Int,
            countingRules: [CountingRule],
            dataGaps: [DataGap]
        ) {
            self.periodStart = periodStart
            self.periodEnd = periodEnd
            self.scheduleKindUsed = scheduleKindUsed
            self.plannedCount = plannedCount
            self.completedCount = completedCount
            self.partialCount = partialCount
            self.startedOnlyCount = startedOnlyCount
            self.missedCount = missedCount
            self.extraOccurrenceCount = extraOccurrenceCount
            self.countingRules = countingRules
            self.dataGaps = dataGaps
        }
    }

    // MARK: - Evaluation

    public static func evaluate(_ input: Input, asOf evaluationDate: Date) -> Result {
        guard input.isActive else {
            return .notReliablyEvaluable(.planNotCurrentlyActive)
        }
        guard let activatedAt = input.activatedAt else {
            return .notReliablyEvaluable(.activationStartUnknown)
        }

        let calendar = input.calendar
        let periodStart = calendar.startOfDay(for: activatedAt)
        let periodEnd = calendar.startOfDay(for: evaluationDate)
        guard periodStart <= periodEnd else {
            return .notReliablyEvaluable(.evaluationBeforeActivation)
        }

        let scheduleKindAssumed = input.usesFixedWeekdays == nil
        let useFixed = input.usesFixedWeekdays == true
        let scheduleKindUsed: ScheduleKind
        if useFixed {
            guard !input.nonRestWeekdays.isEmpty else {
                return .notReliablyEvaluable(.planHasNoTrainingDays)
            }
            scheduleKindUsed = .fixedWeekdays(input.nonRestWeekdays)
        } else {
            guard input.nonRestDayCount > 0 else {
                return .notReliablyEvaluable(.planHasNoTrainingDays)
            }
            scheduleKindUsed = .flexibleWeeklyCadence(sessionsPerWeek: input.nonRestDayCount)
        }

        // Je Kalendertag auf den staerksten Ausgang verdichten (Regel 3) —
        // zwei Sessions am selben Tag duerfen nie wie zwei erfuellte
        // Gelegenheiten zaehlen.
        var bestOutcomeByDay: [Date: SessionOccurrence.Outcome] = [:]
        for occurrence in input.occurrences {
            let day = calendar.startOfDay(for: occurrence.date)
            guard day >= periodStart, day <= periodEnd else { continue }
            if let existing = bestOutcomeByDay[day] {
                bestOutcomeByDay[day] = max(existing, occurrence.outcome)
            } else {
                bestOutcomeByDay[day] = occurrence.outcome
            }
        }

        var countingRules: [CountingRule] = [.notYetDueOpportunitiesExcluded, .duplicateSameDayOccurrencesCollapsedToBestOutcome]
        var dataGaps: [DataGap] = [.singleActivationAnchorOnly, .planStructureChangesDuringPeriodNotTracked]
        if scheduleKindAssumed {
            dataGaps.append(.scheduleKindUnknownAssumedFlexible)
        }
        if input.hasUnattributableSessionsExcluded {
            dataGaps.append(.unattributableHistoryExcludedDueToMultipleActivePlans)
        }

        let matchedOutcomes: [SessionOccurrence.Outcome]
        let extraOccurrenceCount: Int
        let plannedCount: Int

        switch scheduleKindUsed {
        case .fixedWeekdays(let weekdays):
            var plannedDates: [Date] = []
            var cursor = periodStart
            while cursor <= periodEnd {
                let weekday = calendar.component(.weekday, from: cursor)
                if weekdays.contains(weekday) {
                    plannedDates.append(cursor)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            plannedCount = plannedDates.count
            countingRules.append(.fixedWeekdaysMatched(weekdays))

            matchedOutcomes = plannedDates.compactMap { bestOutcomeByDay[$0] }
            let plannedDateSet = Set(plannedDates)
            let offScheduleCount = bestOutcomeByDay.keys.filter { !plannedDateSet.contains($0) }.count
            extraOccurrenceCount = offScheduleCount
            if extraOccurrenceCount > 0 {
                countingRules.append(.offScheduleOccurrencesNotCredited)
            }

        case .flexibleWeeklyCadence(let sessionsPerWeek):
            let elapsedDays = (calendar.dateComponents([.day], from: periodStart, to: periodEnd).day ?? 0) + 1
            plannedCount = Int(floor(Double(elapsedDays) / 7.0 * Double(sessionsPerWeek)))
            countingRules.append(.flexibleWeeklyCadence(sessionsPerWeek: sessionsPerWeek))

            let sortedDays = bestOutcomeByDay.keys.sorted()
            matchedOutcomes = sortedDays.prefix(plannedCount).compactMap { bestOutcomeByDay[$0] }
            extraOccurrenceCount = max(0, sortedDays.count - plannedCount)
            if extraOccurrenceCount > 0 {
                countingRules.append(.occurrencesBeyondCadenceNotCredited)
            }
        }

        guard plannedCount > 0 else {
            return .notReliablyEvaluable(.noOpportunityDueYet)
        }

        let completedCount = matchedOutcomes.filter { $0 == .completed }.count
        let partialCount = matchedOutcomes.filter { $0 == .partial }.count
        let startedOnlyCount = matchedOutcomes.filter { $0 == .startedOnly }.count
        let missedCount = max(0, plannedCount - (completedCount + partialCount + startedOnlyCount))

        return .evaluated(Summary(
            periodStart: periodStart,
            periodEnd: periodEnd,
            scheduleKindUsed: scheduleKindUsed,
            plannedCount: plannedCount,
            completedCount: completedCount,
            partialCount: partialCount,
            startedOnlyCount: startedOnlyCount,
            missedCount: missedCount,
            extraOccurrenceCount: extraOccurrenceCount,
            countingRules: countingRules,
            dataGaps: dataGaps
        ))
    }
}
