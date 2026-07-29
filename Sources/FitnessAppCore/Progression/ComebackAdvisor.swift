import Foundation

/// DEL-235: Entscheidet, OB und WIE stark nach einer Trainingspause reduziert
/// wird. Reine Funktionen, kein SwiftData — die Anwendung auf echte Uebungen
/// folgt in einem eigenen Ticket, sobald der gemeinsame Gewichts-Zustand steht.
///
/// **Warum ein Comeback kein Deload ist.** Ein Deload baut Ermuedung nach
/// Ueberlastung ab: die Leistungsfaehigkeit ist da, sie ist nur verschuettet.
/// Deshalb dauert er eine Woche und endet dann. Ein Comeback rekonditioniert
/// nach Inaktivitaet: Kraft ist tatsaechlich abgebaut, und der Wiedereinstieg
/// scheitert erfahrungsgemaess nicht am Muskel, sondern an Bindegewebe,
/// Technik und Muskelkater. Deshalb wird hier nicht nach Zeit, sondern nach
/// ABSOLVIERTEN Sessions zurueckgefahren — wer nach der Pause zwei Wochen
/// wieder nichts tut, soll nicht automatisch auf voller Last landen.
public enum ComebackAdvisor {

    // MARK: - Auslöser

    /// Untergrenze, ab der ueberhaupt eingegriffen wird.
    ///
    /// Bewusst 14 Tage und nicht die 5 Tage der `reEntry`-Coach-Nachricht: eine
    /// freundliche Bemerkung nach fuenf Tagen ist harmlos, ein Eingriff in die
    /// Arbeitsgewichte nach fuenf Tagen ist Bevormundung. Wer Montag und
    /// Freitag trainiert, hat regelmaessig Luecken von vier bis fuenf Tagen.
    public static let minimumGapDays = 14

    /// Persoenliche Schwelle: bei wem eine Pause ungewoehnlich ist, greift der
    /// Modus frueher — aber nie unter `minimumGapDays`.
    ///
    /// Ein Nutzer mit 6 Tagen Median-Abstand trainiert erkennbar locker; bei
    /// ihm sind 15 Tage kaum ein Bruch. Bei taeglichem Training (Median 1-2)
    /// bleibt es bei 14. Faktor 2.5 statt 2, damit eine einzelne verpasste
    /// Woche nicht sofort als Absenz gilt.
    public static func gapThresholdDays(medianGapOfLastSessions median: Double?) -> Int {
        guard let median, median > 0 else { return minimumGapDays }
        return max(minimumGapDays, Int((2.5 * median).rounded(.down)))
    }

    /// Soll fuer diese Luecke ein Comeback vorgeschlagen werden?
    ///
    /// - Parameters:
    ///   - gapDays: Tage seit der letzten echten Session.
    ///   - medianGap: Median-Abstand der letzten Sessions (persoenliche Norm).
    ///   - sessionsBeforeGap: Sessions in den 28 Tagen VOR der Pause. Das
    ///     Fenster endet an der letzten Session, nicht heute — sonst waere es
    ///     bei langen Pausen zwangslaeufig leer und die Bedingung sinnlos.
    ///     Mindestens 3 verlangt, weil nur dann ueberhaupt eine Last existiert,
    ///     von der sich reduzieren laesst. Wer noch nie regelmaessig trainiert
    ///     hat, braucht kein Comeback, sondern einen Einstieg.
    ///
    ///     **DEL-240: ueber die GESAMTE Historie gezaehlt, nicht in einem
    ///     Fenster vor der Pause.** Die erste Fassung nahm die 28 Tage vor der
    ///     letzten Kraft-Session. Das verwechselt "Anfaenger" mit "hatte
    ///     letzten Monat wenig Zeit": wer zwei Jahre trainiert hat, dann einen
    ///     ruhigen Monat, dann drei Wochen Pause, ist genau der Fall, fuer den
    ///     die Rueckfrage gedacht ist — und wurde von der alten Regel
    ///     ausgeschlossen. Aufgefallen an echten Nutzerdaten: eine
    ///     Kraft-Session am 9., danach nur Laeufe, 20 Tage Luecke, keine Frage.
    ///   - suppressedUntilGapDays: Hat der Nutzer abgelehnt, merkt sich die App
    ///     die damalige Luecke. Erneut gefragt wird nur bei einer DEUTLICH
    ///     laengeren Pause — kein Nachbohren.
    /// Mindestzahl an Kraft-Sessions in der GESAMTEN Historie, damit von einer
    /// etablierten Last gesprochen werden kann.
    public static let minimumPriorStrengthSessions = 3

    public static func shouldSuggest(
        gapDays: Int,
        medianGap: Double?,
        priorStrengthSessionCount: Int,
        suppressedUntilGapDays: Int? = nil
    ) -> Bool {
        guard gapDays >= gapThresholdDays(medianGapOfLastSessions: medianGap) else { return false }
        guard priorStrengthSessionCount >= minimumPriorStrengthSessions else { return false }
        if let suppressed = suppressedUntilGapDays, gapDays <= suppressed { return false }
        return true
    }

    // MARK: - Verordnung

