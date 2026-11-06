import Foundation

/// AI-Running-Coach Phase 2, Work Package 2B (docs/superpowers/plans/
/// 2026-11-06-ai-running-coach-phase2-implementation.md): deterministische
/// Trendanalyse auf dem bereits existierenden Wochen-Aggregat aus Work
/// Package 2A (`TrainingLoadWeek`/`TrainingLoadAggregator`). Reine Funktion,
/// keine SwiftData-/SwiftUI-Abhaengigkeit, kein neuer Aggregationsschritt —
/// liest ausschliesslich `[TrainingLoadWeek]`, das 2A bereits liefert.
///
/// **Bekannte Modellgrenzen (dokumentiert statt erfunden, Ticket Teil 9):**
/// `CardioVolumeOverTimePoint` (Phase 1, von `TrainingLoadWeek.running`
/// eingebettet) traegt keine Lauf-GESAMTDAUER (nur Durchschnitts-Pace) und
/// keine Distanz/Dauer fuer sonstige Ausdaueraktivitaeten (nur eine
/// Sessionzahl). Eine Erweiterung dieser Typen waere eine Aenderung an
/// bereits abgeschlossenen Arbeitspaketen (Phase 1 bzw. 2A) - stattdessen
/// bleiben die entsprechenden Kennzahlen hier bewusst UNMODELLIERT statt
/// erfunden; siehe Design-Dokument fuer die vollstaendige Begruendung.
public enum TrainingLoadTrendAnalyzer {

    // MARK: - Zentrale, dokumentierte Produktregeln (Ticket: "zentral
    // definiert, dokumentiert und getestet")

    /// Vergleichsfenster fuer "stark schwankend" (Variationskoeffizient) und
    /// fuer den Vorherige-Wochen-Durchschnitt: aktuelle + 4 vorherige
    /// VOLLSTAENDIGE Wochen.
    public static let comparisonWindowWeeks = 5
    /// Anstieg ggue. dem Durchschnitt der vorherigen vollstaendigen Wochen,
    /// ab dem ein moderater Belastungsanstieg vorliegt. Bewusst identisch zu
    /// `RaceProgressAssessment.loadIncreaseThreshold` (Phase 1) - keine neu
    /// erfundene Zahl fuer denselben Sachverhalt.
    public static let moderateIncreaseThreshold = 0.25
    /// Ab hier gilt ein Anstieg als deutlich - konsistent mit dem
    /// Ticket-Beispiel (18km -> 27km = +50%).
    public static let significantIncreaseThreshold = 0.50
    /// Variationskoeffizient (Standardabweichung / Mittelwert) ueber die
    /// Wochen im Vergleichsfenster, ab dem das Volumen als "stark
    /// schwankend" statt als gerichteter Trend gilt.
    public static let variabilityCoefficientThreshold = 0.30
    /// Mindestanzahl VOLLSTAENDIGER Wochen fuer jede Trendaussage - weniger
    /// ist eine erfundene Praezision (Ticket: "insufficientData").
    public static let minimumCompleteWeeksForTrend = 3
    /// Acute:Chronic (Ticket Teil 5): 4 vollstaendige Wochen = 28 Tage bei
    /// wochengranularer Aggregation (siehe Typ-Dokumentation unten fuer die
    /// bewusste Rundung von "Tage" auf "Kalenderwochen").
    public static let acuteChronicChronicWindowWeeks = 4

    // MARK: - Eintrittspunkt

