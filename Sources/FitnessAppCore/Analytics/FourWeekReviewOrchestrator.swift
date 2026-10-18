import Foundation

/// P7.1: Dünne Bündelungs-Schicht für den Vier-Wochen-Rückblick. Reine
/// Funktion, kein SwiftData, kein `Date()`/`Calendar.current` im Code-Pfad
/// selbst — alle Signale werden injiziert, wie bei `PlanParticipationEvaluator`
/// und `DeloadAdvisor`.
///
/// **Bewusste Grenzen, direkt aus dem Gesamtmandat:**
///   * Dieser Typ ERFINDET keine neue Progressions-/Deload-Entscheidung. Er
///     nimmt ausschliesslich bereits von `DeloadAdvisor`/`ComebackAdvisor`
///     getroffene Entscheidungen sowie das Ergebnis von
///     `PlanParticipationEvaluator` (P6.2) und `PeriodicCheckIn`-Feedback
///     (P6.3) entgegen und fasst sie zu EINER widerspruchsfreien Aussage
///     zusammen (F08: keine gleichzeitig widersprechenden Advisor-Vorschläge).
///   * `.keepAsIs` ("Plan passt – beibehalten") ist ein vollwertiges,
///     eigenstaendiges Ergebnis — kein blosses Fehlen von Problemen, das
///     stillschweigend uebersprungen wird.
///   * Unzureichende Datengrundlage (keine auswertbare Teilnahme, noch kein
///     Check-in) wird immer explizit mitgeliefert (`dataGaps`), auch wenn das
///     Gesamtergebnis `.keepAsIs` lautet — niemals verschwiegen, damit die UI
///     nie "alles bestens" suggeriert, wo in Wahrheit nur nichts bekannt ist.
///   * Enthaelt bewusst KEINE "apply"-Methode. Dieser Typ empfiehlt nur; das
///     tatsaechliche Anwenden eines Vorschlags (z. B. `AbsenceDeload.apply`)
///     bleibt ein separater, vom Nutzer bewusst bestaetigter Schritt an
///     anderer Stelle.
public enum FourWeekReviewOrchestrator {

    // MARK: - Input

    /// Die vier (bzw. fünf) Fragen aus `PeriodicCheckIn` (P6.3) — hier als
    /// reiner Werttyp, um keine SwiftData-Abhängigkeit in Core zu ziehen.
    /// Jedes Feld `nil` bedeutet ausdrücklich "nicht beantwortet/unbekannt",
    /// nie ein erratener Wert.
    public struct CheckInFeedback: Sendable, Equatable {
        public let frequencyFeedback: FrequencyFeedback?
        public let durationFeedback: DurationFeedback?
        public let hadComplaints: Bool?
        public let goalStillCurrent: Bool?
        /// Periodenbezogene, echt überspringbare Belastungsfrage aus
        /// `PeriodicCheckIn` (Nachbesserung) — ausdrücklich NICHT
        /// `WorkoutSession.sessionFeeling` (pro Session, nicht optional).
        /// Wird hier nur durchgereicht; es gibt (noch) KEINE eigene
        /// `Concern`-Logik dafür — ob "zu hart"/"zu leicht" selbst ein
        /// eigenständiger Befund werden soll (und wie er sich zu
        /// `DeloadAdvisor` abgrenzt), ist eine offene, bewusst noch nicht
        /// getroffene Entscheidung, keine impliziet mitgebaute.
        public let exertionFeedback: ExertionFeedback?

        public init(
            frequencyFeedback: FrequencyFeedback?,
            durationFeedback: DurationFeedback?,
            hadComplaints: Bool?,
            goalStillCurrent: Bool?,
            exertionFeedback: ExertionFeedback? = nil
        ) {
            self.frequencyFeedback = frequencyFeedback
            self.durationFeedback = durationFeedback
            self.hadComplaints = hadComplaints
            self.goalStillCurrent = goalStillCurrent
            self.exertionFeedback = exertionFeedback
        }
    }