    /// Wie stark reduziert wird und ueber wie viele Stufen es zurueckgeht.
    public struct Prescription: Sendable, Equatable {
        /// Faktor auf das Arbeitsgewicht bei Verbund-Uebungen (1.0 = keine
        /// Reduktion).
        public let compoundFactor: Double
        /// Faktor fuer Isolations-Uebungen. Immer >= `compoundFactor`:
        /// Bizeps-Curls sind technisch und strukturell weniger fordernd als
        /// eine schwere Kniebeuge.
        public let isolationFactor: Double
        /// Wie viele Saetze in der ERSTEN Session wegfallen.
        public let firstSessionSetDelta: Int
        /// Zusaetzlicher RIR-Puffer — der Nutzer soll bewusst weiter vom
        /// Muskelversagen wegbleiben.
        public let rirDelta: Int
        /// Absenkung der unteren Wiederholungsgrenze.
        ///
        /// Nicht kosmetisch: `ProgressionEvaluator` urteilt gegen die untere
        /// Grenze und vergibt ein Deload-Verdikt, sobald ein Satz darunter
        /// liegt. Ohne abgesenkten Boden wuerde die Comeback-Session
        /// systematisch Abwaerts-Verdikte erzeugen und die Reduktion damit
        /// zementieren.
        public let repsFloorDelta: Int
        /// Ueber wie viele qualifizierte Sessions es zurueck auf Ausgangslast
        /// geht.
        public let rampSteps: Int
        /// Ab dieser Pausenlaenge ist ein Wiedertest sinnvoller als eine
        /// geschaetzte Reduktion — die alte Last ist keine belastbare
        /// Referenz mehr.
        public let needsRetest: Bool

        public static let none = Prescription(
            compoundFactor: 1.0, isolationFactor: 1.0, firstSessionSetDelta: 0,
            rirDelta: 0, repsFloorDelta: 0, rampSteps: 0, needsRetest: false
        )
    }

    /// Staffel nach Pausenlaenge.
    ///
    /// Bewusst Buckets und keine stetige Formel: eine lineare Regel von etwa
    /// 0,3 % pro Tag ergibt bei 20 Tagen rund 1,8 %, auf 60 kg also ~1,1 kg —
    /// das frisst die Plattenrasterung vollstaendig weg, und das Feature waere
    /// in seinem haeufigsten Fall wirkungslos. Die Stufen sind so gewaehlt,
    /// dass in jedem Bucket eine darstellbare Aenderung herauskommt.
    ///
    /// Die Prozentwerte folgen der Detraining-Literatur: Maximalkraft haelt
    /// sich mehrere Wochen bemerkenswert gut (Muscle Memory), waehrend
    /// Belastungstoleranz von Sehnen und Bindegewebe schneller nachgibt.
    /// Deshalb ist die Lastreduktion moderat, die Volumen- und RIR-Reduktion
    /// dafuer deutlich — genau umgekehrt zur naiven Erwartung.
    public static func prescription(forGapDays gapDays: Int) -> Prescription {
        switch gapDays {
        case ..<14:
            return .none
        case 14...20:
            return Prescription(compoundFactor: 0.95, isolationFactor: 1.0,
                                firstSessionSetDelta: -1, rirDelta: 1,
                                repsFloorDelta: -1, rampSteps: 2, needsRetest: false)
        case 21...29:
            return Prescription(compoundFactor: 0.90, isolationFactor: 0.95,
                                firstSessionSetDelta: -1, rirDelta: 1,
                                repsFloorDelta: -1, rampSteps: 2, needsRetest: false)
        case 30...59:
            return Prescription(compoundFactor: 0.85, isolationFactor: 0.90,
                                firstSessionSetDelta: -2, rirDelta: 1,
                                repsFloorDelta: -2, rampSteps: 3, needsRetest: false)
        case 60...89:
            return Prescription(compoundFactor: 0.80, isolationFactor: 0.85,
                                firstSessionSetDelta: -2, rirDelta: 2,
                                repsFloorDelta: -2, rampSteps: 5, needsRetest: false)
        case 90...179:
            return Prescription(compoundFactor: 0.75, isolationFactor: 0.80,
                                firstSessionSetDelta: -2, rirDelta: 2,
                                repsFloorDelta: -2, rampSteps: 6, needsRetest: false)
        default:
            // Ab einem halben Jahr ist die alte Last Geschichte. Ein
            // geschaetzter Faktor waere Zahlenmystik; hier gehoert ein
            // Wiedertest hin. Volumen und RIR werden trotzdem entschaerft.
            return Prescription(compoundFactor: 1.0, isolationFactor: 1.0,
                                firstSessionSetDelta: -2, rirDelta: 2,
                                repsFloorDelta: -2, rampSteps: 3, needsRetest: true)
        }
    }

    // MARK: - DEL-239 Auswahl und Rundung