    /// `weeks`: unveraendert aus `TrainingLoadAggregator.aggregate(...)`,
    /// aelteste zuerst, lueckenlos. Diese Funktion fuegt KEINE Woche hinzu
    /// und entfernt keine - Vergleiche, die mehr Wochen brauchten als
    /// vorhanden sind, werden explizit als nicht berechenbar markiert statt
    /// das Array stillschweigend zu erweitern (Ticket: "fehlende Wochen
    /// duerfen nicht als bestaetigte Nullbelastung behandelt werden" - eine
    /// Woche VOR `weeks.first` existiert fuer diese Funktion schlicht nicht,
    /// wird nie als 0 angenommen).
    public static func analyze(
        weeks: [TrainingLoadWeek],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TrainingLoadTrend {
        let currentWeek = weeks.last
        let isCurrentWeekComplete = currentWeek.map { isComplete($0, now: now, calendar: calendar) } ?? false

        func trend(_ value: @escaping (TrainingLoadWeek) -> Double) -> WeeklyMetricTrend {
            metricTrend(weeks: weeks, value: value, now: now, calendar: calendar)
        }

        let runningDistance = trend(\.running.runningDistanceKm)
        let runningSessions = trend { Double($0.running.runningSessionCount) }
        let strengthSessions = trend { Double($0.strengthSessionCount) }
        let strengthSets = trend { Double($0.strengthSetCount) }
        let strengthVolume = trend(\.strengthVolumeKg)
        let otherEnduranceSessions = trend { Double($0.running.crossTrainingSessionCount) }
        let ambiguousSessions = trend { Double($0.running.ambiguousCardioSessionCount) }

        let running = RunningLoadTrend(weeklyDistanceKm: runningDistance, weeklySessionCount: runningSessions)
        let strength = StrengthLoadTrend(weeklySessionCount: strengthSessions, weeklySetCount: strengthSets, weeklyVolumeKg: strengthVolume)
        let otherEndurance = OtherEnduranceLoadTrend(weeklySessionCount: otherEnduranceSessions)
        let overall = OverallTrainingSummary(weeklyAmbiguousSessionCount: ambiguousSessions, weeklyTotalDurationSeconds: nil)

        let loadDevelopment = combineLoadDevelopment(running: runningDistance, strength: strengthVolume)
        let acr = acuteChronicRatio(weeks: weeks, now: now, calendar: calendar)
        let completenessHistoricalWeekCount = weeks.dropLast().filter { isComplete($0, now: now, calendar: calendar) }.count
        let completeness = dataCompleteness(
            weeks: weeks, historicalWeekCount: completenessHistoricalWeekCount, isCurrentWeekComplete: isCurrentWeekComplete
        )

        return TrainingLoadTrend(
            analyzedWeeks: weeks,
            currentWeek: currentWeek,
            isCurrentWeekComplete: isCurrentWeekComplete,
            running: running,
            strength: strength,
            otherEndurance: otherEndurance,
            overall: overall,
            loadDevelopment: loadDevelopment,
            acuteChronicRatio: acr,
            dataCompleteness: completeness
        )
    }

    // MARK: - Woche vollstaendig?

    /// Eine Woche ist "vollstaendig", wenn ihr Kalenderwochen-Ende bereits
    /// erreicht ist - die letzte Woche in `weeks` enthaelt `now` meist noch
    /// und ist damit eine LAUFENDE, unvollstaendige Woche (Ticket: "laufende
    /// vs. abgeschlossene Kalenderwoche").
    static func isComplete(_ week: TrainingLoadWeek, now: Date, calendar: Calendar) -> Bool {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: week.weekStart) else { return false }
        return interval.end <= now
    }

    // MARK: - Einzelkennzahl: aktueller Wert + Vergleich