    /// Bereits von `ComebackAdvisor` getroffene Entscheidung — der
    /// Orchestrator ruft `ComebackAdvisor` NICHT selbst auf (das würde die
    /// Gap-/Historien-Berechnung duplizieren), sondern bekommt das Ergebnis
    /// vom Aufrufer gereicht, der die realen Sessions kennt.
    public struct ComebackSignal: Sendable, Equatable {
        public let gapDays: Int
        public let prescription: ComebackAdvisor.Prescription

        public init(gapDays: Int, prescription: ComebackAdvisor.Prescription) {
            self.gapDays = gapDays
            self.prescription = prescription
        }
    }

    public struct Input: Sendable, Equatable {
        /// Ergebnis von `PlanParticipationEvaluator.evaluate(_:asOf:)` — wird
        /// unverändert durchgereicht, nicht neu berechnet.
        public let participation: PlanParticipationEvaluator.Result
        /// Der letzte gespeicherte `PeriodicCheckIn`, falls vorhanden. `nil`
        /// heisst: der Nutzer hat diese Runde noch nie einen Rückblick
        /// ausgefüllt — explizit als Datenlücke behandelt, NIE als "alles in
        /// Ordnung" interpretiert.
        public let latestCheckIn: CheckInFeedback?
        /// Von `DeloadAdvisor.shouldRecommendDeload` bereits getroffene
        /// Entscheidung.
        public let deloadRecommended: Bool
        /// Von `ComebackAdvisor.shouldSuggest` bereits getroffene
        /// Entscheidung samt Verordnung, oder `nil` wenn keine Pause erkannt
        /// wurde.
        public let comebackSignal: ComebackSignal?

        public init(
            participation: PlanParticipationEvaluator.Result,
            latestCheckIn: CheckInFeedback?,
            deloadRecommended: Bool,
            comebackSignal: ComebackSignal?
        ) {
            self.participation = participation
            self.latestCheckIn = latestCheckIn
            self.deloadRecommended = deloadRecommended
            self.comebackSignal = comebackSignal
        }
    }

    // MARK: - Output

    /// Ein einzelner, maschinenlesbarer Befund — die UI übersetzt diese 1:1
    /// in Text, Core liefert hier keine freien Strings.
    public enum Concern: Sendable, Equatable {
        case deloadRecommended
        case comebackSuggested(ComebackAdvisor.Prescription)
        /// Spürbar hinter dem Plan zurückgeblieben (siehe
        /// `significantMissedRatioThreshold`) — bewusst NICHT bei jeder
        /// einzelnen verpassten Einheit, sonst wäre jeder Vier-Wochen-Rückblick
        /// ein Vorwurf statt einer Standortbestimmung.
        case participationBelowPlan(missedCount: Int, plannedCount: Int)
        case complaintsReported
        case goalNoLongerCurrent
    }

    /// Warum (Teile der) Datengrundlage fehlen — wird IMMER mitgeliefert,
    /// unabhängig vom Gesamtergebnis (Regel: unzureichende Daten offen
    /// benennen, nie verschweigen).
    public enum DataGap: Sendable, Equatable {
        case participationNotReliablyEvaluable(PlanParticipationEvaluator.UnreliableReason)
        case noCheckInYet
        /// Gespiegelt aus `PlanParticipationEvaluator.Summary.dataGaps`
        /// (`.unattributableHistoryExcludedDueToMultipleActivePlans`) — bei
        /// mehreren gleichzeitig aktiven Plänen wurde reale Trainingshistorie
        /// ohne verlässliche Plan-Zuordnung von DIESER Auswertung
        /// ausgeschlossen, statt sie zu erraten oder stillschweigend
        /// anzurechnen. Eigens auf Orchestrator-Ebene gehoben (statt nur im
        /// internen `Summary.dataGaps` zu verbleiben), weil dieser Befund —
        /// anders als die übrigen, rein methodischen `Summary`-Datenlücken —
        /// für die betroffene Person sichtbar sein muss.
        case participationHistoryPartiallyUnattributed
    }

    public enum Outcome: Sendable, Equatable {
        /// "Plan passt – beibehalten" — vollwertiges Ergebnis, kein Fallback.
        case keepAsIs
        /// Mindestens ein Befund liegt vor. Reihenfolge ist die
        /// Anzeige-Priorität (schwerwiegendstes zuerst), nicht Fundreihenfolge.
        case concernsFound([Concern])
    }

