// DEL-196: Auto-Deload-Empfehlung.
//
// Kombiniert zwei Signale, die das DEL-098/099-Scoring bereits liefert:
//   1. **Steigende Wochen-Last** — die summierte CNS-Load der letzten drei
//      Kalenderwochen steigt monoton UND um mindestens 20% von Woche 1 zu
//      Woche 3. Ein einzelner harter Tag triggert also nichts; es braucht
//      einen echten Aufwärts-Trend.
//   2. **Subjektive Erschöpfung** — mindestens zwei Sessions in den letzten
//      14 Tagen mit `sessionFeeling >= 4` ("Sehr schwer" / "Zerstört",
//      DEL-057-Skala).
//
// Beides zusammen = klassisches Overreaching-Muster → Deload empfehlen.
// Nur EIN Signal allein reicht nicht: steigende Last bei gutem Gefühl ist
// gewollte Progression; schlechtes Gefühl ohne Last-Trend ist eher Schlaf/
// Stress/Krankheit — dafür gibt es andere Coaching-Hinweise.
//
// Pure function — Dashboard aggregiert die Wochen-Loads aus den Sessions
// und ruft hier nur noch die Entscheidung ab.

import Foundation

public enum DeloadAdvisor {

    /// Mindest-Anstieg von der ältesten zur jüngsten Woche (Faktor).
    /// 1.2 = +20% — darunter ist es normales Wochen-Rauschen.
    public static let minimumRampFactor: Double = 1.2

    /// Wieviele harte Sessions (Feeling >= 4) in den letzten 14 Tagen
    /// mindestens nötig sind.
    public static let minimumHardSessions: Int = 2

    /// Session-Feeling-Schwelle, ab der eine Session als "hart" zählt
    /// (DEL-057-Skala: 4 = Sehr schwer, 5 = Zerstört).
    public static let hardFeelingThreshold: Int = 4

    /// Entscheidet, ob eine Deload-Woche empfohlen werden soll.
    ///
    /// - Parameter weeklyLoads: Summierte Trainings-Last (z.B. CNS-Load)
    ///   pro Kalenderwoche, älteste zuerst. Es werden die letzten drei
    ///   Einträge betrachtet; weniger als drei → nie eine Empfehlung
    ///   (Stichprobe zu klein).
    /// - Parameter hardSessionCount: Anzahl Sessions mit Feeling >=
    ///   `hardFeelingThreshold` in den letzten 14 Tagen.
    public static func shouldRecommendDeload(
        weeklyLoads: [Double],
        hardSessionCount: Int
    ) -> Bool {
        guard hardSessionCount >= minimumHardSessions else { return false }
        let recent = Array(weeklyLoads.suffix(3))
        guard recent.count == 3 else { return false }
        let (w1, w2, w3) = (recent[0], recent[1], recent[2])
        // Monoton steigend — strikt, damit eine flache Woche den Trend bricht.
        guard w3 > w2, w2 > w1 else { return false }
        // Null-Last-Schutz: ohne Basis-Woche keine Ratio-Aussage.
        guard w1 > 0 else { return false }
        return w3 >= w1 * minimumRampFactor
    }

    // MARK: - Ablauf der Deload-Woche

    /// Ist die per Timer festgelegte Deload-Woche abgelaufen?
    ///
    /// - Parameter untilTimestamp: Unix-Timestamp aus `deload_until`. `0`
    ///   heisst "kein Timer" (z.B. nach Neuinstallation oder Restore) und gilt
    ///   nie als abgelaufen — ohne Enddatum gibt es nichts, was man automatisch
    ///   beenden koennte; der Nutzer beendet dann manuell.
    ///
    /// Bewusst NUR am Timer festgemacht, nicht daran, ob noch gesicherte
    /// Originalgewichte existieren: DEL-238 laesst das Banner zusaetzlich aus
    /// den DATEN erscheinen (Timer verloren), und diese Bedingung bleibt nach
    /// Ablauf wahr, solange die Gewichte nicht zurueckgestellt sind. Wer den
    /// Auto-Ablauf davon abhaengig macht, beendet nie.
    public static func hasExpired(untilTimestamp: Double, now: Date) -> Bool {
        untilTimestamp > 0 && untilTimestamp <= now.timeIntervalSince1970
    }

    // MARK: - DEL-236: Nur Krafttraining zaehlt

    /// Kraft-Anteil der CNS-Last einer Session — Cardio-Saetze fliegen raus.
    ///
    /// **Warum das noetig war.** Beide Signale oben haben vorher JEDE reale
    /// Session gezaehlt, und `ExerciseLog.cnsFatigueScore` liefert fuer Cardio
    /// sehr wohl einen Wert (aus der Dauer, ueber `timeBasedScore`) — ein
    /// langer Lauf landet im hoechsten Belastungs-Bucket. Wer sein Laufpensum
    /// drei Wochen steigert und zwei Laeufe als sehr hart meldet, bekam damit
    /// eine Deload-Empfehlung, die seine LANGHANTEL-Gewichte halbiert. Das
    /// Krafttraining hatte sich dabei nie veraendert.
    ///
    /// Ein Deload reduziert Arbeitsgewichte. Die Entscheidung darueber darf
    /// deshalb nur von Kraftarbeit abhaengen. Laufermuedung ist real, aber die
    /// richtige Antwort darauf ist ein Ruhetag, nicht eine halbierte Kniebeuge.
    ///
    /// TimeBased-Uebungen (Plank, Wall Sit) zaehlen bewusst MIT: das ist
    /// Widerstandsarbeit gegen den eigenen Koerper, kein Ausdauertraining.
    /// Ausgeschlossen wird ausschliesslich `isCardio`.
    public static func strengthCNSLoad(logs: [(isCardio: Bool, cnsScore: Double)]) -> Double {
        logs.reduce(0.0) { $0 + ($1.isCardio ? 0 : $1.cnsScore) }
    }

    /// Zaehlt diese Session als "harte Session" im Sinne der Deload-Erkennung?
    ///
    /// Nur wenn ueberhaupt Kraftarbeit dabei war. Ein zerstoerender
    /// Halbmarathon ist eine harte Session — aber keine, die etwas ueber die
    /// Ermuedung beim Bankdruecken aussagt.
    public static func isHardStrengthSession(feeling: Int?, containsStrengthWork: Bool) -> Bool {
        containsStrengthWork && (feeling ?? 0) >= hardFeelingThreshold
    }
}