    /// `weeks`: unveraendertes Eingabe-Array, aelteste zuerst. `value`
    /// liest die konkrete Kennzahl (z.B. Laufkilometer) aus einer Woche.
    ///
    /// **Wichtige Invariante (Bugfix waehrend der eigenen Testerstellung
    /// gefunden):** die AKTUELLE Woche (`weeks.last`) darf NIE Teil ihrer
    /// EIGENEN Vergleichsbasis sein - auch nicht, wenn sie zufaellig bereits
    /// kalendarisch vollstaendig ist. Deshalb wird die Vergleichsbasis fuer
    /// `changeVsPreviousWeeksAverage` STRUKTURELL aus `weeks.dropLast()`
    /// gebildet (nie aus einer reinen Vollstaendigkeits-Filterung des
    /// GESAMTEN Arrays, die die letzte Woche faelschlich mit einschliessen
    /// koennte). Zwei getrennte Vergleiche (Ticket Teil 3):
    ///   1. `changeVsPreviousCompleteWeek`: letzte vollstaendige Woche GEGEN
    ///      GENAU die eine Woche davor (kein Durchschnitt) - darf die
    ///      aktuelle Woche einschliessen, WENN sie selbst vollstaendig ist.
    ///   2. `changeVsPreviousWeeksAverage`: aktuelle (ggf. unvollstaendige)
    ///      Woche gegen den Durchschnitt ALLER historischen (= vor ihr
    ///      liegenden) vollstaendigen Wochen - treibt `classification` an,
    ///      identisch zum Ticket-Beispiel "vorherige 4 Wochen im Schnitt
    ///      18km, aktuelle Woche 27km = +50%".
    static func metricTrend(weeks: [TrainingLoadWeek], value: (TrainingLoadWeek) -> Double, now: Date, calendar: Calendar) -> WeeklyMetricTrend {
        let current = weeks.last.map(value)
        let historical = weeks.dropLast().filter { isComplete($0, now: now, calendar: calendar) }.map(value)
        let allComplete = weeks.filter { isComplete($0, now: now, calendar: calendar) }.map(value)

        let lastComplete = allComplete.last
        let singlePreviousWeek = allComplete.dropLast().last
        let changeVsPreviousCompleteWeek: MetricChange? = {
            guard let lastComplete, let singlePreviousWeek else { return nil }
            return MetricChange(previous: singlePreviousWeek, current: lastComplete)
        }()

        let historicalAverage = historical.isEmpty ? nil : historical.reduce(0, +) / Double(historical.count)
        let changeVsPreviousWeeksAverage: MetricChange? = {
            guard let current, let historicalAverage else { return nil }
            return MetricChange(previous: historicalAverage, current: current)
        }()

        let changeOver28Days: MetricChange? = {
            guard historical.count >= 2 * acuteChronicChronicWindowWeeks else { return nil }
            let last4 = historical.suffix(acuteChronicChronicWindowWeeks)
            let previous4 = historical.dropLast(acuteChronicChronicWindowWeeks).suffix(acuteChronicChronicWindowWeeks)
            let last4Average = last4.reduce(0, +) / Double(last4.count)
            let previous4Average = previous4.reduce(0, +) / Double(previous4.count)
            return MetricChange(previous: previous4Average, current: last4Average)
        }()

        let recentWindow = Array(allComplete.suffix(comparisonWindowWeeks))
        let classification = classify(
            recentCompleteWeeks: recentWindow,
            historicalWeekCount: historical.count,
            changeVsPreviousAverage: changeVsPreviousWeeksAverage
        )

        return WeeklyMetricTrend(
            currentValue: current,
            lastCompleteWeekValue: lastComplete,
            previousWeekValue: singlePreviousWeek,
            changeVsPreviousCompleteWeek: changeVsPreviousCompleteWeek,
            previousWeeksAverage: historicalAverage,
            changeVsPreviousWeeksAverage: changeVsPreviousWeeksAverage,
            changeOver28Days: changeOver28Days,
            classification: classification
        )
    }