    public struct Review: Sendable, Equatable {
        public let participation: PlanParticipationEvaluator.Result
        public let outcome: Outcome
        public let dataGaps: [DataGap]

        public init(
            participation: PlanParticipationEvaluator.Result,
            outcome: Outcome,
            dataGaps: [DataGap]
        ) {
            self.participation = participation
            self.outcome = outcome
            self.dataGaps = dataGaps
        }
    }

    // MARK: - Konfliktauflösung (F08)

    /// Ab welchem Anteil verpasster Gelegenheiten eine Teilnahme-Lücke als
    /// eigenständiger Befund gilt. 0.3 = mehr als 30% der fälligen Einheiten
    /// verpasst — ein einzelner Ausrutscher (z. B. 1 von 8) bleibt bewusst
    /// unterhalb der Schwelle.
    ///
    /// **Ausdrücklich eine vorläufige PRODUKTREGEL, keine wissenschaftliche
    /// Grenze** — ein plausibel gewählter, aber nicht empirisch hergeleiteter
    /// Wert, der bei echtem Nutzerfeedback angepasst werden darf/soll, ohne
    /// dass das eine "Korrektur eines Fehlers" waere. Und, zur Klarstellung,
    /// weil der Name das missverstehen liesse: dieser Wert loest NIEMALS von
    /// sich aus eine automatische Last- oder Planaenderung aus — er steuert
    /// ausschliesslich, ob `.participationBelowPlan` in der Befundliste
    /// auftaucht, die dem Nutzer zur Ansicht vorgelegt wird (P7.2). Jede
    /// tatsaechliche Aenderung bleibt ein separater, vom Nutzer bewusst
    /// bestaetigter Schritt (siehe Typ-Dokumentation oben: "KEINE
    /// apply-Methode").
    public static let significantMissedRatioThreshold: Double = 0.3

    // MARK: - Review

    public static func review(_ input: Input) -> Review {
        var dataGaps: [DataGap] = []
        var concerns: [Concern] = []

        switch input.participation {
        case .notReliablyEvaluable(let reason):
            dataGaps.append(.participationNotReliablyEvaluable(reason))
        case .evaluated(let summary):
            if summary.plannedCount > 0 {
                let missedRatio = Double(summary.missedCount) / Double(summary.plannedCount)
                if missedRatio > significantMissedRatioThreshold {
                    concerns.append(.participationBelowPlan(
                        missedCount: summary.missedCount,
                        plannedCount: summary.plannedCount
                    ))
                }
            }
            if summary.dataGaps.contains(.unattributableHistoryExcludedDueToMultipleActivePlans) {
                dataGaps.append(.participationHistoryPartiallyUnattributed)
            }
        }

        if let checkIn = input.latestCheckIn {
            if checkIn.hadComplaints == true {
                concerns.append(.complaintsReported)
            }
            if checkIn.goalStillCurrent == false {
                concerns.append(.goalNoLongerCurrent)
            }
        } else {
            dataGaps.append(.noCheckInYet)
        }

        // F08 — Konfliktauflösung: Deload (Überlastung bei steigender,
        // bereits absolvierter Last) und Comeback (Reduktion nach einer
        // Trainingspause) setzen gegensätzliche Tatsachen voraus und können
        // bei korrekten Eingabedaten nie beide zutreffen. Träfen sie wegen
        // widersprüchlicher/veralteter Eingabedaten dennoch gleichzeitig zu,
        // gewinnt das Comeback-Signal: eine erkannte Trainingspause ist die
        // aktuellere, konkretere Tatsache, waehrend ein Lastanstieg ueber drei
        // Wochen zwingend bedeutet, dass in dieser Zeit durchgehend trainiert
        // wurde — also nicht zur selben Pause passen kann.
        if let comeback = input.comebackSignal {
            concerns.append(.comebackSuggested(comeback.prescription))
        } else if input.deloadRecommended {
            concerns.append(.deloadRecommended)
        }

        let outcome: Outcome = concerns.isEmpty ? .keepAsIs : .concernsFound(concerns)
        return Review(participation: input.participation, outcome: outcome, dataGaps: dataGaps)
    }
}