    /// Reduktions-Stufen, die der Nutzer in der Rueckfrage waehlen kann.
    ///
    /// Bewusst 5-Prozent-Schritte und kein Schieberegler: Gewichte rasten auf
    /// die Scheiben-Schrittweite der Uebung (meist 2,5 kg). Bei 60 kg
    /// Arbeitsgewicht ist der Unterschied zwischen 12 % und 13 % nach der
    /// Rundung null — ein feiner Regler wuerde Genauigkeit vorspiegeln, die
    /// nicht existiert.
    public static let selectableReductions: [Double] = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30]

    /// Reduziertes Arbeitsgewicht, auf die Scheiben-Schrittweite gerastet.
    ///
    /// - Parameters:
    ///   - current: aktuelles Arbeitsgewicht.
    ///   - factor: Zielfaktor (0,85 = minus 15 %). Werte >= 1 liefern das
    ///     Gewicht unveraendert zurueck — "keine Reduktion" ist eine legitime
    ///     Wahl und darf nicht in eine Pseudo-Aenderung umkippen.
    ///   - increment: Scheiben-Schrittweite der Uebung.
    ///
    /// **Abwaerts gerastet, nicht gerundet.** Projekt-Konvention (truncate
    /// statt round) und hier zusaetzlich inhaltlich richtig: bei einem Deload
    /// ist die kleinere Zahl die sichere. `startDeload` rundet historisch mit
    /// `.rounded()` auf feste 2,5 — das bleibt unangetastet, um das Verhalten
    /// des Overreaching-Pfads nicht zu veraendern.
    ///
    /// **Relativer Boden statt absoluter.** Nie unter die Haelfte des
    /// Ausgangsgewichts, und nie unter eine Schrittweite. Ein absoluter Boden
    /// von 2,5 kg (wie in `startDeload`) macht aus 5 kg Kurzhantel-Arbeit im
    /// Extremfall eine Halbierung, waehrend er bei 200 kg nie greift.
    public static func reducedWeight(current: Double, factor: Double, increment: Double) -> Double {
        guard current > 0, increment > 0 else { return current }
        guard factor < 1.0 else { return current }

        let target = current * max(0, factor)
        let steps = (target / increment).rounded(.down)
        let snapped = steps * increment

        let relativeFloor = current * 0.5
        return max(snapped, increment, relativeFloor > increment ? relativeFloor : increment)
    }

    /// Aendert diese Reduktion das Gewicht ueberhaupt, nachdem gerastet wurde?
    ///
    /// Die Rueckfrage soll nicht behaupten, etwas zu tun, was auf dem Raster
    /// verpufft. Bei sehr leichten Gewichten oder sehr kleinen Prozentsaetzen
    /// ist das der Fall.
    public static func changesAnything(current: Double, factor: Double, increment: Double) -> Bool {
        reducedWeight(current: current, factor: factor, increment: increment) < current
    }

    // MARK: - Rückkehr

    /// Naechste Rampenstufe. Fuehrt in `stepsRemaining` Schritten linear auf
    /// 1.0 zurueck.
    ///
    /// Die letzte Stufe setzt exakt 1.0 statt sich asymptotisch zu naehern —
    /// sonst blieben Restfaktoren wie 0.998 stehen und die Reduktion waere
    /// formal nie beendet.
    public static func advance(factor: Double, stepsRemaining: Int) -> (factor: Double, stepsRemaining: Int) {
        guard stepsRemaining > 1 else { return (1.0, 0) }
        let step = (1.0 - factor) / Double(stepsRemaining)
        return (min(1.0, factor + step), stepsRemaining - 1)
    }

    /// Zaehlt eine Session als Fortschritt auf der Rampe?
    ///
    /// `.hold` wiederholt die Stufe, statt sie zu vergeben. Das
    /// Feeling-Veto spiegelt die bestehende Progressions-Regel und verhindert
    /// den Widerspruch, dass die Rampe eine Stufe freigibt, waehrend der Coach
    /// am naechsten Tag Ueberlastung meldet.
    public enum StepVerdict: Sendable, Equatable {
        case advance
        case hold(reason: HoldReason)

        public enum HoldReason: String, Sendable {
            /// Weniger Saetze geloggt als vorgesehen.
            case incompleteVolume
            /// Wiederholungen unter dem (bereits abgesenkten) Boden.
            case repsBelowFloor
            /// Naeher am Versagen als vorgesehen.
            case tooCloseToFailure
            /// Session subjektiv sehr hart.
            case sessionFeltHard
        }
    }

    public static func verdict(
        loggedSetCount: Int,
        targetSetCount: Int,
        reps: [Int],
        repsFloor: Int,
        medianRir: Double,
        targetRir: Double,
        sessionFeeling: Int?
    ) -> StepVerdict {
        // Reihenfolge ist Absicht: das subjektive Veto zuerst, damit der
        // Nutzer nicht auf die naechste Stufe geschoben wird, obwohl er die
        // Session als sehr hart gemeldet hat.
        if let sessionFeeling, sessionFeeling >= 4 {
            return .hold(reason: .sessionFeltHard)
        }
        if loggedSetCount < targetSetCount {
            return .hold(reason: .incompleteVolume)
        }
        if let lowest = reps.min(), lowest < repsFloor {
            return .hold(reason: .repsBelowFloor)
        }
        if medianRir < targetRir {
            return .hold(reason: .tooCloseToFailure)
        }
        return .advance
    }
}