    /// Klassifiziert EINE Kennzahl (z.B. Laufkilometer oder Kraftvolumen).
    /// Reihenfolge der Pruefung ist die Prioritaet: Datenbasis zuerst,
    /// Schwankung vor gerichtetem Trend (ein stark schwankender Verlauf mit
    /// zufaellig hohem letzten Wert ist kein verlaesslicher "Anstieg").
    /// `historicalWeekCount` ist die Anzahl der Wochen, auf denen die
    /// Vergleichsbasis (`changeVsPreviousAverage`) beruht - NICHT
    /// `recentCompleteWeeks.count` (das kann die aktuelle Woche mit
    /// einschliessen und waere damit die falsche Grundlage fuer "reicht die
    /// Datenbasis fuer eine Aussage").
    static func classify(recentCompleteWeeks: [Double], historicalWeekCount: Int, changeVsPreviousAverage: MetricChange?) -> MetricTrendClassification {
        guard historicalWeekCount >= minimumCompleteWeeksForTrend else { return .insufficientData }

        let mean = recentCompleteWeeks.reduce(0, +) / Double(max(recentCompleteWeeks.count, 1))
        if mean > 0, recentCompleteWeeks.count >= minimumCompleteWeeksForTrend {
            let variance = recentCompleteWeeks.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(recentCompleteWeeks.count)
            let coefficientOfVariation = sqrt(variance) / mean
            if coefficientOfVariation >= variabilityCoefficientThreshold {
                return .highlyVariable(coefficientOfVariation: coefficientOfVariation)
            }
        }

        guard let change = changeVsPreviousAverage, let percent = change.percentChange else {
            // Beide Werte 0 (z.B. eine Disziplin, die der Nutzer nie
            // betreibt) ist kein Datenmangel, sondern ein echtes "nichts
            // veraendert sich" - niemals als Luecke/Warnung interpretieren.
            if (changeVsPreviousAverage?.previous ?? 0) == 0 && (changeVsPreviousAverage?.current ?? 0) == 0 {
                return .notApplicable
            }
            return .insufficientData
        }

        if percent >= significantIncreaseThreshold { return .significantlyIncreasing(percent: percent) }
        if percent >= moderateIncreaseThreshold { return .increasing(percent: percent) }
        if percent <= -moderateIncreaseThreshold { return .declining(percent: percent) }
        return .stable
    }

    // MARK: - Gesamtbelastungsentwicklung

    /// Kombiniert NUR Lauf-Distanz und Kraft-Volumen (die beiden Kennzahlen
    /// mit einer echten Groessenordnung) - niemals Ausdauer-Distanz und
    /// Kraft-Volumen vermischt (Ticket Teil 4: "keine Vermischung").
    /// "Keine Bewertung allein anhand von Laufkilometern, wenn gleichzeitig
    /// Krafttraining stattfindet": beide Disziplinen werden UNABHAENGIG
    /// klassifiziert, das schwerwiegendere Ergebnis gewinnt, beide werden
    /// als ausloesende Disziplin(en) genannt.
    static func combineLoadDevelopment(running: WeeklyMetricTrend, strength: WeeklyMetricTrend) -> LoadDevelopment {
        func severity(_ c: MetricTrendClassification) -> Int {
            switch c {
            case .significantlyIncreasing: return 5
            case .increasing: return 4
            case .highlyVariable: return 3
            case .declining: return 2
            case .stable: return 1
            case .notApplicable: return 0
            case .insufficientData: return -1
            }
        }

        let runningClass = running.classification
        let strengthClass = strength.classification
        let winner = severity(runningClass) >= severity(strengthClass) ? runningClass : strengthClass
        let loser = severity(runningClass) >= severity(strengthClass) ? strengthClass : runningClass

        // Beide ohne verwertbares Signal -> insufficientData, NIE stable
        // erfinden (Ticket: "insufficientData" ist ein eigenstaendiges Ergebnis).
        if severity(winner) < 0 { return .insufficientData }

        func disciplines(for classification: MetricTrendClassification, isRunning: Bool) -> [Discipline] {
            severity(classification) == severity(winner) && severity(classification) > 0 ? [isRunning ? .running : .strength] : []
        }
        let triggeringDisciplines = disciplines(for: runningClass, isRunning: true) + disciplines(for: strengthClass, isRunning: false)

        switch winner {
        case .significantlyIncreasing(let percent): return .significantIncrease(disciplines: triggeringDisciplines, percent: percent)
        case .increasing(let percent): return .moderateIncrease(disciplines: triggeringDisciplines, percent: percent)
        case .declining(let percent): return .declining(disciplines: triggeringDisciplines, percent: percent)
        case .highlyVariable(let cov): return .highlyVariable(disciplines: triggeringDisciplines, coefficientOfVariation: cov)
        case .stable, .notApplicable:
            // Wenn der "Verlierer" insufficientData ist, aber der Gewinner
            // ein echtes (stabiles) Signal hat, bleibt das Gesamtergebnis
            // stabil - ein fehlendes Signal in EINER Disziplin darf die
            // andere nicht verdraengen.
            _ = loser
            return .stable
        case .insufficientData: return .insufficientData
        }
    }

