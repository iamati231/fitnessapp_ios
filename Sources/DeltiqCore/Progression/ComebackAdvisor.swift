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
    ///   - priorStrengthSessionCount: Kraft-Sessions in der GESAMTEN Historie
    ///     (DEL-240). Mindestens 3 verlangt, weil nur dann ueberhaupt eine
    ///     etablierte Last existiert, von der sich reduzieren laesst. Wer noch
    ///     nie regelmaessig trainiert hat, braucht kein Comeback, sondern einen
    ///     Einstieg.
    ///
    ///     **DEL-240: GESAMTE Historie, nicht 28-Tage-Fenster vor der Pause.** Die erste Fassung nahm die 28 Tage vor der
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
        // DEL-241: Stufen-basiert statt `gapDays <= suppressed` — siehe
        // `isSuppressed`. Die alte Fassung fragte am Tag nach der Ablehnung
        // wieder, weil die Luecke waechst.
        if let declined = suppressedUntilGapDays,
           isSuppressed(gapDays: gapDays, declinedAtGapDays: declined) {
            return false
        }
        return true
    }

    // MARK: - Verordnung

    /// Wie stark reduziert wird.
    ///
    /// DEL-242: Die Volumen- und Rampen-Felder sind entfernt
    /// (`firstSessionSetDelta`, `rirDelta`, `repsFloorDelta`, `rampSteps`) —
    /// ebenso `advance`, `verdict` und `StepVerdict`. Sie stammten aus DEL-235
    /// und wurden nie verdrahtet: DEL-239 hat das Design umgedreht, seither ist
    /// die Reduktion der neue Stand und `ProgressionApplicator` traegt die
    /// Gewichte ueber die naechsten Sessions zurueck nach oben. Eine zweite
    /// Rampen-Mechanik daneben waere ein widerspruechlicher zweiter Schreiber
    /// gewesen. Gebaut-aber-nicht-verdrahtet ist die schlimmste Sorte Code: es
    /// liest sich wie eine Zusicherung, die es nicht gibt.
    public struct Prescription: Sendable, Equatable, Codable {
        /// Faktor auf das Arbeitsgewicht bei Verbund-Uebungen (1.0 = keine
        /// Reduktion).
        public let compoundFactor: Double
        /// Faktor fuer Isolations-Uebungen. Immer >= `compoundFactor`:
        /// Bizeps-Curls sind technisch und strukturell weniger fordernd als
        /// eine schwere Kniebeuge.
        public let isolationFactor: Double
        /// Ab dieser Pausenlaenge ist ein Wiedertest sinnvoller als eine
        /// geschaetzte Reduktion — die alte Last ist keine belastbare
        /// Referenz mehr.
        public let needsRetest: Bool

        public static let none = Prescription(
            compoundFactor: 1.0, isolationFactor: 1.0, needsRetest: false
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
    /// Deshalb ist die Lastreduktion moderat gehalten.
    ///
    /// DEL-242 — offener Punkt, der mit den Rampen-Feldern verschwunden ist und
    /// hier festgehalten wird, damit er nicht vergessen wird: Eine Reduktion
    /// des Volumens (weniger Saetze) und ein groesserer RIR-Puffer waeren
    /// trainingswissenschaftlich MINDESTENS so wichtig wie die Lastreduktion.
    /// Zusaetzlich gilt: `ProgressionEvaluator` urteilt gegen die untere
    /// Wiederholungsgrenze und vergibt ein Abwaerts-Verdikt, sobald ein Satz
    /// darunter liegt — wer nach der Pause mit reduzierter Last weniger
    /// Wiederholungen schafft, bekommt derzeit also eine weitere Absenkung
    /// obendrauf. Dieser Schutz ist NICHT aktiv. Beides gehoert in ein eigenes
    /// Ticket, nicht in halb gebaute Felder, die niemand liest.
    public static func prescription(forGapDays gapDays: Int) -> Prescription {
        // DEL-241: Die isolationFactor-Werte sind identisch zu
        // `isolationFactor(forCompoundFactor:)` — ein Test haelt das fest,
        // damit Tabelle und Ableiter nicht auseinanderlaufen.
        switch gapDays {
        case ..<14:      return .none
        case 14...20:    return Prescription(compoundFactor: 0.95, isolationFactor: 1.0,  needsRetest: false)
        case 21...29:    return Prescription(compoundFactor: 0.90, isolationFactor: 0.95, needsRetest: false)
        case 30...59:    return Prescription(compoundFactor: 0.85, isolationFactor: 0.90, needsRetest: false)
        case 60...89:    return Prescription(compoundFactor: 0.80, isolationFactor: 0.85, needsRetest: false)
        case 90...179:   return Prescription(compoundFactor: 0.75, isolationFactor: 0.80, needsRetest: false)
        default:
            // Ab einem halben Jahr ist die alte Last Geschichte. Ein
            // geschaetzter Faktor waere Zahlenmystik; hier gehoert ein
            // Wiedertest hin.
            return Prescription(compoundFactor: 1.0, isolationFactor: 1.0, needsRetest: true)
        }
    }

    // MARK: - DEL-241 Isolation wird milder reduziert

    /// Um wie viele Prozentpunkte Isolations-Uebungen WENIGER reduziert werden
    /// als Verbund-Uebungen.
    ///
    /// Begruendung: eine schwere Kniebeuge fordert Technik, Rumpf und
    /// Bindegewebe; ein Bizeps-Curl nicht. Nach einer Pause gibt genau das
    /// zuerst nach, nicht die Muskelkraft — deshalb trifft die Reduktion die
    /// Verbundlifts staerker.
    public static let isolationRelief = 0.05

    /// Isolations-Faktor, abgeleitet aus dem Verbund-Faktor.
    ///
    /// Reproduziert exakt die Werte der Verordnungs-Tabelle (per Test
    /// abgesichert), gilt aber auch fuer eine vom Nutzer FREI gewaehlte Stufe:
    /// waehlt er minus 15 % fuer die Verbundlifts, bekommen Isolations-Uebungen
    /// minus 10 %. Bei minus 5 % bleibt Isolation unangetastet — weniger als
    /// eine Scheibe waere ohnehin nicht darstellbar.
    public static func isolationFactor(forCompoundFactor factor: Double) -> Double {
        guard factor < 1.0 else { return 1.0 }
        let compoundReduction = 1.0 - factor
        return 1.0 - max(0, compoundReduction - isolationRelief)
    }

    /// Passender Faktor fuer eine konkrete Uebung.
    public static func factor(forCompoundFactor factor: Double, isCompound: Bool) -> Double {
        isCompound ? factor : isolationFactor(forCompoundFactor: factor)
    }

    // MARK: - DEL-241 Ablehnung: wann wird erneut gefragt?

    /// Ist die Rueckfrage nach einer Ablehnung noch unterdrueckt?
    ///
    /// **Warum das nicht `gapDays <= declined` ist.** Genau so stand es
    /// zuerst da — und weil die Luecke waehrend einer Pause jeden Tag waechst,
    /// war die Frage am Tag nach der Ablehnung sofort wieder faellig. Aus
    /// "nicht nachbohren" wurde taegliches Nachbohren.
    ///
    /// Richtig ist: erneut fragen erst, wenn die Empfehlung inhaltlich STAERKER
    /// waere als die abgelehnte — also wenn die Pause eine neue Stufe der
    /// Verordnungs-Tabelle erreicht hat. Innerhalb derselben Stufe gibt es
    /// nichts Neues zu sagen.
    public static func isSuppressed(gapDays: Int, declinedAtGapDays: Int) -> Bool {
        let current = prescription(forGapDays: gapDays)
        let declined = prescription(forGapDays: declinedAtGapDays)
        // Der Wiedertest-Hinweis ist eine andere Aussage als ein Faktor und
        // darf eine frueher abgelehnte Reduktion ueberstimmen.
        if current.needsRetest && !declined.needsRetest { return false }
        return current.compoundFactor >= declined.compoundFactor
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

        // Bugfix (Audit): der Boden selbst muss ebenfalls gerastet sein, sonst
        // kann `max()` ihn gegen `snapped` gewinnen lassen und ein Gewicht
        // liefern, das mit der Schrittweite gar nicht ladbar ist (z.B. current
        // = 6, increment = 2.5 -> Boden 3.0 statt eines Vielfachen von 2.5).
        // Aufwaerts gerastet (nicht abwaerts wie `snapped`), damit der Boden
        // nie UNTERSCHRITTEN wird - das ist hier die staerkere Garantie.
        let relativeFloor = current * 0.5
        let snappedFloor = (relativeFloor / increment).rounded(.up) * increment
        return max(snapped, increment, snappedFloor > increment ? snappedFloor : increment)
    }

    // DEL-242: `changesAnything` entfernt — ohne Aufrufer. Die wirksame Regel
    // steht als `guard reduced < current` in `AbsenceDeload.preview` und
    // `.apply`, und zwar mit dem dort schon berechneten Wert. Ein Aufruf hier
    // haette `reducedWeight` pro Uebung ein zweites Mal gerechnet.

    // DEL-242: Der Rampen-Block (`advance`, `verdict`, `StepVerdict`) ist
    // entfernt. Er war ohne Aufrufer und ist es geblieben, weil DEL-239 das
    // Design umgedreht hat: die Reduktion ist der neue Stand,
    // `ProgressionApplicator` traegt die Gewichte ueber die naechsten Sessions
    // zurueck nach oben. Eine eigene Rampe daneben waere ein zweiter,
    // widerspruechlicher Schreiber auf `suggestedWeight` gewesen.
    //
    // Falls die Rueckkehr je feiner gesteuert werden soll, gehoert sie an
    // GENAU EINE Stelle — dieselbe, die auch die Progression schreibt.
}