    // MARK: - Acute:Chronic Workload Ratio (Ticket Teil 5)

    /// Ausschliesslich auf Lauf-Distanz (nie Kraftvolumen - "keine
    /// Vermischung"). `nil`, wenn keine 4 vollstaendigen Wochen VOLLSTAENDIG
    /// innerhalb der bekannten Historie liegen (`weeks` ist bereits exakt
    /// auf die bekannte Historie begrenzt, siehe `TrainingLoadAggregator`/
    /// `RaceProgressCardModel`-Konvention `windowStart` = fruehestes
    /// bekanntes Aktivitaetsdatum) oder wenn der chronische Durchschnitt 0
    /// ist (Division durch 0 vermeiden, UND ein Sprung von 0 auf irgendeinen
    /// Wert ist kein sinnvolles Verhaeltnis).
    public static func acuteChronicRatio(weeks: [TrainingLoadWeek], now: Date, calendar: Calendar) -> Double? {
        let completeWeeks = weeks.filter { isComplete($0, now: now, calendar: calendar) }
        guard completeWeeks.count >= acuteChronicChronicWindowWeeks else { return nil }
        let window = completeWeeks.suffix(acuteChronicChronicWindowWeeks)
        guard let acute = window.last?.running.runningDistanceKm else { return nil }
        let chronicAverage = window.reduce(0.0) { $0 + $1.running.runningDistanceKm } / Double(acuteChronicChronicWindowWeeks)
        guard chronicAverage > 0 else { return nil }
        return acute / chronicAverage
    }

    // MARK: - Datenvollstaendigkeit (Ticket Teil 6)

    static func dataCompleteness(
        weeks: [TrainingLoadWeek], historicalWeekCount: Int, isCurrentWeekComplete: Bool
    ) -> TrainingLoadDataCompleteness {
        var reasons: [TrainingLoadDataCompleteness.Reason] = []

        if historicalWeekCount < minimumCompleteWeeksForTrend {
            reasons.append(.shortHistory(weeksAvailable: historicalWeekCount, weeksNeeded: minimumCompleteWeeksForTrend))
        }
        if !isCurrentWeekComplete, weeks.last != nil {
            reasons.append(.currentWeekIncomplete)
        }
        // Eine Woche mit geloggten Lauf-Sessions, aber 0 km Gesamtdistanz,
        // ist mit hoher Wahrscheinlichkeit eine Woche mit unbekannter
        // Distanz (Phase 1 kollabiert "unbekannt" und "0" an dieser Stelle
        // bereits auf Aggregat-Ebene, siehe `CardioVolumeOverTimePoint`-Doku) -
        // niemals als "0 km gelaufen" interpretieren.
        let weeksWithUnknownDistance = weeks.filter { $0.running.runningSessionCount > 0 && $0.running.runningDistanceKm == 0 }.count
        if weeksWithUnknownDistance > 0 {
            reasons.append(.missingRunningDistance(weeks: weeksWithUnknownDistance))
        }
        let weeksWithAmbiguousActivity = weeks.filter { $0.running.ambiguousCardioSessionCount > 0 }.count
        if weeksWithAmbiguousActivity > 0 {
            reasons.append(.unknownActivityPresent(weeks: weeksWithAmbiguousActivity))
        }
        // Laufdauer/Gesamttrainingsdauer sind im 2A-Datenmodell nicht
        // erfasst (siehe Typ-Dokumentation oben) - das macht JEDE Analyse
        // hoechstens "partial", nie "complete".
        reasons.append(.durationDataUnavailable)

        if reasons.contains(where: { if case .shortHistory = $0 { return true }; return false }) {
            return .insufficient(reasons: reasons)
        }
        return .partial(reasons: reasons)
    }
}

// MARK: - Werttypen

/// Absolute und (wenn sinnvoll) relative Veraenderung zwischen zwei Werten.
/// `percentChange` ist `nil`, wenn `previous == 0` - eine Prozentangabe
/// relativ zu 0 ist immer irrefuehrend (Ticket Teil 3, explizites Beispiel).
public struct MetricChange: Sendable, Equatable {
    public let previous: Double
    public let current: Double
    public let absoluteChange: Double
    public let percentChange: Double?

    public init(previous: Double, current: Double) {
        self.previous = previous
        self.current = current
        self.absoluteChange = current - previous
        self.percentChange = previous == 0 ? nil : (current - previous) / previous
    }
}

public enum MetricTrendClassification: Sendable, Equatable {
    case stable
    case increasing(percent: Double)
    case significantlyIncreasing(percent: Double)
    case declining(percent: Double)
    case highlyVariable(coefficientOfVariation: Double)
    /// Beide Vergleichswerte sind 0 - eine Disziplin, die schlicht nicht
    /// stattfindet. Kein Datenmangel, keine Warnung.
    case notApplicable
    case insufficientData
}

/// Eine einzelne Kennzahl (z.B. Laufkilometer) mit Rohwerten UND
/// eingeordneter Entwicklung - niemals nur die Einordnung ohne die
/// zugrunde liegenden Zahlen (Ticket Teil 7: "jede Aussage muss auf
/// nachvollziehbaren Eingabewerten basieren").
public struct WeeklyMetricTrend: Sendable, Equatable {
    /// Wert der aktuellen Woche (ggf. unvollstaendige Kalenderwoche). `nil`,
    /// wenn keine Wochen vorliegen.
    public let currentValue: Double?
    public let lastCompleteWeekValue: Double?
    /// Wert GENAU der einen vollstaendigen Woche vor der letzten
    /// vollstaendigen Woche - Vergleichsbasis fuer
    /// `changeVsPreviousCompleteWeek` (Ticket: "letzte vollstaendige Woche
    /// gegenueber VORHERIGER vollstaendiger Woche", kein Durchschnitt).
    public let previousWeekValue: Double?
    public let changeVsPreviousCompleteWeek: MetricChange?
    /// Durchschnitt ALLER vorhandenen HISTORISCHEN (= vor der aktuellen
    /// Woche liegenden) vollstaendigen Wochen - Vergleichsbasis fuer
    /// `changeVsPreviousWeeksAverage`. Schliesst die aktuelle Woche
    /// STRUKTURELL nie mit ein, selbst wenn diese kalendarisch bereits
    /// vollstaendig waere (siehe `metricTrend`-Dokumentation).
    public let previousWeeksAverage: Double?
    public let changeVsPreviousWeeksAverage: MetricChange?
    /// Durchschnitt der letzten 4 vollstaendigen Wochen gegen die 4 Wochen
    /// davor (Ticket: "28-Tage-Entwicklung"). `nil` ohne 8 vollstaendige
    /// Wochen Historie.
    public let changeOver28Days: MetricChange?
    public let classification: MetricTrendClassification

    public init(
        currentValue: Double?, lastCompleteWeekValue: Double?, previousWeekValue: Double?,
        changeVsPreviousCompleteWeek: MetricChange?, previousWeeksAverage: Double?,
        changeVsPreviousWeeksAverage: MetricChange?,
        changeOver28Days: MetricChange?, classification: MetricTrendClassification
    ) {
        self.currentValue = currentValue
        self.lastCompleteWeekValue = lastCompleteWeekValue
        self.previousWeekValue = previousWeekValue
        self.changeVsPreviousCompleteWeek = changeVsPreviousCompleteWeek
        self.previousWeeksAverage = previousWeeksAverage
        self.changeVsPreviousWeeksAverage = changeVsPreviousWeeksAverage
        self.changeOver28Days = changeOver28Days
        self.classification = classification
    }
}

public enum Discipline: Sendable, Equatable { case running, strength }

public enum LoadDevelopment: Sendable, Equatable {
    case stable
    case moderateIncrease(disciplines: [Discipline], percent: Double)
    case significantIncrease(disciplines: [Discipline], percent: Double)
    case declining(disciplines: [Discipline], percent: Double)
    case highlyVariable(disciplines: [Discipline], coefficientOfVariation: Double)
    case insufficientData
}

public enum TrainingLoadDataCompleteness: Sendable, Equatable {
    public enum Reason: Sendable, Equatable {
        case shortHistory(weeksAvailable: Int, weeksNeeded: Int)
        case currentWeekIncomplete
        case missingRunningDistance(weeks: Int)
        case unknownActivityPresent(weeks: Int)
        /// 2A's Datenmodell erfasst keine Lauf-/Gesamttrainingsdauer (siehe
        /// Design-Dokument) - gilt daher IMMER, bis dieses Feld existiert.
        case durationDataUnavailable
    }

    case complete
    case partial(reasons: [Reason])
    case insufficient(reasons: [Reason])
}

public struct RunningLoadTrend: Sendable, Equatable {
    public let weeklyDistanceKm: WeeklyMetricTrend
    public let weeklySessionCount: WeeklyMetricTrend
}

public struct StrengthLoadTrend: Sendable, Equatable {
    public let weeklySessionCount: WeeklyMetricTrend
    public let weeklySetCount: WeeklyMetricTrend
    public let weeklyVolumeKg: WeeklyMetricTrend
}

public struct OtherEnduranceLoadTrend: Sendable, Equatable {
    /// NUR Sessionzahl - `CardioVolumeOverTimePoint` erfasst weder Distanz
    /// noch Dauer fuer Cross-Training (Phase-1-Entscheidung, siehe
    /// Design-Dokument). Niemals mit Laufkilometern vermischt.
    public let weeklySessionCount: WeeklyMetricTrend
}

public struct OverallTrainingSummary: Sendable, Equatable {
    public let weeklyAmbiguousSessionCount: WeeklyMetricTrend
    /// Immer `nil` - siehe `TrainingLoadDataCompleteness.Reason.
    /// durationDataUnavailable`. Bewusst als optionales Feld modelliert statt
    /// weggelassen, damit eine spaetere Phase die Spalte nicht neu
    /// einfuehren muss (identisches Prinzip wie `CardioVolumeOverTimePoint.
    /// averageHeartRateBpm` in Phase 1).
    public let weeklyTotalDurationSeconds: Int?
}

/// Das vollstaendige Ergebnis der Work-Package-2B-Trendanalyse. Reiner
/// Werttyp, keine lokalisierten Strings (Ticket Teil 7).
public struct TrainingLoadTrend: Sendable, Equatable {
    public let analyzedWeeks: [TrainingLoadWeek]
    public let currentWeek: TrainingLoadWeek?
    public let isCurrentWeekComplete: Bool

    public let running: RunningLoadTrend
    public let strength: StrengthLoadTrend
    public let otherEndurance: OtherEnduranceLoadTrend
    public let overall: OverallTrainingSummary

    public let loadDevelopment: LoadDevelopment
    /// Siehe `TrainingLoadTrendAnalyzer.acuteChronicRatio` - ausschliesslich
    /// interne Kennzahl, nie die zentrale Aussage des Coaches (Ticket Teil 5).
    public let acuteChronicRatio: Double?

    public let dataCompleteness: TrainingLoadDataCompleteness
}
